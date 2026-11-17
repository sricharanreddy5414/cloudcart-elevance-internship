# Refuse to delete the EverShop PostgreSQL volume.
# This script may remove only containers labelled cloudcart.lab=mysql-security.

$ErrorActionPreference = "Stop"

foreach ($arg in $args) {
    if ($arg -match "postgres-data") {
        Write-Error "Refuse to delete postgres-data"
        exit 1
    }
}

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
    Write-Host "Docker is not available. No containers were changed. postgres-data was not touched."
    exit 0
}

$ids = docker ps -aq --filter "label=cloudcart.lab=mysql-security"
if ($ids) {
    docker rm -f $ids
    Write-Host "Removed MySQL lab containers."
} else {
    Write-Host "No MySQL lab containers were running."
}

Write-Host "postgres-data was not removed."
exit 0
