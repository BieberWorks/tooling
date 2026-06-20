# BieberWorks.RepoSetup
# Geteilte Bausteine fuer das Setup neuer BieberWorks-SDK-Repos.
# Die duennen Scripts unter powershell/github/ importieren nur dieses Modul.
# Statische Datei-Inhalte leben als Single-Source unter ../../../templates/.
#
# Schicht-Architektur:
#   New-BwRepoBase     -> Basis-Geruest (Files + CI + Branches main/staging/dev + Default dev)
#   New-BwRepo         -> Base + leere src/tests/docs + .slnx  (blanko-Repo)
#   New-BwTemplateRepo -> Base + dotnet new <Template> + .slnx + Deploy (api/app/web/module)
#   Add-BwPackageDeployment / Add-BwDockerPublish -> Deployment-Workflows (standalone nutzbar)

$ErrorActionPreference = 'Stop'

# templates/ suchen: zuerst lokales Unterverzeichnis (nach Install-Module), dann relativer Fallback (lokale Repo-Entwicklung)
$localTemplates = Join-Path $PSScriptRoot 'templates'
$script:TemplateRoot = if (Test-Path $localTemplates) {
    $localTemplates
} else {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\templates')).Path
}

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

# Fuegt eine Datei als <File>-Eintrag in einen Solution-Folder einer .slnx ein.
# Legt den Folder an, falls er fehlt. Idempotent (kein Doppel-Eintrag). Nur falls .slnx existiert.
function Add-BwSlnxItem {
    param(
        [Parameter(Mandatory)][string]$SlnxPath,
        [Parameter(Mandatory)][string]$Folder,   # z.B. "/SolutionItems/docker/"
        [Parameter(Mandatory)][string]$FilePath  # z.B. "Dockerfile"
    )
    if (-not (Test-Path $SlnxPath)) { return }
    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $false
    $xml.Load((Join-Path (Get-Location) $SlnxPath))
    $root = $xml.DocumentElement   # <Solution>

    # Folder finden oder anlegen
    $folderNode = $null
    foreach ($f in $root.SelectNodes('Folder')) {
        if ($f.GetAttribute('Name') -eq $Folder) { $folderNode = $f; break }
    }
    if (-not $folderNode) {
        $folderNode = $xml.CreateElement('Folder')
        $folderNode.SetAttribute('Name', $Folder) | Out-Null
        $root.AppendChild($folderNode) | Out-Null
    }

    # Doppel-Eintrag vermeiden
    foreach ($fileEl in $folderNode.SelectNodes('File')) {
        if ($fileEl.GetAttribute('Path') -eq $FilePath) { return }
    }
    $fileNode = $xml.CreateElement('File')
    $fileNode.SetAttribute('Path', $FilePath) | Out-Null
    $folderNode.AppendChild($fileNode) | Out-Null

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = '  '
    $settings.OmitXmlDeclaration = $true
    $settings.Encoding = (New-Object System.Text.UTF8Encoding $false)
    $writer = [System.Xml.XmlWriter]::Create((Join-Path (Get-Location) $SlnxPath), $settings)
    try { $xml.Save($writer) } finally { $writer.Dispose() }
}

function Write-BwPackagesTokenHint {
    param([string]$Owner, [string]$RepoName)
    Write-Host ''
    Write-Host "==> WICHTIG: Repo-Secret 'PACKAGES_TOKEN' setzen, sobald dieses Repo interne Pakete nutzt." -ForegroundColor Yellow
    Write-Host "    GITHUB_TOKEN kann keine Pakete aus anderen Org-Repos lesen (403); im Free-Tier sind"
    Write-Host "    Org-Secrets fuer PRIVATE Repos nicht verfuegbar -> PAT (read:packages) pro Repo setzen:"
    Write-Host "      gh secret set PACKAGES_TOKEN --repo $Owner/$RepoName" -ForegroundColor Cyan
    Write-Host ''
}

# --- Schicht 0: Basis-Repo (Files + CI + Branches, KEINE src/tests/docs) ----

