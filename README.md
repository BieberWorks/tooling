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

Modulares Repo-Setup nach dem Flow **Create-Repo → Add-Publish**. Jedes Script ist
ein dünner Wrapper; die Logik liegt zentral (PS-Modul [`BieberWorks.RepoSetup`](powershell/modules/BieberWorks.RepoSetup)
bzw. Bash-Lib [`bash/lib/repo-setup.sh`](bash/lib/repo-setup.sh)), die statischen
Datei-Inhalte als Single-Source unter [`templates/`](templates) — kein Doppel-Code,
1:1 in PowerShell **und** Bash.

| Schicht | PowerShell | Bash | Wirkung |
|---|---|---|---|
| Basis | `create-repo.ps1` | `create-repo.sh` | Gerüst + build/test-CI, Remote-Repo, Branches **immer** main/staging/dev (Default `dev`) |
| Pakete | `add-package-deployment.ps1` | `add-package-deployment.sh` | NuGet-Release-Workflow (staging=`-rc`, main=final) |
| Docker | `add-docker-publish.ps1` | `add-docker-publish.sh` | Docker-Publish-Workflow (Image → GHCR) |

```powershell
.\create-repo.ps1 -RepoName Users        # Basis-Repo (privat; -Public für Branch Protection)
cd Users
..\add-package-deployment.ps1            # optional: NuGet-Release
..\add-docker-publish.ps1                # optional: Docker-Publish
```

Die `add-*`-Scripts laufen im aktuellen Repo-Ordner → auch auf bestehende Repos
anwendbar. Details: [`powershell/github`](powershell/github) · [`bash/github`](bash/github).

## Lizenz

Proprietär — siehe [LICENSE](LICENSE). Öffentlich sichtbar ≠ OSS.
