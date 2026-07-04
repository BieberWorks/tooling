# Legt ein neues BieberWorks-Modul-Repo an: Basis + 'dotnet new bieberworks-module'
# (Contracts + Impl + Tests) + NuGet-Package-Deployment. Branches main/staging/dev (Default dev).
# HINWEIS: Das Template 'bieberworks-module' muss im DotnetTemplates-Paket existieren.
#
#   .\create-repo-module.ps1 -RepoName <Name> [-NoPersistence] [-Public]
#
# -NoPersistence: Modul OHNE DbContext/EF/Migrations (In-Memory-Service), z.B. RateLimiting.
param(
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Owner,
    [string]$TargetDirectory = '',
    [switch]$NoPersistence,
    [switch]$Public
)
$ErrorActionPreference = 'Stop'

if ($RepoName -notmatch '^SDK-') {
    $suggested = "SDK-$RepoName"
    Write-Error "Fachmodul-Repos muessen nach Konvention 'SDK-<Name>' heissen. Bitte '-RepoName $suggested' verwenden."
    exit 1
}

# dotnet new braucht einen Punktnamen: BieberWorks.SDK.<Name> (SDK- Praefix entfernen).
# Das Template extrahiert das letzte Punkt-Segment als Klassen-/Dateinamen (z.B. 'Forum').
$ModuleName  = $RepoName -replace '^SDK-', ''
$DotnetName  = "BieberWorks.SDK.$ModuleName"

if (Get-Module -ListAvailable -Name BieberWorks.RepoSetup) {
    Import-Module BieberWorks.RepoSetup -Force
} else {
    Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
}
New-BwModuleRepo -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -NoPersistence:$NoPersistence -Public:$Public
