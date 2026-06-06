#!/usr/bin/env bash
# BieberWorks repo-setup library.
# Geteilte Bausteine fuer das Setup neuer BieberWorks-SDK-Repos.
# Die duennen Scripts unter bash/github/ sourcen nur diese Datei.
# Statische Datei-Inhalte leben als Single-Source unter ../../templates/.

set -euo pipefail

# templates/ relativ zur Lib: <repo>/templates, Lib: <repo>/bash/lib
_BW_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BW_TEMPLATE_ROOT="$(cd "$_BW_LIB_DIR/../../templates" && pwd)"

# --- Helper -----------------------------------------------------------------

# Liest ein Template und ersetzt __ORG__/__REPO__/__USER__/__YEAR__ (auf stdout).
# Erwartet die Tokens als globale Variablen BW_ORG / BW_REPO / BW_USER / BW_YEAR
# (fehlende werden als leer behandelt).
bw_expand_template() {
  local name="$1"
  sed \
    -e "s|__ORG__|${BW_ORG:-}|g" \
    -e "s|__REPO__|${BW_REPO:-}|g" \
    -e "s|__USER__|${BW_USER:-}|g" \
    -e "s|__YEAR__|${BW_YEAR:-}|g" \
    "$BW_TEMPLATE_ROOT/$name"
}

# Schreibt ein expandiertes Template in eine Datei (legt Verzeichnis an).
bw_install_template() {
  local name="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  bw_expand_template "$name" > "$dest"
}

bw_github_user() {
  gh api user -q .login
}

# "Org/Repo" des Repos im CWD.
bw_repo_identity() {
  local nwo
  nwo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
  if [ -z "$nwo" ]; then
    echo "Konnte 'Org/Repo' nicht ermitteln - bist du im Repo-Ordner mit gh-Remote?" >&2
    return 1
  fi
  echo "$nwo"
}

bw_commit_push() {
  local msg="$1" branch
  git add .
  git commit -m "$msg"
  branch="$(git rev-parse --abbrev-ref HEAD)"
  git push origin "$branch"
}

bw_packages_token_hint() {
  local org="$1" repo="$2"
  echo ""
  echo "==> WICHTIG: Repo-Secret 'PACKAGES_TOKEN' setzen, sobald dieses Repo interne Pakete nutzt."
  echo "    GITHUB_TOKEN kann keine Pakete aus anderen Org-Repos lesen (403); im Free-Tier sind"
  echo "    Org-Secrets fuer PRIVATE Repos nicht verfuegbar -> PAT (read:packages) pro Repo setzen:"
  echo "      gh secret set PACKAGES_TOKEN --repo $org/$repo"
  echo ""
}

# --- Schicht 1: Basis-Repo --------------------------------------------------

