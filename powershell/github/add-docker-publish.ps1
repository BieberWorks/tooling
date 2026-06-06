# Ergaenzt das aktuelle Repo um den Docker-Publish-Workflow (Image -> GHCR).
# Legt Dockerfile/.dockerignore nur an, falls noch keins existiert.
# Im Repo-Ordner ausfuehren (nach create-repo.ps1 oder in einem bestehenden Repo).
#
#   cd <RepoName>; ..\add-docker-publish.ps1
param()
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
Add-BwDockerPublish
