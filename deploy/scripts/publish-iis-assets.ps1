[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$OutputRoot = ".\deploy\published",
    [string]$ApiNodeConfigFile,
    [string]$WebNodeConfigFile,
    [string]$DotNetPath = "dotnet"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$apiProject = Join-Path $repoRoot "src\DaemonAdmin.Api\DaemonAdmin.Api.csproj"
$webProject = Join-Path $repoRoot "src\DaemonAdmin.Web\DaemonAdmin.Web.csproj"
$apiOutput = Join-Path $repoRoot (Join-Path $OutputRoot "DaemonAdmin.Api")
$webOutput = Join-Path $repoRoot (Join-Path $OutputRoot "DaemonAdmin.Web")

function Publish-Project {
    param(
        [string]$ProjectPath,
        [string]$OutputPath
    )

    & $DotNetPath publish $ProjectPath -c $Configuration -o $OutputPath
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish fallo para $ProjectPath"
    }
}

Publish-Project -ProjectPath $apiProject -OutputPath $apiOutput
Publish-Project -ProjectPath $webProject -OutputPath $webOutput

if ($ApiNodeConfigFile) {
    Copy-Item -LiteralPath $ApiNodeConfigFile -Destination (Join-Path $apiOutput "appsettings.Local.json") -Force
}

if ($WebNodeConfigFile) {
    Copy-Item -LiteralPath $WebNodeConfigFile -Destination (Join-Path $webOutput "appsettings.Local.json") -Force
}

Write-Host "API publicada en: $apiOutput"
Write-Host "Web publicada en: $webOutput"
