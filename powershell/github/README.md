# Repo-Setup-Scripts (PowerShell)

Modulares Setup neuer **BieberWorks-SDK-Repos**. Die Scripts sind duenne Wrapper
um das Modul [`BieberWorks.RepoSetup`](../modules/BieberWorks.RepoSetup) — die
gesamte Logik (und die statischen Datei-Inhalte unter [`../../templates`](../../templates))
liegt zentral, kein Doppel-Code. Eine 1:1-Bash-Variante liegt unter [`../../bash/github`](../../bash/github).

## Flow: Create-Repo -> Add-Publish

```powershell
# 1. Basis-Repo anlegen (Geruest + build/test-CI, Remote, Branches main/staging/dev, Default dev)
.\create-repo.ps1 -RepoName Users                 # privat (default), Org BieberWorks
.\create-repo.ps1 -RepoName Users -Public         # oeffentlich (ermoeglicht Branch Protection)

# 2. Release-Schicht(en) im Repo-Ordner ergaenzen
cd Users
..\add-package-deployment.ps1                      # NuGet-Release (staging=-rc, main=final)
..\add-docker-publish.ps1                          # Docker-Image -> GHCR
```

## Scripts

| Script | Wirkung |
|---|---|
| `create-repo.ps1` | Ordner + `git init`; LICENSE, `.gitignore`, README, `Directory.Build.props`, `src/`/`tests/`/`docs/`, `nuget.config`, `ci.yml` (build/test-Caller). `gh repo create` + Push, Branches **immer** main/staging/dev (Default `dev`), Branch-Protection nur bei `-Public`. |
| `add-package-deployment.ps1` | Ergaenzt `release.yml` (Caller -> `nuget-release.yml`) im aktuellen Repo. `Directory.Build.props` nur falls fehlend. Commit + Push. |
| `add-docker-publish.ps1` | Ergaenzt `docker-publish.yml` (Caller -> `docker-publish.yml`). `Dockerfile`/`.dockerignore` nur falls fehlend (kein Ueberschreiben). Commit + Push. |

Die Add-Scripts laufen im **aktuellen** Repo-Ordner und sind dadurch auch auf
bestehende Repos anwendbar.

## Hinweis: PACKAGES_TOKEN

Sobald ein Repo interne BieberWorks-Pakete referenziert, muss das Repo-Secret
`PACKAGES_TOKEN` (PAT, `read:packages`) gesetzt sein — `create-repo.ps1` erinnert
am Ende daran:

```powershell
gh secret set PACKAGES_TOKEN --repo BieberWorks/<RepoName>
```
