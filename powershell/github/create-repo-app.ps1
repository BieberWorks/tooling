# Legt ein neues BieberWorks-Consumer-App-Repo an:
# Basis + 'dotnet new bw-blazor' + Docker-Publish + Consumer-Directory.Build.props.
#
#   .\create-repo-app.ps1 -RepoName <Name> [-Public]
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
New-BwAppRepo -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public
