#!/usr/bin/env bash
# BieberWorks repo-setup library.
# Geteilte Bausteine fuer das Setup neuer BieberWorks-SDK-Repos.
# Die duennen Scripts unter bash/github/ sourcen nur diese Datei.
# Statische Datei-Inhalte leben als Single-Source unter ../../templates/.
#
# Schicht-Architektur:
#   bw_new_repo_base     -> Basis-Geruest (Files + CI + Branches main/staging/dev + Default dev)
#   bw_new_repo          -> Base + leere src/tests/docs + .slnx  (blanko-Repo)
#   bw_new_template_repo -> Base + dotnet new <Template> + .slnx + Deploy (api/app/web/module)
#   bw_add_package_deployment / bw_add_docker_publish -> Deployment-Workflows (standalone nutzbar)

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

# Fuegt eine Datei als <File>-Eintrag in einen Solution-Folder einer .slnx ein.
# Legt den Folder an, falls er fehlt. Idempotent. Nur falls .slnx existiert.
#   bw_slnx_add_item <slnx> <folder "/SolutionItems/docker/"> <file>
bw_slnx_add_item() {
  local slnx="$1" folder="$2" file="$3" tmp
  [ -f "$slnx" ] || return 0
  tmp="$(mktemp)"
  if grep -qF "Name=\"$folder\"" "$slnx"; then
    # Folder existiert: File nach der Folder-Oeffnungszeile einfuegen (falls noch nicht da)
    if awk -v f="$folder" -v p="$file" '
        index($0, "Name=\"" f "\"") { infolder=1 }
        infolder && index($0, "Path=\"" p "\"") { found=1 }
        END { exit(found ? 0 : 1) }' "$slnx"; then
      rm -f "$tmp"; return 0
    fi
    awk -v f="$folder" -v p="$file" '
      { print }
      !done && index($0, "Name=\"" f "\"") {
        match($0, /^[[:space:]]*/); indent = substr($0, 1, RLENGTH)
        print indent "  <File Path=\"" p "\" />"
        done = 1
      }' "$slnx" > "$tmp"
    mv "$tmp" "$slnx"
  else
    # Folder fehlt: kompletten Block vor </Solution> einfuegen
    awk -v f="$folder" -v p="$file" '
      !done && index($0, "</Solution>") {
        print "  <Folder Name=\"" f "\">"
        print "    <File Path=\"" p "\" />"
        print "  </Folder>"
        done = 1
      }
      { print }' "$slnx" > "$tmp"
    mv "$tmp" "$slnx"
  fi
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

# --- Schicht 0: Basis-Repo (Files + CI + Branches, KEINE src/tests/docs) ----

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

  # 2. Nur der Workflows-Ordner (src/tests/docs kommen erst in bw_new_repo / -template_repo)
  mkdir -p .github/workflows

  # 3. LICENSE, README, nuget.config, Directory.Build.props
  echo "==> Lege LICENSE, README, nuget.config, Directory.Build.props, CI an..."
  bw_install_template "LICENSE.tmpl"               "LICENSE"
  bw_install_template "README.module.tmpl"         "README.md"
  bw_install_template "nuget.config"               "nuget.config"
  bw_install_template "Directory.Build.props.tmpl" "Directory.Build.props"

  # 4. .gitignore - VisualStudio-Basis (offiziell) + BieberWorks-Anhang
  if curl -fsSL "https://raw.githubusercontent.com/github/gitignore/main/VisualStudio.gitignore" -o .gitignore; then
    :
  else
    echo "    gitignore-Download fehlgeschlagen, Fallback auf 'dotnet new gitignore'."
    dotnet new gitignore >/dev/null
  fi
  bw_expand_template "gitignore.append" >> .gitignore

  # 5. CI (build/test) - Caller auf den reusable Workflow (run_tests default true)
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
  echo "==> Basis steht (Branch: dev)."
}

# --- Schicht 1a: Blanko-Repo (Base + leere Ordner + .slnx) ------------------

# bw_new_repo <RepoName> [Org=BieberWorks] [public|private]
bw_new_repo() {
  local repo="$1" org="${2:-BieberWorks}" vis="${3:-private}"
  bw_new_repo_base "$repo" "$org" "$vis"

  echo "==> Lege leere Standard-Ordner (src/tests/docs) + Solution an..."
  local folder
  for folder in src tests docs; do
    mkdir -p "$folder"
    touch "$folder/.gitkeep"
  done
  bw_install_template "tests.Directory.Build.props" "tests/Directory.Build.props"
  bw_install_template "solution.slnx.tmpl"          "$repo.slnx"

  bw_commit_push "chore: add solution skeleton (src/tests/docs, slnx)"
  echo "==> Fertig! '$org/$repo' steht bereit (Branch: dev)."
}

# --- Schicht 1b: Typ-Repo via dotnet-new-Template + Deployment ---------------

# bw_new_template_repo <RepoName> <Template-ShortName> <docker|packages> [Org] [public|private] [DotnetName]
# DotnetName: optionaler -n-Wert fuer dotnet new (Standard = RepoName).
# Fuer Module: BieberWorks.SDK.<Name>, damit das Template den korrekten Kurznamen extrahiert.
bw_new_template_repo() {
  local repo="$1" template="$2" deploy="$3" org="${4:-BieberWorks}" vis="${5:-private}" dotnet_name="${6:-}"
  local name_arg="${dotnet_name:-$repo}"
  bw_new_repo_base "$repo" "$org" "$vis"

  echo "==> Solution-Geruest + 'dotnet new $template -n $name_arg'..."
  mkdir -p docs; touch docs/.gitkeep
  bw_install_template "solution.slnx.tmpl" "$repo.slnx"

  # Template instanziieren in den Repo-Root. Das Template bringt seine Projekte
  # unter src/<Name> (+ tests/<Name>.Tests) mit; KEINE repo-globalen Dateien
  # (die liefert die Basis) und KEINE eigene .slnx.
  dotnet new "$template" -n "$name_arg" -o .

  # Alle erzeugten csproj in die Solution aufnehmen (src/ und tests/ getrennt).
  local csproj
  while IFS= read -r csproj; do
    [ -n "$csproj" ] && dotnet sln "$repo.slnx" add "$csproj" --solution-folder src
  done < <(find src -name '*.csproj' 2>/dev/null || true)
  while IFS= read -r csproj; do
    [ -n "$csproj" ] && dotnet sln "$repo.slnx" add "$csproj" --solution-folder tests
  done < <(find tests -name '*.csproj' 2>/dev/null || true)

  bw_commit_push "chore: scaffold $template project + solution"

  if [ "$deploy" = "docker" ]; then bw_add_docker_publish; else bw_add_package_deployment; fi
  echo "==> Fertig! '$org/$repo' steht bereit (Branch: dev)."
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

  # Docker-Dateien in der Solution sichtbar machen (SolutionItems/docker), falls .slnx vorhanden.
  local slnx
  slnx="$(find . -maxdepth 1 -name '*.slnx' 2>/dev/null | head -n1 || true)"
  if [ -n "$slnx" ]; then
    bw_slnx_add_item "$slnx" "/SolutionItems/docker/" "Dockerfile"
    bw_slnx_add_item "$slnx" "/SolutionItems/docker/" ".dockerignore"
  fi

  bw_commit_push "chore: add docker publish workflow"
  echo "==> Docker-Publish-Workflow aktiv (Image -> GHCR)."
}
