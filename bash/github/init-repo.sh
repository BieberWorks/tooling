#!/bin/bash

# Abbruch bei Fehlern
set -e

REPO_NAME=$1
GITHUB_USER=$(gh api user -q .login)

if [ -z "$REPO_NAME" ]; then
  echo "❌ Fehler: Bitte gib einen Repository-Namen an!"
  echo "Nutzung: ./init-repo.sh mein-neues-projekt"
  exit 1
fi

echo "🚀 Starte Initialisierung für Repository: $REPO_NAME (Owner: $GITHUB_USER)..."

# 1. Lokalen Ordner und Git erstellen
mkdir "$REPO_NAME" && cd "$REPO_NAME"
git init -b main

# 2. Grundstruktur anlegen
echo "📁 Erstelle Best-Practice Ordnerstruktur..."
mkdir -p .github/workflows src tests docs deploy

# .gitkeep Dateien erstellen, damit leere Ordner von Git getrackt werden
touch src/.gitkeep
touch tests/.gitkeep
touch docs/.gitkeep
touch deploy/.gitkeep

# --- WORKFLOW 1: Versionierung & Release ---
cat << 'EOF' > .github/workflows/release-management.yml
name: Versioning & Release Management

on:
  push:
    branches:
      - main
      - staging

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Automated Tagging
        id: tagger
        uses: mathieudutour/github-tag-action@v6.2
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          release_branches: main
          pre_release_branches: staging
          append_to_pre_release_tag: rc

      - name: Create GitHub Release
        if: github.ref == 'refs/heads/main'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.tagger.outputs.new_tag }}
          name: Release ${{ steps.tagger.outputs.new_tag }}
          body: ${{ steps.tagger.outputs.changelog }}
EOF

# --- WORKFLOW 2: Docker Build & Push ---
cat << 'EOF' > .github/workflows/docker-ci.yml
name: Docker Build & Push

on:
  push:
    branches:
      - main
      - staging
      - dev
  pull_request:
    branches:
      - dev

jobs:
  docker:
    runs-on: ubuntu-latest
    outputs:
      dockerfile_exists: ${{ steps.check_files.outputs.exists }}
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Check if Dockerfile exists
        id: check_files
        run: |
          if [ -f "Dockerfile" ]; then
            echo "exists=true" >> $GITHUB_OUTPUT
          else
            echo "exists=false" >> $GITHUB_OUTPUT
          fi

  build-and-push:
    needs: docker
    if: needs.docker.outputs.dockerfile_exists == 'true'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        if: github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
            type=raw,value=staging,enable=${{ github.ref == 'refs/heads/staging' }}
            type=raw,value=dev,enable=${{ github.ref == 'refs/heads/dev' }}
            type=ref,event=pr
            type=sha,prefix=sha-

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' || github.event.pull_request.head.repo.full_name == github.repository }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

# Initialer Commit im main Branch
echo "# $REPO_NAME" > README.md
echo "Initiales Setup mit automatisiertem Branch-Flow (main <- staging <- dev)." >> README.md
git add .
git commit -m "chore: initial repository setup with ci/cd workflows"

# 3. Remote Repository auf GitHub erstellen (Private)
echo "🌐 Erstelle Remote-Repository auf GitHub..."
gh repo create "$REPO_NAME" --private --source=. --remote=origin

# Main hochladen
git push -u origin main

# 4. 'staging' und 'dev' Branches erstellen und pushen
echo "🌿 Erstelle Branches (staging & dev)..."
git checkout -b staging
git push -u origin staging

git checkout -b dev
git push -u origin dev

# 5. 'dev' als Default-Branch auf GitHub setzen
echo "⚙️ Setze 'dev' als Default-Branch..."
gh repo edit "$GITHUB_USER/$REPO_NAME" --default-branch dev

# Zurück auf dev wechseln für die lokale Arbeit
git checkout dev

# 6. Branch Protection Rules via GitHub API setzen
echo "🔒 Konfiguriere Branch Protection Rules..."

PROTECTION_JSON=$(cat << 'EOF'
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null
}
EOF
)

for branch in main staging dev; do
  echo "   -> Schütze Branch: $branch"
  gh api --method PUT "/repos/$GITHUB_USER/$REPO_NAME/branches/$branch/protection" \
    --input - <<< "$PROTECTION_JSON" > /dev/null
done

echo "✅ Fertig! Dein Repository '$REPO_NAME' ist komplett eingerichtet und geschützt."
echo "👉 Du befindest dich lokal auf dem Branch 'dev'. Viel Erfolg!"