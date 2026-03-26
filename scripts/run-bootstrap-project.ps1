Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $repoRoot "logs"

if (-not (Test-Path -LiteralPath $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $logDir "bootstrap-project-$timestamp.log"

Set-Location $repoRoot

try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "bootstrap-project.ps1") *>&1 |
        Tee-Object -FilePath $logPath
}
catch {
    $_ | Out-String | Tee-Object -FilePath $logPath -Append | Out-Host
    throw
}
