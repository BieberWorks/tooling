# BieberWorks.tooling

Zentrales Build- und Setup-Tooling für das **BieberWorks SDK**. Öffentlich, damit
die **reusable Workflows** von den (privaten) SDK-Repos referenziert werden können.
Enthält **keine** Secrets — Tokens kommen via `secrets: inherit` aus dem nutzenden Repo.

## Reusable Workflows (`.github/workflows/`)

| Workflow | Zweck | Aufruf |
|---|---|---|
| `nuget-release.yml` | Tagging + Pack + Push (GitHub Packages) + Release | `uses: BieberWorks/tooling/.github/workflows/nuget-release.yml@main` |
| `dotnet-ci.yml` | Build (+ optional Test) gegen GitHub Packages | `uses: BieberWorks/tooling/.github/workflows/dotnet-ci.yml@main` |
| `docker-publish.yml` | Image bauen + nach GHCR pushen (BuildKit-Secret für privaten Restore) | `uses: BieberWorks/tooling/.github/workflows/docker-publish.yml@main` |

Beispiel-Caller in einem Modul-Repo (`.github/workflows/release.yml`):
```yaml
name: Release & Publish
on:
  push:
    branches: [main, staging]
jobs:
  release:
    uses: BieberWorks/tooling/.github/workflows/nuget-release.yml@main
    secrets: inherit
```

> **Versionierung:** Caller referenzieren aktuell `@main` (immer aktuell, kein Drift).
> Sobald die Workflows stabil sind, kann auf einen Tag (`@v1`) gepinnt werden, damit
> Änderungen nicht alle Repos auf einmal treffen.

## Setup-Scripts (`powershell/`, `bash/`)

`powershell/github/init-nuget-repo.ps1` legt ein neues SDK-Repo an (Branch-Flow,
Caller-Workflows, LICENSE, `Directory.Build.props`). Mit `-Template <shortName>`
entsteht statt einer NuGet-Modul-Hülle ein App-Host via `dotnet new`.

```powershell
.\init-nuget-repo.ps1 -RepoName <Name>                       # NuGet-Modul
.\init-nuget-repo.ps1 -RepoName <Name> -Template bieberworks-api  # App-Host
```

## Lizenz

Proprietär — siehe [LICENSE](LICENSE). Öffentlich sichtbar ≠ OSS.