# bw_new_repo_base <RepoName> [Org=BieberWorks] [public|private]
bw_new_repo_base() {
  local repo="$1"
  local org="${2:-BieberWorks}"
  local vis_word="${3:-private}"
  local visibility="--private"
  [ "$vis_word" = "public" ] && visibility="--public"

  export BW_ORG="$org" BW_REPO="$repo"
  BW_USER="$(bw_github_user)"; export BW_USER
  BW_YEAR="$(date +%Y)"; export BW_YEAR

  echo "==> Basis-Repo: $org/$repo  (Owner-Account: $BW_USER, $visibility)"

  # 1. Lokaler Ordner + Git
  mkdir "$repo"
  cd "$repo"
  git init -b main

  # 2. Ordnerstruktur (jedes Repo ist baubar/testbar)
  echo "==> Erstelle Ordnerstruktur..."
  mkdir -p .github/workflows src tests docs
  touch src/.gitkeep tests/.gitkeep docs/.gitkeep

  # 3. LICENSE, README, nuget.config, Directory.Build.props
  echo "==> Lege LICENSE, README, nuget.config, Directory.Build.props an..."
  bw_install_template "LICENSE.tmpl"               "LICENSE"
  bw_install_template "README.module.tmpl"         "README.md"
  bw_install_template "nuget.config"               "nuget.config"
  bw_install_template "Directory.Build.props.tmpl" "Directory.Build.props"
  bw_install_template "tests.Directory.Build.props" "tests/Directory.Build.props"

  # 4. .gitignore - VisualStudio-Basis (offiziell) + BieberWorks-Anhang
  if curl -fsSL "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore" -o .gitignore; then
    :
  else
    echo "    gitignore-Download fehlgeschlagen, Fallback auf 'dotnet new gitignore'."
    dotnet new gitignore >/dev/null
  fi
  bw_expand_template "gitignore.append" >> .gitignore

  # 5. CI (build/test) - Caller auf den reusable Workflow
  bw_install_template "workflows/ci.caller.yml" ".github/workflows/ci.yml"

  # 6. Initialer Commit + Remote-Repo + Push (pusht main)
  git add .
  git commit -m "chore: initial repo scaffold (base, ci)"
  echo "==> Erstelle Remote-Repo $org/$repo..."
  gh repo create "$org/$repo" "$visibility" --source=. --remote=origin --push

  # 7. Branches: immer main + staging + dev
  echo "==> Erstelle Branches (staging, dev)..."
  git checkout -b staging; git push -u origin staging
  git checkout -b dev;     git push -u origin dev
  git checkout dev

  # 8. Default-Branch = dev
  gh repo edit "$org/$repo" --default-branch dev

  # 9. Branch Protection - nur bei PUBLIC (Free-Plan kann es fuer private nicht)
  if [ "$visibility" = "--public" ]; then
    echo "==> Konfiguriere Branch Protection..."
    local protection
    protection='{"required_status_checks":null,"enforce_admins":false,"required_pull_request_reviews":{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1},"restrictions":null}'
    local branch
    for branch in main staging dev; do
      if echo "$protection" | gh api --method PUT "/repos/$org/$repo/branches/$branch/protection" --input - >/dev/null 2>&1; then
        echo "    geschuetzt: $branch"
      else
        echo "    Protection fuer '$branch' fehlgeschlagen (uebersprungen)."
      fi
    done
  else
    echo "==> Privates Repo auf Free-Plan: Branch Protection nicht verfuegbar - uebersprungen."
  fi

  bw_packages_token_hint "$org" "$repo"
  echo "==> Fertig! '$org/$repo' steht bereit (Branch: dev)."
  echo "    Naechster Schritt: add-package-deployment.sh und/oder add-docker-publish.sh im Repo-Ordner."
}

# --- Schicht 2: Package-Deployment (NuGet-Release) --------------------------

bw_add_package_deployment() {
  echo "==> Fuege NuGet-Release-Workflow hinzu..."
  bw_install_template "workflows/nuget-release.caller.yml" ".github/workflows/release.yml"

  # Directory.Build.props nur ergaenzen, falls sie fehlt (Basis bringt sie normalerweise schon).
  if [ ! -f "Directory.Build.props" ]; then
    echo "    Directory.Build.props fehlt - lege sie aus Template an."
    local nwo; nwo="$(bw_repo_identity)"
    export BW_ORG="${nwo%%/*}" BW_REPO="${nwo##*/}"
    bw_install_template "Directory.Build.props.tmpl" "Directory.Build.props"
    [ -f "tests/Directory.Build.props" ] || bw_install_template "tests.Directory.Build.props" "tests/Directory.Build.props"
  fi

  bw_commit_push "chore: add nuget package deployment workflow"
  echo "==> NuGet-Release-Workflow aktiv (Push auf staging=-rc, main=final)."
}

# --- Schicht 3: Docker-Publish ----------------------------------------------

bw_add_docker_publish() {
  echo "==> Fuege Docker-Publish-Workflow hinzu..."
  bw_install_template "workflows/docker-publish.caller.yml" ".github/workflows/docker-publish.yml"

  # Dockerfile / .dockerignore nur anlegen, falls noch keins existiert (nicht ueberschreiben).
  if [ ! -f "Dockerfile" ]; then
    local nwo; nwo="$(bw_repo_identity)"
    export BW_ORG="${nwo%%/*}" BW_REPO="${nwo##*/}"
    BW_USER="$(bw_github_user)"; export BW_USER
    bw_install_template "Dockerfile.tmpl" "Dockerfile"
    echo "    Dockerfile-Stub angelegt - Pfade/ENTRYPOINT anpassen."
  else
    echo "    vorhandenes Dockerfile beibehalten."
  fi
  [ -f ".dockerignore" ] || bw_install_template "dockerignore.base" ".dockerignore"

  bw_commit_push "chore: add docker publish workflow"
  echo "==> Docker-Publish-Workflow aktiv (Image -> GHCR)."
}
