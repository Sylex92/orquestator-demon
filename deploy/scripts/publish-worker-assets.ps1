[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$OutputRoot = ".\\deploy\\published",
    [string]$WorkerNodeConfigFile,
    [string]$DotNetPath = "dotnet"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$workerProject = Join-Path $repoRoot "src\\DaemonHost.Worker\\DaemonHost.Worker.csproj"
$workerOutput = Join-Path $repoRoot (Join-Path $OutputRoot "DaemonHost.Worker")

& $DotNetPath publish $workerProject -c $Configuration -o $workerOutput
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish fallo para $workerProject"
}

if ($WorkerNodeConfigFile) {
    Copy-Item -LiteralPath $WorkerNodeConfigFile -Destination (Join-Path $workerOutput "appsettings.Local.json") -Force
}

Write-Host "Worker publicado en: $workerOutput"
if ($WorkerNodeConfigFile) {
    Write-Host "Configuracion de nodo copiada a appsettings.Local.json"
}
