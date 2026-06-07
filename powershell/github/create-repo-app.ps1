# Legt ein neues BieberWorks-App-Repo an: Basis + 'dotnet new bieberworks-app' + Docker-Publish.
# HINWEIS: Das Template 'bieberworks-app' muss im DotnetTemplates-Paket existieren.
#
#   .\create-repo-app.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo -RepoName $RepoName -Template 'bieberworks-app' -Deploy 'docker' -Org $Org -Public:$Public