function New-BwRepoBase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [string]$Owner = 'BieberWorks',
        # 'Directory.Build.props.tmpl'          = SDK-Modul (Default)
        # 'Directory.Build.consumer.props.tmpl' = Consumer-App (kein PackagePrefix)
        [string]$DbPropsTemplate = 'Directory.Build.props.tmpl',
        [string]$ReadmeTemplate = 'README.module.tmpl',
        [string]$TargetDirectory = '',
        [switch]$Public
    )

    $visibility = if ($Public) { '--public' } else { '--private' }
    $githubUser = Get-BwGithubUser
    $tokens = @{ ORG = $Owner; REPO = $RepoName; USER = $githubUser; YEAR = (Get-Date).Year }

    Write-Host "==> Basis-Repo: $Owner/$RepoName  (Owner-Account: $githubUser, $visibility)" -ForegroundColor Cyan

    # 1. Lokaler Ordner + Git
    $repoDir = if ($TargetDirectory) {
        Join-Path (Resolve-Path $TargetDirectory) $RepoName
    } else {
        Join-Path (Get-Location) $RepoName
    }
    New-Item -ItemType Directory -Force -Path $repoDir | Out-Null
    Set-Location -Path $repoDir
    git init -b main

    # 2. Nur der Workflows-Ordner (src/tests/docs kommen erst in New-BwRepo / -TemplateRepo)
    New-Item -ItemType Directory -Force -Path '.github/workflows' | Out-Null

    # 3. LICENSE, README, nuget.config, Directory.Build.props
    Write-Host "==> Lege LICENSE, README, nuget.config, Directory.Build.props ($DbPropsTemplate), CI an..." -ForegroundColor Cyan
    Write-Utf8NoBom -Path 'LICENSE'               -Content (Expand-BwTemplate 'LICENSE.tmpl' $tokens)
    Write-Utf8NoBom -Path 'README.md'             -Content (Expand-BwTemplate $ReadmeTemplate $tokens)
    Write-Utf8NoBom -Path 'nuget.config'          -Content (Expand-BwTemplate 'nuget.config')
    Write-Utf8NoBom -Path 'Directory.Build.props' -Content (Expand-BwTemplate $DbPropsTemplate $tokens)

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

    # 5. CI (build/test) - Caller auf den reusable Workflow (run_tests default true)
    Write-Utf8NoBom -Path '.github/workflows/ci.yml' -Content (Expand-BwTemplate 'workflows/ci.caller.yml')

    # 6. Initialer Commit + Remote-Repo + Push (pusht main)
    git add .
    git commit -m 'chore: initial repo scaffold (base, ci)'
    Write-Host "==> Erstelle Remote-Repo $Org/$RepoName..." -ForegroundColor Cyan
    gh repo create "$Owner/$RepoName" $visibility --source=. --remote=origin --push

    # 7. Branches: immer main + staging + dev
    Write-Host "==> Erstelle Branches (staging, dev)..." -ForegroundColor Cyan
    git checkout -b staging; git push -u origin staging
    git checkout -b dev;     git push -u origin dev
    git checkout dev

    # 8. Default-Branch = dev
    gh repo edit "$Owner/$RepoName" --default-branch dev

    # 9. Branch Protection - nur bei PUBLIC (Free-Plan kann es fuer private nicht)
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
                $protection | gh api --method PUT "/repos/$Owner/$RepoName/branches/$branch/protection" --input - | Out-Null
                Write-Host "    geschuetzt: $branch" -ForegroundColor Gray
            } catch {
                Write-Host "    Protection fuer '$branch' fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "==> Privates Repo auf Free-Plan: Branch Protection nicht verfuegbar - uebersprungen." -ForegroundColor DarkGray
    }

    Write-BwPackagesTokenHint -Owner $Owner -RepoName $RepoName
    Write-Host "==> Basis steht (Branch: dev)." -ForegroundColor Green
}

# --- Schicht 1a: Blanko-Repo (Base + leere Ordner + .slnx) ------------------

