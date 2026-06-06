param (
    [Parameter(Mandatory=$true)]
    [string]$RepoName,

    # Ziel-Organisation. Default: BieberWorks (SDK-Module).
    [string]$Org = "BieberWorks",

    # Standard ist PRIVATE. Mit -Public wird das Repo oeffentlich erstellt
    # (nur dann ist Branch Protection auf dem Free-Plan moeglich).
    [switch]$Public,

    # OPTIONAL: dotnet-new-ShortName (z.B. "bieberworks-api"). Wenn gesetzt, wird
    # statt einer NuGet-Modul-Huelle ein lauffaehiges App-Host-Repo via `dotnet new`
    # erzeugt (kein Paket-Release, daher main+dev statt main+staging+dev).
    [string]$Template = ""
)

$ErrorActionPreference = "Stop"

# --- Helper: schreibt Dateien als UTF-8 OHNE BOM (PS 5.1 wuerde sonst UTF-16/BOM erzeugen) ---
function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $full = Join-Path (Get-Location) $Path
    $dir = Split-Path $full -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText($full, $Content, (New-Object System.Text.UTF8Encoding $false))
}

$Visibility = if ($Public) { "--public" } else { "--private" }
$GithubUser = (gh api user | ConvertFrom-Json).login
$IsApp = [bool]$Template

$mode = if ($IsApp) { "App-Host via '$Template'" } else { "NuGet-Modul" }
Write-Host "==> $mode-Repo: $Org/$RepoName  (Owner-Account: $GithubUser, $Visibility)" -ForegroundColor Cyan

# 1. Lokalen Ordner + Git
New-Item -ItemType Directory -Force -Path $RepoName | Out-Null
Set-Location -Path $RepoName
git init -b main

# 2. LICENSE - proprietaer (gemeinsam fuer beide Modi)
Write-Host "==> Lege LICENSE (proprietaer) an..." -ForegroundColor Cyan
$year = (Get-Date).Year
$license = @"
Copyright (c) $year Pierre Bieber. Alle Rechte vorbehalten.

Diese Software und der zugehoerige Quellcode sind urheberrechtlich geschuetzt
und vertraulich (proprietary and confidential). Jede Nutzung, Vervielfaeltigung,
Verbreitung oder Veraenderung ohne ausdrueckliche schriftliche Genehmigung des
Urhebers ist untersagt.
"@
Write-Utf8NoBom -Path "LICENSE" -Content $license

if ($IsApp) {
    # ========================================================================
    # APP-HOST-MODUS: Projekt via `dotnet new <Template>` erzeugen.
    # Das Template bringt csproj, Program.cs, appsettings, nuget.config und
    # eine eigene README/.gitignore mit (single source = das NuGet-Template-Paket).
    # ========================================================================
    Write-Host "==> Stelle sicher, dass das Template-Paket installiert ist..." -ForegroundColor Cyan
    $available = (dotnet new list $Template 2>$null | Select-String -SimpleMatch $Template)
    if (-not $available) {
        Write-Host "    '$Template' nicht gefunden - versuche 'dotnet new install BieberWorks.Templates'..." -ForegroundColor Yellow
        dotnet new install BieberWorks.Templates 2>&1 | Out-Null
        $available = (dotnet new list $Template 2>$null | Select-String -SimpleMatch $Template)
        if (-not $available) {
            throw "Template '$Template' nicht verfuegbar. Erst 'dotnet new install BieberWorks.Templates' (GitHub-Packages-Auth noetig), dann erneut ausfuehren."
        }
    }

    Write-Host "==> Erzeuge App via 'dotnet new $Template -n $RepoName'..." -ForegroundColor Cyan
    dotnet new $Template -n $RepoName -o .

} else {
    # ========================================================================
    # NUGET-MODUL-MODUS: klassische Paket-Huelle (src/tests/docs + Build-Props).
    # ========================================================================

    # Best-Practice-Ordnerstruktur (NuGet-Modul: src/tests/docs, KEIN deploy)
    Write-Host "==> Erstelle Ordnerstruktur..." -ForegroundColor Cyan
    foreach ($folder in @(".github/workflows", "src", "tests", "docs")) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        if ($folder -ne ".github/workflows") {
            New-Item -ItemType File -Force -Path "$folder/.gitkeep" | Out-Null
        }
    }

    # .gitignore - VisualStudio als Basis (offizielle github/gitignore) + eigene Ergaenzungen
    Write-Host "==> Lege .gitignore (VisualStudio-Basis) an..." -ForegroundColor Cyan
    $gitignore = $null
    try {
        $gitignore = Invoke-RestMethod -Uri "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore"
    } catch {
        Write-Host "    Download fehlgeschlagen, Fallback auf 'dotnet new gitignore'." -ForegroundColor Yellow
        dotnet new gitignore | Out-Null
        $gitignore = Get-Content -Raw -Path ".gitignore"
    }
    $customIgnore = @'

