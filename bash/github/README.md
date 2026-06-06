# Repo-Setup-Scripts (Bash)

Modulares Setup neuer **BieberWorks-SDK-Repos**. Die Scripts sourcen nur die
geteilte Lib [`../lib/repo-setup.sh`](../lib/repo-setup.sh); die statischen
Datei-Inhalte liegen zentral unter [`../../templates`](../../templates) — kein
Doppel-Code. Eine 1:1-PowerShell-Variante liegt unter [`../../powershell/github`](../../powershell/github).

## Flow: Create-Repo -> Add-Publish

```bash
# 1. Basis-Repo anlegen (Geruest + build/test-CI, Remote, Branches main/staging/dev, Default dev)
./create-repo.sh Users                 # privat (default), Org BieberWorks
./create-repo.sh Users --public        # oeffentlich (ermoeglicht Branch Protection)
./create-repo.sh Users --org OtherOrg  # andere Organisation

# 2. Release-Schicht(en) im Repo-Ordner ergaenzen
cd Users
../github/add-package-deployment.sh    # NuGet-Release (staging=-rc, main=final)
../github/add-docker-publish.sh        # Docker-Image -> GHCR
```

## Scripts

| Script | Wirkung |
|---|---|
| `create-repo.sh` | Ordner + `git init`; LICENSE, `.gitignore`, README, `Directory.Build.props`, `src/`/`tests/`/`docs/`, `nuget.config`, `ci.yml` (build/test-Caller). `gh repo create` + Push, Branches **immer** main/staging/dev (Default `dev`), Branch-Protection nur bei `--public`. |
| `add-package-deployment.sh` | Ergaenzt `release.yml` (Caller -> `nuget-release.yml`) im aktuellen Repo. `Directory.Build.props` nur falls fehlend. Commit + Push. |
| `add-docker-publish.sh` | Ergaenzt `docker-publish.yml` (Caller -> `docker-publish.yml`). `Dockerfile`/`.dockerignore` nur falls fehlend (kein Ueberschreiben). Commit + Push. |

Die Add-Scripts laufen im **aktuellen** Repo-Ordner und sind dadurch auch auf
bestehende Repos anwendbar.

## Hinweis: PACKAGES_TOKEN

Sobald ein Repo interne BieberWorks-Pakete referenziert, muss das Repo-Secret
`PACKAGES_TOKEN` (PAT, `read:packages`) gesetzt sein — `create-repo.sh` erinnert
am Ende daran:

```bash
gh secret set PACKAGES_TOKEN --repo BieberWorks/<RepoName>
```