function New-BwRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [string]$Owner = 'BieberWorks',
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwRepoBase -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public

    Write-Host "==> Lege leere Standard-Ordner (src/tests/docs) + Solution an..." -ForegroundColor Cyan
    foreach ($folder in @('src', 'tests', 'docs')) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        New-Item -ItemType File -Force -Path "$folder/.gitkeep" | Out-Null
    }
    Write-Utf8NoBom -Path 'tests/Directory.Build.props' -Content (Expand-BwTemplate 'tests.Directory.Build.props')
    Write-Utf8NoBom -Path "$RepoName.slnx"               -Content (Expand-BwTemplate 'solution.slnx.tmpl')

    Invoke-BwCommitPush -Message 'chore: add solution skeleton (src/tests/docs, slnx)'
    Write-Host "==> Fertig! '$Owner/$RepoName' steht bereit (Branch: dev)." -ForegroundColor Green
}

# --- Schicht 1b: Typ-Repo via dotnet-new-Template + Deployment ---------------

function New-BwTemplateRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Template,                       # dotnet new shortName
        [Parameter(Mandatory)][ValidateSet('docker', 'packages')][string]$Deploy,
        [string]$DotnetName = '',   # -n Argument fuer dotnet new; Standard = $RepoName
        [string]$Owner = 'BieberWorks',
        # Welches Directory.Build.props-Template verwenden?
        # 'Directory.Build.props.tmpl'          = SDK-Modul (PackagePrefix + NuGet-Publishing, Default)
        # 'Directory.Build.consumer.props.tmpl' = Consumer-App (kein PackagePrefix, kein NuGet-Publishing)
        [string]$DbPropsTemplate = 'Directory.Build.props.tmpl',
        [string]$ReadmeTemplate = 'README.module.tmpl',
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwRepoBase -RepoName $RepoName -Owner $Owner -DbPropsTemplate $DbPropsTemplate -ReadmeTemplate $ReadmeTemplate -TargetDirectory $TargetDirectory -Public:$Public

    $nameArg = if ($DotnetName) { $DotnetName } else { $RepoName }
    Write-Host "==> Solution-Geruest + 'dotnet new $Template -n $nameArg'..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path 'docs' | Out-Null
    New-Item -ItemType File -Force -Path 'docs/.gitkeep' | Out-Null
    Write-Utf8NoBom -Path "$RepoName.slnx" -Content (Expand-BwTemplate 'solution.slnx.tmpl')

    # Template instanziieren in den Repo-Root. Das Template bringt seine Projekte
    # unter src/<Name> (+ tests/<Name>.Tests) mit; KEINE repo-globalen Dateien
    # (die liefert die Basis) und KEINE eigene .slnx.
    dotnet new $Template -n $nameArg -o . --force

    # Alle erzeugten csproj in die Solution aufnehmen (src/ und tests/ getrennt).
    Get-ChildItem -Path 'src'   -Recurse -Filter *.csproj -ErrorAction SilentlyContinue | ForEach-Object {
        dotnet sln "$RepoName.slnx" add $_.FullName --solution-folder src
    }
    Get-ChildItem -Path 'tests' -Recurse -Filter *.csproj -ErrorAction SilentlyContinue | ForEach-Object {
        dotnet sln "$RepoName.slnx" add $_.FullName --solution-folder tests
    }

    Invoke-BwCommitPush -Message "chore: scaffold $Template project + solution"

    if ($Deploy -eq 'docker') { Add-BwDockerPublish } else { Add-BwPackageDeployment }
    Write-Host "==> Fertig! '$Owner/$RepoName' steht bereit (Branch: dev)." -ForegroundColor Green
}

# --- Schicht 2: Package-Deployment (NuGet-Release) --------------------------

