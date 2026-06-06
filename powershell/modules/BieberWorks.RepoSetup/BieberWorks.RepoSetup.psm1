# BieberWorks.RepoSetup
# Geteilte Bausteine fuer das Setup neuer BieberWorks-SDK-Repos.
# Die duennen Scripts unter powershell/github/ importieren nur dieses Modul.
# Statische Datei-Inhalte leben als Single-Source unter ../../../templates/.

$ErrorActionPreference = 'Stop'

# templates/ liegt relativ zum Modul: <repo>/templates, Modul: <repo>/powershell/modules/BieberWorks.RepoSetup
$script:TemplateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\templates')).Path

# --- Helper -----------------------------------------------------------------

# Schreibt UTF-8 OHNE BOM (PS 5.1 wuerde sonst UTF-16/BOM erzeugen). Pfad relativ zum CWD.
function Write-Utf8NoBom {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Content)
    $full = Join-Path (Get-Location) $Path
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding $false))
}

# Liest ein Template aus templates/ und ersetzt __ORG__/__REPO__/__USER__/__YEAR__.
function Expand-BwTemplate {
    param([Parameter(Mandatory)][string]$Name, [hashtable]$Tokens = @{})
    $raw = [System.IO.File]::ReadAllText((Join-Path $script:TemplateRoot $Name))
    foreach ($k in $Tokens.Keys) { $raw = $raw.Replace("__${k}__", [string]$Tokens[$k]) }
    return $raw
}

function Get-BwGithubUser {
    return (gh api user | ConvertFrom-Json).login
}

# Ermittelt "Org/Repo" des Repos im CWD (fuer die Add-Scripts, die standalone laufen koennen).
function Get-BwRepoIdentity {
    $nwo = (gh repo view --json nameWithOwner -q .nameWithOwner)
    if (-not $nwo) { throw "Konnte 'Org/Repo' nicht ermitteln - bist du im Repo-Ordner mit gh-Remote?" }
    $parts = $nwo.Split('/')
    return [pscustomobject]@{ Org = $parts[0]; Repo = $parts[1]; NameWithOwner = $nwo }
}

# git add/commit/push auf dem aktuellen Branch.
function Invoke-BwCommitPush {
    param([Parameter(Mandatory)][string]$Message)
    git add .
    git commit -m $Message
    $branch = (git rev-parse --abbrev-ref HEAD).Trim()
    git push origin $branch
}

# --- Schicht 1: Basis-Repo --------------------------------------------------

