[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SqlServer,

    [int]$SqlPort = 1433,

    [string[]]$CredentialTargets = @(),

    [switch]$CheckIis
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param(
        [string]$Check,
        [bool]$Passed,
        [string]$Details
    )

    $results.Add([pscustomobject]@{
        Check = $Check
        Passed = $Passed
        Details = $Details
    }) | Out-Null
}

try {
    $dotnetInfo = & dotnet --list-runtimes 2>$null
    $hasNet10 = $dotnetInfo | Select-String -Pattern 'Microsoft.NETCore.App 10\.'
    Add-Result -Check ".NET 10 runtime" -Passed ($null -ne $hasNet10) -Details (($hasNet10 | Select-Object -First 1).ToString())
}
catch {
    Add-Result -Check ".NET 10 runtime" -Passed $false -Details $_.Exception.Message
}

try {
    $aspnetInfo = & dotnet --list-runtimes 2>$null
    $hasAspNet10 = $aspnetInfo | Select-String -Pattern 'Microsoft.AspNetCore.App 10\.'
    Add-Result -Check "ASP.NET Core 10 runtime" -Passed ($null -ne $hasAspNet10) -Details (($hasAspNet10 | Select-Object -First 1).ToString())
}
catch {
    Add-Result -Check "ASP.NET Core 10 runtime" -Passed $false -Details $_.Exception.Message
}

if ($CheckIis) {
    try {
        $iisInstalled = $false
        $detail = ""

        if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
            $feature = Get-WindowsFeature -Name Web-Server
            $iisInstalled = $feature -and $feature.InstallState -eq "Installed"
            $detail = if ($feature) { "Web-Server: $($feature.InstallState)" } else { "No se encontro feature Web-Server." }
        }
        else {
            $service = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
            $iisInstalled = $null -ne $service
            $detail = if ($service) { "Servicio W3SVC encontrado: $($service.Status)" } else { "No se encontro W3SVC." }
        }

        Add-Result -Check "IIS" -Passed $iisInstalled -Details $detail
    }
    catch {
        Add-Result -Check "IIS" -Passed $false -Details $_.Exception.Message
    }
}

try {
    $sqlConnectivity = Test-NetConnection -ComputerName $SqlServer -Port $SqlPort -InformationLevel Quiet -WarningAction SilentlyContinue
    Add-Result -Check "Conectividad SQL" -Passed ([bool]$sqlConnectivity) -Details "$SqlServer`:$SqlPort"
}
catch {
    Add-Result -Check "Conectividad SQL" -Passed $false -Details $_.Exception.Message
}

foreach ($target in $CredentialTargets) {
    try {
        $cmdkeyOutput = cmdkey /list | Out-String
        $exists = $cmdkeyOutput -match [regex]::Escape($target)
        Add-Result -Check "Credential Manager: $target" -Passed $exists -Details ($(if ($exists) { "Target encontrado." } else { "Target no encontrado." }))
    }
    catch {
        Add-Result -Check "Credential Manager: $target" -Passed $false -Details $_.Exception.Message
    }
}

$results | Format-Table -AutoSize

$failed = $results | Where-Object { -not $_.Passed }
if ($failed.Count -gt 0) {
    throw "Fallaron $($failed.Count) validaciones de prerrequisitos."
}

Write-Host "Validacion completada correctamente."
