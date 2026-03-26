[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PublishDir,

    [string]$ServiceName = "DaemonPlatform.Worker",
    [string]$ExecutableName = "DaemonHost.Worker.exe",
    [string]$NodeConfigFile,
    [switch]$SkipStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedPublishDir = (Resolve-Path $PublishDir).Path
$exePath = Join-Path $resolvedPublishDir $ExecutableName

if (-not (Test-Path -LiteralPath $exePath)) {
    throw "No se encontro el ejecutable del Worker en '$exePath'."
}

if ($NodeConfigFile) {
    Copy-Item -LiteralPath $NodeConfigFile -Destination (Join-Path $resolvedPublishDir "appsettings.Local.json") -Force
}

$existingService = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existingService) {
    if ($existingService.Status -ne "Stopped") {
        Stop-Service -Name $ServiceName -Force -ErrorAction Stop
    }

    sc.exe delete $ServiceName | Out-Null
    Start-Sleep -Seconds 2
}

$quotedExe = '"' + $exePath + '"'
$quotedDisplayName = '"' + $ServiceName + '"'
sc.exe create $ServiceName binPath= $quotedExe start= auto DisplayName= $quotedDisplayName | Out-Null
sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/""/0 | Out-Null

if (-not $SkipStart) {
    Start-Service -Name $ServiceName
}

Write-Host "Servicio registrado: $ServiceName"
Write-Host "Directorio publicado: $resolvedPublishDir"
if ($NodeConfigFile) {
    Write-Host "Configuracion nodo copiada a appsettings.Local.json"
}
Write-Host "Nota: la identidad del servicio (cuenta/gMSA) debe configurarse por Infra segun la politica corporativa."
