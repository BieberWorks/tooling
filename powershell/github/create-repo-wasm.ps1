# Legt ein neues BieberWorks Consumer WASM-Only Repo an:
# Basis + 'dotnet new bw-wasm' + Docker-Publish + Consumer-Directory.Build.props.
#
# Das Template erzeugt einen eigenstaendigen Blazor WebAssembly Client ohne API-Projekt
# im selben Repo. Die API-URL wird in wwwroot/appsettings.json konfiguriert.
# Typischer Use-Case: getrennte Deployment-Einheit (CDN/static hosting) gegen eine
# externe bw-api oder bw-wasm-api.
#
#   .\create-repo-wasm.ps1 -RepoName <Name> [-Public]
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
New-BwWasmRepo -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public
