# Prepare a local checkout. Does not start or stop EverShop and does not call AWS.

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created .env from .env.example. Put the local database password there. Do not commit .env."
} else {
    Write-Host ".env already exists and was left unchanged."
}

foreach ($tool in @("python", "node", "git")) {
    $found = Get-Command $tool -ErrorAction SilentlyContinue
    if (-not $found) {
        Write-Warning "$tool was not found on PATH."
    }
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Warning "Docker was not found. Container checks will be blocked."
}

Write-Host "Setup did not run docker compose and did not create AWS resources."
exit 0
