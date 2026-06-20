# Alias auf create-repo-app.ps1.
# Hintergrund: bieberworks-web war ein Phantom-Template (existierte nie).
# Consumer-Blazor-Apps werden mit 'bw-blazor' via create-repo-app.ps1 angelegt.
#
#   .\create-repo-web.ps1 -RepoName <Name> [-Public]
param(
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Owner,
    [string]$TargetDirectory = '',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'create-repo-app.ps1') -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public