function Add-BwPackageDeployment {
    [CmdletBinding()]
    param()

    Write-Host '==> Fuege NuGet-Release-Workflow hinzu...' -ForegroundColor Cyan
    $id = Get-BwRepoIdentity
    # __MODULE__ = Repo-Name ohne 'SDK-' Praefix (lowercase), __REPO__ = voller Repo-Name
    $moduleName = $id.Repo -replace '^SDK-', '' -replace '-', '_'
    $moduleName = $moduleName.Substring(0,1).ToLower() + $moduleName.Substring(1)
    $tokens = @{ MODULE = $moduleName; REPO = $id.Repo }
    Write-Utf8NoBom -Path '.github/workflows/release.yml' -Content (Expand-BwTemplate 'workflows/nuget-release.caller.yml' $tokens)

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

    # Docker-Dateien in der Solution sichtbar machen (SolutionItems/docker), falls .slnx vorhanden.
    $slnx = Get-ChildItem -Path . -Filter *.slnx -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($slnx) {
        Add-BwSlnxItem -SlnxPath $slnx.Name -Folder '/SolutionItems/docker/' -FilePath 'Dockerfile'
        Add-BwSlnxItem -SlnxPath $slnx.Name -Folder '/SolutionItems/docker/' -FilePath '.dockerignore'
    }

    Invoke-BwCommitPush -Message 'chore: add docker publish workflow'
    Write-Host '==> Docker-Publish-Workflow aktiv (Image -> GHCR).' -ForegroundColor Green
}

# --- Schicht 3: High-Level-Wrapper (oeffentliche API) ------------------------

function New-BwModuleRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    if ($RepoName -notmatch '^SDK-') {
        throw "RepoName muss mit 'SDK-' beginnen (z.B. SDK-Forum)."
    }
    $ModuleName = $RepoName -replace '^SDK-', ''
    $DotnetName = "BieberWorks.SDK.$ModuleName"
    New-BwTemplateRepo `
        -RepoName $RepoName `
        -DotnetName $DotnetName `
        -Template 'bieberworks-module' `
        -Deploy 'packages' `
        -DbPropsTemplate 'Directory.Build.props.tmpl' `
        -Owner $Owner `
        -TargetDirectory $TargetDirectory `
        -Public:$Public
}

function New-BwAppRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwTemplateRepo `
        -RepoName $RepoName `
        -Template 'bw-blazor' `
        -Deploy 'docker' `
        -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
        -ReadmeTemplate 'README.consumer.tmpl' `
        -Owner $Owner `
        -TargetDirectory $TargetDirectory `
        -Public:$Public
}

function New-BwApiRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwTemplateRepo `
        -RepoName $RepoName `
        -Template 'bw-api' `
        -Deploy 'docker' `
        -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
        -ReadmeTemplate 'README.consumer.tmpl' `
        -Owner $Owner `
        -TargetDirectory $TargetDirectory `
        -Public:$Public
}

function New-BwWasmApiRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwTemplateRepo `
        -RepoName $RepoName `
        -Template 'bw-wasm-api' `
        -Deploy 'docker' `
        -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
        -ReadmeTemplate 'README.consumer.tmpl' `
        -Owner $Owner `
        -TargetDirectory $TargetDirectory `
        -Public:$Public
}

function New-BwWasmRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwTemplateRepo `
        -RepoName $RepoName `
        -Template 'bw-wasm' `
        -Deploy 'docker' `
        -DbPropsTemplate 'Directory.Build.consumer.props.tmpl' `
        -ReadmeTemplate 'README.consumer.tmpl' `
        -Owner $Owner `
        -TargetDirectory $TargetDirectory `
        -Public:$Public
}

function New-BwBlankRepo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoName,
        [Parameter(Mandatory)][string]$Owner,
        [string]$TargetDirectory = '',
        [switch]$Public
    )
    New-BwRepo -RepoName $RepoName -Owner $Owner -TargetDirectory $TargetDirectory -Public:$Public
}

Export-ModuleMember -Function `
    New-BwModuleRepo, New-BwAppRepo, New-BwApiRepo, `
    New-BwWasmApiRepo, New-BwWasmRepo, New-BwBlankRepo, `
    Get-BwGithubUser, Get-BwRepoIdentity, `
    Add-BwPackageDeployment, Add-BwDockerPublish, Add-BwSlnxItem
