# Legt ein neues BieberWorks Consumer WASM+API Repo an:
# Basis + 'dotnet new bw-wasm-api' + Docker-Publish + Consumer-Directory.Build.props.
#
# Das Template erzeugt eine Solution mit zwei Projekten:
#   src/Api/   -- ASP.NET Core API-Host mit BieberWorks-Modulen und CORS-Konfiguration
#   src/Client/ -- Blazor WebAssembly Frontend, kommuniziert per HttpClient mit der API
#
#   .\create-repo-wasm-api.ps1 -RepoName <Name> [-Public]
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
    -Template 'bw-wasm-api' `
    -Deploy 'docker' `
    -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
    -Org $Org `
    -TargetDirectory $TargetDirectory `
    -Public:$Public
