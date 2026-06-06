#!/usr/bin/env bash
# Ergaenzt das aktuelle Repo um den NuGet-Release-Workflow (Push staging=-rc, main=final).
# Im Repo-Ordner ausfuehren (nach create-repo.sh oder in einem bestehenden Repo).
#
#   cd <RepoName> && ../path/to/add-package-deployment.sh
set -euo pipefail
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/repo-setup.sh
source "$_SCRIPT_DIR/../lib/repo-setup.sh"

bw_add_package_deployment
