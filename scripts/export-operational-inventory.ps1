[CmdletBinding()]
param(
    [string]$OutputDir,
    [switch]$SkipServices,
    [switch]$SkipScheduledTasks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function New-DirectoryIfMissing {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function ConvertTo-FlatString {
    param([object]$Value)

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string]) {
        return $Value.Trim()
    }

    if ($Value -is [System.Array]) {
        return (($Value | ForEach-Object { ConvertTo-FlatString -Value $_ }) -join "; ").Trim()
    }

    return $Value.ToString().Trim()
}

function Get-ScheduledTaskInventory {
    try {
        $tasks = Get-ScheduledTask | Sort-Object TaskPath, TaskName
    }
    catch {
        Write-Warning ("Scheduled task inventory was skipped: {0}" -f $_.Exception.Message)
        return @()
    }

    foreach ($task in $tasks) {
        $taskInfo = $null
        try {
            $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName -TaskPath $task.TaskPath
        }
        catch {
            # Some built-in tasks can fail detail resolution; keep the row but omit runtime metadata.
        }

        $actions = @($task.Actions)
        $triggers = @($task.Triggers)
        $principal = $task.Principal
        $settings = $task.Settings

        [pscustomobject]@{
            Source                = "TaskScheduler"
            Kind                  = "ScheduledTask"
            Identifier            = "{0}{1}" -f $task.TaskPath, $task.TaskName
            Name                  = $task.TaskName
            Path                  = $task.TaskPath
            State                 = ConvertTo-FlatString -Value $task.State
            Enabled               = [bool]$task.Settings.Enabled
            RunAs                 = ConvertTo-FlatString -Value $principal.UserId
            LogonType             = ConvertTo-FlatString -Value $principal.LogonType
            RunLevel              = ConvertTo-FlatString -Value $principal.RunLevel
            Execute               = ConvertTo-FlatString -Value ($actions | ForEach-Object { $_.Execute })
            Arguments             = ConvertTo-FlatString -Value ($actions | ForEach-Object { $_.Arguments })
            WorkingDirectory      = ConvertTo-FlatString -Value ($actions | ForEach-Object { $_.WorkingDirectory })
            TriggerSummary        = ConvertTo-FlatString -Value ($triggers | ForEach-Object { $_.CimClass.CimClassName })
            TriggerStartBoundary  = ConvertTo-FlatString -Value ($triggers | ForEach-Object { $_.StartBoundary })
            TriggerEndBoundary    = ConvertTo-FlatString -Value ($triggers | ForEach-Object { $_.EndBoundary })
            LastRunTime           = $taskInfo.LastRunTime
            NextRunTime           = $taskInfo.NextRunTime
            LastTaskResult        = if ($taskInfo) { $taskInfo.LastTaskResult } else { $null }
            NumberOfMissedRuns    = if ($taskInfo) { $taskInfo.NumberOfMissedRuns } else { $null }
            MultipleInstances     = ConvertTo-FlatString -Value $settings.MultipleInstances
            RestartCount          = ConvertTo-FlatString -Value $settings.RestartCount
            RestartInterval       = ConvertTo-FlatString -Value $settings.RestartInterval
            ExecutionTimeLimit    = ConvertTo-FlatString -Value $settings.ExecutionTimeLimit
            Description           = ConvertTo-FlatString -Value $task.Description
        }
    }
}

function Get-ServiceInventory {
    try {
        $serviceDetails = Get-CimInstance Win32_Service | Sort-Object Name
    }
    catch {
        Write-Warning ("Windows service inventory was skipped: {0}" -f $_.Exception.Message)
        return @()
    }

    foreach ($service in $serviceDetails) {
        [pscustomobject]@{
            Source               = "ServiceControlManager"
            Kind                 = "WindowsService"
            Identifier           = $service.Name
            Name                 = $service.Name
            Path                 = $null
            State                = ConvertTo-FlatString -Value $service.State
            Enabled              = $service.StartMode -ne "Disabled"
            RunAs                = ConvertTo-FlatString -Value $service.StartName
            LogonType            = $null
            RunLevel             = $null
            Execute              = ConvertTo-FlatString -Value $service.PathName
            Arguments            = $null
            WorkingDirectory     = $null
            TriggerSummary       = ConvertTo-FlatString -Value $service.StartMode
            TriggerStartBoundary = $null
            TriggerEndBoundary   = $null
            LastRunTime          = $null
            NextRunTime          = $null
            LastTaskResult       = $null
            NumberOfMissedRuns   = $null
            MultipleInstances    = $null
            RestartCount         = $null
            RestartInterval      = $null
            ExecutionTimeLimit   = $null
            Description          = ConvertTo-FlatString -Value $service.Description
        }
    }
}

function Export-InventorySet {
    param(
        [object[]]$Items,
        [Parameter(Mandatory = $true)]
        [string]$BasePath
    )

    $jsonPath = "$BasePath.json"
    $csvPath = "$BasePath.csv"

    [object[]]$safeItems = @($Items | Where-Object { $null -ne $_ })

    if ($safeItems.Count -eq 0) {
        Set-Content -LiteralPath $jsonPath -Value "[]" -Encoding utf8
        Set-Content -LiteralPath $csvPath -Value "" -Encoding utf8
        return
    }

    $safeItems | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
    $safeItems | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
}

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $OutputDir = Join-Path $repoRoot "artifacts/inventory"
}

New-DirectoryIfMissing -Path $OutputDir

$scheduledTasks = @()
$services = @()
$warnings = [System.Collections.Generic.List[string]]::new()

if (-not $SkipScheduledTasks) {
    $scheduledTasks = @(Get-ScheduledTaskInventory)
    if ($scheduledTasks.Count -eq 0) {
        $warnings.Add("Scheduled task inventory returned no rows. The current shell may not have permission to query Task Scheduler.")
    }
    Export-InventorySet -Items $scheduledTasks -BasePath (Join-Path $OutputDir "scheduled-tasks")
}

if (-not $SkipServices) {
    $services = @(Get-ServiceInventory)
    if ($services.Count -eq 0) {
        $warnings.Add("Windows service inventory returned no rows. The current shell may not have permission to query the Service Control Manager.")
    }
    Export-InventorySet -Items $services -BasePath (Join-Path $OutputDir "windows-services")
}

[object[]]$combined = @($scheduledTasks + $services)
$combined = @($combined | Sort-Object Kind, Identifier)
Export-InventorySet -Items $combined -BasePath (Join-Path $OutputDir "operational-inventory")

$summary = [pscustomobject]@{
    GeneratedAtUtc      = (Get-Date).ToUniversalTime().ToString("o")
    OutputDir           = $OutputDir
    ScheduledTaskCount  = $scheduledTasks.Count
    WindowsServiceCount = $services.Count
    CombinedCount       = $combined.Count
    Warnings            = @($warnings)
}

$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $OutputDir "summary.json") -Encoding utf8
$summary
