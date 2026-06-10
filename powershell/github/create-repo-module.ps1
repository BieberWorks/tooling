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

if ($RepoName -notmatch '^SDK-') {
    Write-Host "HINWEIS: Fachmodul-Repos sollten nach Konvention 'SDK-<Name>' heissen (z.B. SDK-Auth, SDK-Email)." -ForegroundColor Yellow
}

# dotnet new braucht einen Punktnamen: BieberWorks.SDK.<Name> (SDK- Praefix entfernen).
# Das Template extrahiert das letzte Punkt-Segment als Klassen-/Dateinamen (z.B. 'Forum').
$ModuleName  = $RepoName -replace '^SDK-', ''
$DotnetName  = "BieberWorks.SDK.$ModuleName"

Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo -RepoName $RepoName -DotnetName $DotnetName -Template 'bieberworks-module' -Deploy 'packages' -Org $Org -Public:$Public
