#!/usr/bin/env bash
# Ergaenzt das aktuelle Repo um den Docker-Publish-Workflow (Image -> GHCR).
# Legt Dockerfile/.dockerignore nur an, falls noch keins existiert.
# Im Repo-Ordner ausfuehren (nach create-repo.sh oder in einem bestehenden Repo).
#
#   cd <RepoName> && ../path/to/add-docker-publish.sh
set -euo pipefail
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/repo-setup.sh
source "$_SCRIPT_DIR/../lib/repo-setup.sh"

bw_add_docker_publish
