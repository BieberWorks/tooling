# Legt ein neues BieberWorks-Consumer-API-Repo an:
# Basis + 'dotnet new bw-api' + Docker-Publish + Consumer-Directory.Build.props.
#
# Hinweis: Das interne SDK-Template 'bieberworks-api' ist weiterhin verfuegbar
# (isHidden: true, fuer Org-interne SDK-Hosts), aber Consumer nutzen 'bw-api'.
#
#   .\create-repo-api.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [string]$TargetDirectory = '',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwTemplateRepo `
    -RepoName $RepoName `
    -Template 'bw-api' `
    -Deploy 'docker' `
    -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
    -Org $Org `
    -TargetDirectory $TargetDirectory `
    -Public:$Public
