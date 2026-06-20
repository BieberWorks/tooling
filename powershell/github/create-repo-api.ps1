# Legt ein neues BieberWorks-Consumer-API-Repo an:
# Basis + 'dotnet new bw-api' + Docker-Publish + Consumer-Directory.Build.props.
#
# Hinweis: Das interne SDK-Template 'bieberworks-api' ist weiterhin verfuegbar
# (isHidden: true, fuer Org-interne SDK-Hosts), aber Consumer nutzen 'bw-api'.
#
#   .\create-repo-api.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Owner,
    [string]$TargetDirectory = '',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
if (Get-Module -ListAvailable -Name BieberWorks.RepoSetup) {
    Import-Module BieberWorks.RepoSetup -Force
} else {
    Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
}
New-BwApiRepo -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public
