[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TargetName,

    [Parameter(Mandatory = $true)]
    [string]$UserName,

    [Parameter(Mandatory = $true)]
    [string]$Secret
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

cmdkey /generic:$TargetName /user:$UserName /pass:$Secret | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "No se pudo registrar el secreto en Credential Manager."
}

Write-Host "Secreto registrado en Credential Manager. Target=$TargetName"
