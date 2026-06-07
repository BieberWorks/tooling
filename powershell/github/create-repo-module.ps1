# Legt ein neues BieberWorks-Modul-Repo an: Basis + 'dotnet new bieberworks-module'
# (Contracts + Impl + Tests) + NuGet-Package-Deployment. Branches main/staging/dev (Default dev).
# HINWEIS: Das Template 'bieberworks-module' muss im DotnetTemplates-Paket existieren.
#
#   .\create-repo-module.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo -RepoName $RepoName -Template 'bieberworks-module' -Deploy 'packages' -Org $Org -Public:$Public
