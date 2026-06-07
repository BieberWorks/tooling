#!/usr/bin/env bash
# Legt ein neues BieberWorks-Modul-Repo an: Basis + 'dotnet new bieberworks-module'
# (Contracts + Impl + Tests) + NuGet-Package-Deployment. Branches main/staging/dev (Default dev).
# HINWEIS: Das Template 'bieberworks-module' muss im DotnetTemplates-Paket existieren.
#
#   ./create-repo-module.sh <RepoName> [--org <Org>] [--public]
set -euo pipefail
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/repo-setup.sh
source "$_SCRIPT_DIR/../lib/repo-setup.sh"

ORG="BieberWorks"; VIS="private"; REPO_NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    --public) VIS="public"; shift ;;
    --org)    ORG="$2"; shift 2 ;;
    -*)       echo "Unbekannte Option: $1" >&2; exit 1 ;;
    *)        REPO_NAME="$1"; shift ;;
  esac
done
if [ -z "$REPO_NAME" ]; then
  echo "Nutzung: ./create-repo-module.sh <RepoName> [--org <Org>] [--public]" >&2
  exit 1
fi

bw_new_template_repo "$REPO_NAME" "bieberworks-module" "packages" "$ORG" "$VIS"
