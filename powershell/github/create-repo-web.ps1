# Legt ein neues BieberWorks-Web-Repo an: Basis + 'dotnet new bieberworks-web' + Docker-Publish.
# HINWEIS: Das Template 'bieberworks-web' muss im DotnetTemplates-Paket existieren.
#
#   .\create-repo-web.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo -RepoName $RepoName -Template 'bieberworks-web' -Deploy 'docker' -Org $Org -Public:$Public
