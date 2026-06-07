# Legt ein neues BieberWorks-API-Host-Repo an: Basis + 'dotnet new bieberworks-api'
# (API + Tests) + Docker-Publish. Branches main/staging/dev (Default dev).
#
#   .\create-repo-api.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo -RepoName $RepoName -Template 'bieberworks-api' -Deploy 'docker' -Org $Org -Public:$Public
