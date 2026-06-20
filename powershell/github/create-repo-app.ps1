# Legt ein neues BieberWorks-Consumer-App-Repo an:
# Basis + 'dotnet new bw-blazor' + Docker-Publish + Consumer-Directory.Build.props.
#
#   .\create-repo-app.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Org,
    [string]$TargetDirectory = '',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo `
    -RepoName $RepoName `
    -Template 'bw-blazor' `
    -Deploy 'docker' `
    -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
    -Org $Org `
    -TargetDirectory $TargetDirectory `
    -Public:$Public
