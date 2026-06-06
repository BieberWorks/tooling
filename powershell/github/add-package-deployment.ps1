# Ergaenzt das aktuelle Repo um den NuGet-Release-Workflow (Push staging=-rc, main=final).
# Im Repo-Ordner ausfuehren (nach create-repo.ps1 oder in einem bestehenden Repo).
#
#   cd <RepoName>; ..\add-package-deployment.ps1
param()
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
Add-BwPackageDeployment