# --- BieberWorks ---
artifacts/
local-nuget-feed/
*.env
.env.*
'@
    Write-Utf8NoBom -Path ".gitignore" -Content ($gitignore + $customIgnore)

    # README.md (single-quoted Here-String => Backticks literal; Platzhalter danach ersetzen)
    Write-Host "==> Lege README.md an..." -ForegroundColor Cyan
    $readme = @'
# __REPO__

Teil des **BieberWorks SDK** - privates, modulares .NET-Fundament.
Veroeffentlicht als NuGet-Paket(e) in den **GitHub Packages** der Organisation `__ORG__` (token-geschuetzt).

## Installation

In `nuget.config` die private Quelle ergaenzen:

```xml
<add key="bieberworks" value="https://nuget.pkg.github.com/__ORG__/index.json" />
```

Authentifizierung via PAT mit `read:packages` (NICHT committen):

```powershell
dotnet nuget add source "https://nuget.pkg.github.com/__ORG__/index.json" `
  --name bieberworks --username __USER__ --password <PAT> --store-password-in-clear-text
```

Dann: `dotnet add package <Paketname>`

## Branch-Flow

`main` <- `staging` <- `dev`  (Default-Branch: `dev`)
Feature-Branch -> PR gegen `dev` -> `staging` -> `main` (Release).

## Versionierung & Release

Push auf `main` taggt automatisch (SemVer) und veroeffentlicht die Pakete.
`staging` erzeugt `-rc` Pre-Releases.

## Lizenz

Proprietaer - siehe [LICENSE](./LICENSE).
'@
    $readme = $readme.Replace('__REPO__', $RepoName).Replace('__ORG__', $Org).Replace('__USER__', $GithubUser)
    Write-Utf8NoBom -Path "README.md" -Content $readme

    # nuget.config - nur nuget.org committen (private Quelle wird in CI/lokal mit Token ergaenzt)
    $nugetConfig = @'
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <packageSources>
    <clear />
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
  </packageSources>
</configuration>
'@
    Write-Utf8NoBom -Path "nuget.config" -Content $nugetConfig

    # Directory.Build.props - zentrales artifacts-Layout + Paket-Praefix-Logik (erprobte Vorlage)
    Write-Host "==> Lege Directory.Build.props an (artifacts + Paket-Praefix)..." -ForegroundColor Cyan
    $dirBuildProps = @'
<Project>

  <!--
    ============================================================
    Shared MSBuild properties (BieberWorks SDK module repo).
    HINWEIS: KEIN <TargetFramework> hier setzen - das bricht den
    .slnx-Restore. TFM bleibt pro .csproj.
    ============================================================
  -->

  <PropertyGroup>
    <!-- bin/obj/package zentral nach ./artifacts. MUSS in Directory.Build.props
         stehen (nicht im .csproj), damit MSBuild es vor dem Projekt-Load auswertet. -->
    <UseArtifactsOutput>true</UseArtifactsOutput>
    <ArtifactsPath>$(MSBuildThisFileDirectory)artifacts</ArtifactsPath>
  </PropertyGroup>

  <!-- Repo-Identitaet -->
  <PropertyGroup>
    <PackagePrefix>__ORG__</PackagePrefix>
    <Company>__ORG__</Company>
    <Authors>Pierre Bieber</Authors>
    <RepositoryUrl>https://github.com/__ORG__/__REPO__</RepositoryUrl>
  </PropertyGroup>

  <!-- Code-Qualitaet -->
  <PropertyGroup>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest</AnalysisLevel>
    <TreatWarningsAsErrors>false</TreatWarningsAsErrors>
    <CodeAnalysisTreatWarningsAsErrors>false</CodeAnalysisTreatWarningsAsErrors>
  </PropertyGroup>

  <!-- Paket-Identitaet aus Projektnamen; nur fuer echte .csproj (nicht .slnx). -->
  <PropertyGroup Condition="'$(MSBuildProjectExtension)' == '.csproj'">
    <PackageId>$(PackagePrefix).$(MSBuildProjectName)</PackageId>
    <RootNamespace>$(PackagePrefix).$(MSBuildProjectName)</RootNamespace>
    <AssemblyName>$(PackagePrefix).$(MSBuildProjectName)</AssemblyName>
  </PropertyGroup>

</Project>
'@
    $dirBuildProps = $dirBuildProps.Replace('__ORG__', $Org).Replace('__REPO__', $RepoName)
    Write-Utf8NoBom -Path "Directory.Build.props" -Content $dirBuildProps

    # tests/Directory.Build.props - verkettet zur Root (UseArtifactsOutput erben) + nicht packen
    $testsBuildProps = @'
<Project>
  <!-- Zur Repo-Root-Props verketten, damit UseArtifactsOutput auch fuer Tests greift. -->
  <Import Project="$([MSBuild]::GetPathOfFileAbove('Directory.Build.props', '$(MSBuildThisFileDirectory)../'))" />
  <PropertyGroup>
    <IsPackable>false</IsPackable>
  </PropertyGroup>
</Project>
'@
    Write-Utf8NoBom -Path "tests/Directory.Build.props" -Content $testsBuildProps

    # Workflow: Release & Publish (Caller -> reusable Workflow im tooling-Repo)
    $releaseWorkflow = @'
name: Release & Publish
on:
  push:
    branches: [main, staging]
jobs:
  release:
    uses: BieberWorks/tooling/.github/workflows/nuget-release.yml@main
    secrets: inherit
'@
    Write-Utf8NoBom -Path ".github/workflows/release.yml" -Content $releaseWorkflow

    # Workflow: CI (Caller -> reusable Workflow im tooling-Repo)
    $ciWorkflow = @'
name: CI
on:
  pull_request:
    branches: [dev, staging, main]
jobs:
  ci:
    uses: BieberWorks/tooling/.github/workflows/dotnet-ci.yml@main
    secrets: inherit
'@
    Write-Utf8NoBom -Path ".github/workflows/ci.yml" -Content $ciWorkflow
}

# 3. Initialer Commit
$commitMsg = if ($IsApp) { "chore: initial $Template host scaffold (license)" } else { "chore: initial nuget module scaffold (ci/cd, gitignore, license)" }
git add .
git commit -m $commitMsg

# 4. Remote-Repo in der ORG erstellen + pushen (pusht main)
Write-Host "==> Erstelle Remote-Repo $Org/$RepoName..." -ForegroundColor Cyan
gh repo create "$Org/$RepoName" $Visibility --source=. --remote=origin --push

# 5. Branches: App-Repo = main+dev (kein -rc/staging); Modul = main+staging+dev
Write-Host "==> Erstelle Branches..." -ForegroundColor Cyan
if (-not $IsApp) {
    git checkout -b staging; git push -u origin staging
}
git checkout -b dev; git push -u origin dev
git checkout dev

# 6. Default-Branch = dev
gh repo edit "$Org/$RepoName" --default-branch dev

# 7. Branch Protection - nur bei PUBLIC moeglich (Free-Plan erlaubt es nicht fuer private)
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
    $branches = if ($IsApp) { @("main", "dev") } else { @("main", "staging", "dev") }
    foreach ($branch in $branches) {
        try {
            $protection | gh api --method PUT "/repos/$Org/$RepoName/branches/$branch/protection" --input - | Out-Null
            Write-Host "    geschuetzt: $branch" -ForegroundColor Gray
        } catch {
            Write-Host "    Protection fuer '$branch' fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "==> Privates Repo auf Free-Plan: Branch Protection nicht verfuegbar - uebersprungen." -ForegroundColor DarkGray
    Write-Host "    (Branch-Flow gilt als Konvention; spaeter via Team-Plan erzwingbar.)" -ForegroundColor DarkGray
}

# 8. Hinweis: PACKAGES_TOKEN Repo-Secret (Pflicht, sobald interne BieberWorks-Pakete referenziert werden)
Write-Host ""
Write-Host "==> WICHTIG: Repo-Secret 'PACKAGES_TOKEN' setzen, sobald dieses Repo interne Pakete nutzt." -ForegroundColor Yellow
Write-Host "    GITHUB_TOKEN kann keine Pakete aus anderen Org-Repos lesen (403); im Free-Tier sind"
Write-Host "    Org-Secrets fuer PRIVATE Repos nicht verfuegbar -> PAT (read:packages) pro Repo setzen:"
Write-Host "      gh secret set PACKAGES_TOKEN --repo $Org/$RepoName" -ForegroundColor Cyan
if ($IsApp) {
    Write-Host "    (App-Host referenziert BieberWorks-Module -> ohne Secret schlaegt der lokale/CI-Restore fehl.)"
} else {
    Write-Host "    Ohne dieses Secret schlaegt der CI-Restore interner BieberWorks-Pakete fehl."
}
Write-Host ""
Write-Host "==> Fertig! '$Org/$RepoName' steht bereit (Branch: dev)." -ForegroundColor Green