function New-BwRepoBase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [string]$Org = 'BieberWorks',
        [switch]$Public
    )

    $visibility = if ($Public) { '--public' } else { '--private' }
    $githubUser = Get-BwGithubUser
    $tokens = @{ ORG = $Org; REPO = $RepoName; USER = $githubUser; YEAR = (Get-Date).Year }

    Write-Host "==> Basis-Repo: $Org/$RepoName  (Owner-Account: $githubUser, $visibility)" -ForegroundColor Cyan

    # 1. Lokaler Ordner + Git
    New-Item -ItemType Directory -Force -Path $RepoName | Out-Null
    Set-Location -Path $RepoName
    git init -b main

    # 2. Ordnerstruktur (jedes Repo ist baubar/testbar)
    Write-Host "==> Erstelle Ordnerstruktur..." -ForegroundColor Cyan
    foreach ($folder in @('.github/workflows', 'src', 'tests', 'docs')) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        if ($folder -ne '.github/workflows') {
            New-Item -ItemType File -Force -Path "$folder/.gitkeep" | Out-Null
        }
    }

    # 3. LICENSE (proprietaer)
    Write-Host "==> Lege LICENSE, README, nuget.config, Directory.Build.props an..." -ForegroundColor Cyan
    Write-Utf8NoBom -Path 'LICENSE' -Content (Expand-BwTemplate 'LICENSE.tmpl' $tokens)

    # 4. .gitignore - VisualStudio-Basis (offiziell) + BieberWorks-Anhang
    $gitignore = $null
    try {
        $gitignore = Invoke-RestMethod -Uri 'https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore'
    } catch {
        Write-Host "    gitignore-Download fehlgeschlagen, Fallback auf 'dotnet new gitignore'." -ForegroundColor Yellow
        dotnet new gitignore | Out-Null
        $gitignore = Get-Content -Raw -Path '.gitignore'
    }
    Write-Utf8NoBom -Path '.gitignore' -Content ($gitignore + (Expand-BwTemplate 'gitignore.append'))

    # 5. README, nuget.config, Directory.Build.props (+ tests/)
    Write-Utf8NoBom -Path 'README.md'             -Content (Expand-BwTemplate 'README.module.tmpl' $tokens)
    Write-Utf8NoBom -Path 'nuget.config'          -Content (Expand-BwTemplate 'nuget.config')
    Write-Utf8NoBom -Path 'Directory.Build.props' -Content (Expand-BwTemplate 'Directory.Build.props.tmpl' $tokens)
    Write-Utf8NoBom -Path 'tests/Directory.Build.props' -Content (Expand-BwTemplate 'tests.Directory.Build.props')

    # 6. CI (build/test) - Caller auf den reusable Workflow
    Write-Utf8NoBom -Path '.github/workflows/ci.yml' -Content (Expand-BwTemplate 'workflows/ci.caller.yml')

    # 7. Initialer Commit + Remote-Repo + Push (pusht main)
    git add .
    git commit -m 'chore: initial repo scaffold (base, ci)'
    Write-Host "==> Erstelle Remote-Repo $Org/$RepoName..." -ForegroundColor Cyan
    gh repo create "$Org/$RepoName" $visibility --source=. --remote=origin --push

    # 8. Branches: immer main + staging + dev
    Write-Host "==> Erstelle Branches (staging, dev)..." -ForegroundColor Cyan
    git checkout -b staging; git push -u origin staging
    git checkout -b dev;     git push -u origin dev
    git checkout dev

    # 9. Default-Branch = dev
    gh repo edit "$Org/$RepoName" --default-branch dev

    # 10. Branch Protection - nur bei PUBLIC (Free-Plan kann es fuer private nicht)
    if ($Public) {
        Write-Host "==> Konfiguriere Branch Protection..." -ForegroundColor Cyan
        $protection = @{
            required_status_checks        = $null
            enforce_admins                = $false
            required_pull_request_reviews = @{
                dismiss_stale_reviews           = $true
                require_code_owner_reviews      = $false
                required_approving_review_count = 1
            }
            restrictions                  = $null
        } | ConvertTo-Json -Depth 10
        foreach ($branch in @('main', 'staging', 'dev')) {
            try {
                $protection | gh api --method PUT "/repos/$Org/$RepoName/branches/$branch/protection" --input - | Out-Null
                Write-Host "    geschuetzt: $branch" -ForegroundColor Gray
            } catch {
                Write-Host "    Protection fuer '$branch' fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "==> Privates Repo auf Free-Plan: Branch Protection nicht verfuegbar - uebersprungen." -ForegroundColor DarkGray
    }

    Write-BwPackagesTokenHint -Org $Org -RepoName $RepoName
    Write-Host "==> Fertig! '$Org/$RepoName' steht bereit (Branch: dev)." -ForegroundColor Green
    Write-Host "    Naechster Schritt: add-package-deployment.ps1 und/oder add-docker-publish.ps1 im Repo-Ordner." -ForegroundColor DarkGray
}

function Write-BwPackagesTokenHint {
    param([string]$Org, [string]$RepoName)
    Write-Host ''
    Write-Host "==> WICHTIG: Repo-Secret 'PACKAGES_TOKEN' setzen, sobald dieses Repo interne Pakete nutzt." -ForegroundColor Yellow
    Write-Host "    GITHUB_TOKEN kann keine Pakete aus anderen Org-Repos lesen (403); im Free-Tier sind"
    Write-Host "    Org-Secrets fuer PRIVATE Repos nicht verfuegbar -> PAT (read:packages) pro Repo setzen:"
    Write-Host "      gh secret set PACKAGES_TOKEN --repo $Org/$RepoName" -ForegroundColor Cyan
    Write-Host ''
}

# --- Schicht 2: Package-Deployment (NuGet-Release) --------------------------

function Add-BwPackageDeployment {
    [CmdletBinding()]
    param()

    Write-Host '==> Fuege NuGet-Release-Workflow hinzu...' -ForegroundColor Cyan
    Write-Utf8NoBom -Path '.github/workflows/release.yml' -Content (Expand-BwTemplate 'workflows/nuget-release.caller.yml')

    # Directory.Build.props nur ergaenzen, falls sie fehlt (Basis bringt sie normalerweise schon).
    if (-not (Test-Path 'Directory.Build.props')) {
        Write-Host '    Directory.Build.props fehlt - lege sie aus Template an.' -ForegroundColor Yellow
        $id = Get-BwRepoIdentity
        Write-Utf8NoBom -Path 'Directory.Build.props' -Content (Expand-BwTemplate 'Directory.Build.props.tmpl' @{ ORG = $id.Org; REPO = $id.Repo })
        if (-not (Test-Path 'tests/Directory.Build.props')) {
            Write-Utf8NoBom -Path 'tests/Directory.Build.props' -Content (Expand-BwTemplate 'tests.Directory.Build.props')
        }
    }

    Invoke-BwCommitPush -Message 'chore: add nuget package deployment workflow'
    Write-Host '==> NuGet-Release-Workflow aktiv (Push auf staging=-rc, main=final).' -ForegroundColor Green
}

# --- Schicht 3: Docker-Publish ----------------------------------------------

function Add-BwDockerPublish {
    [CmdletBinding()]
    param()

    Write-Host '==> Fuege Docker-Publish-Workflow hinzu...' -ForegroundColor Cyan
    Write-Utf8NoBom -Path '.github/workflows/docker-publish.yml' -Content (Expand-BwTemplate 'workflows/docker-publish.caller.yml')

    # Dockerfile / .dockerignore nur anlegen, falls noch keins existiert (nicht ueberschreiben).
    if (-not (Test-Path 'Dockerfile')) {
        $id = Get-BwRepoIdentity
        $user = Get-BwGithubUser
        Write-Utf8NoBom -Path 'Dockerfile' -Content (Expand-BwTemplate 'Dockerfile.tmpl' @{ ORG = $id.Org; REPO = $id.Repo; USER = $user })
        Write-Host '    Dockerfile-Stub angelegt - Pfade/ENTRYPOINT anpassen.' -ForegroundColor Yellow
    } else {
        Write-Host '    vorhandenes Dockerfile beibehalten.' -ForegroundColor DarkGray
    }
    if (-not (Test-Path '.dockerignore')) {
        Write-Utf8NoBom -Path '.dockerignore' -Content (Expand-BwTemplate 'dockerignore.base')
    }

    Invoke-BwCommitPush -Message 'chore: add docker publish workflow'
    Write-Host '==> Docker-Publish-Workflow aktiv (Image -> GHCR).' -ForegroundColor Green
}

Export-ModuleMember -Function New-BwRepoBase, Add-BwPackageDeployment, Add-BwDockerPublish, Get-BwGithubUser, Get-BwRepoIdentity
