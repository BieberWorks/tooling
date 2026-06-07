# Legt ein neues BieberWorks-SDK-Repo an: Basis-Geruest + build/test-CI +
# leere Standard-Ordner (src/tests/docs) + Solution. Branches main/staging/dev (Default dev).
# Danach im Repo-Ordner optional: add-package-deployment.ps1 und/oder add-docker-publish.ps1
#
#   .\create-repo.ps1 -RepoName <Name>            # privat (default), Org BieberWorks
#   .\create-repo.ps1 -RepoName <Name> -Public    # oeffentlich (ermoeglicht Branch Protection)
param(
    [Parameter(Mandatory)][string]$RepoName,
    [string]$Org = 'BieberWorks',
    [switch]$Public
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\BieberWorks.RepoSetup\BieberWorks.RepoSetup.psd1') -Force
New-BwRepo -RepoName $RepoName -Org $Org -Public:$Public
