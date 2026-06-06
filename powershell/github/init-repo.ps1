param (
    [Parameter(Mandatory=$true)]
    [string]$RepoName
)

$ErrorActionPreference = "Stop"

# GitHub User ermitteln
$hash = gh api user | ConvertFrom-Json
$GithubUser = $hash.login

Write-Host "🚀 Starte Initialisierung für Repository: $RepoName (Owner: $GithubUser)..." -ForegroundColor Cyan

# 1. Lokalen Ordner und Git erstellen
New-Item -ItemType Directory -Force -Path $RepoName | Out-Null
Set-Location -Path $RepoName
git init -b main

# 2. Grundstruktur anlegen
Write-Host "📁 Erstelle Best-Practice Ordnerstruktur..." -ForegroundColor Cyan
$Folders = @(".github/workflows", "src", "tests", "docs", "deploy")
foreach ($folder in $Folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    if ($folder -ne ".github/workflows") {
        New-Item -ItemType File -Force -Path "$folder/.gitkeep" | Out-Null
    }
}

# --- WORKFLOW 1: Versionierung & Release ---
$ReleaseWorkflow = @'
name: Versioning & Release Management
on:
  push:
    branches: [main, staging]
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
'@
Set-Content -Path .github/workflows/release-management.yml -Value $ReleaseWorkflow

# --- WORKFLOW 2: Docker Build & Push ---
$DockerWorkflow = @'
name: Docker Build & Push
on:
  push:
    branches: [main, staging, dev]
  pull_request:
    branches: [dev]
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
'@
Set-Content -Path .github/workflows/docker-ci.yml -Value $DockerWorkflow

# Initialer Commit
Set-Content -Path README.md -Value "# $RepoName`nInitiales Setup mit automatisiertem Branch-Flow (main <- staging <- dev)."
git add .
git commit -m "chore: initial repository setup with ci/cd workflows"

# 3. Remote Repository erstellen
Write-Host "🌐 Erstelle Remote-Repository auf GitHub..." -ForegroundColor Cyan
gh repo create "$RepoName" --private --source=. --remote=origin
git push -u origin main

# 4. Branches erstellen
Write-Host "🌿 Erstelle Branches (staging & dev)..." -ForegroundColor Cyan
git checkout -b staging
git push -u origin staging
git checkout -b dev
git push -u origin dev
git checkout dev

# 5. Default Branch ändern
Write-Host "⚙️ Setze 'dev' als Default-Branch..." -ForegroundColor Cyan
gh repo edit "$GithubUser/$RepoName" --default-branch dev

# 6. Branch Protection via API
Write-Host "🔒 Konfiguriere Branch Protection Rules..." -ForegroundColor Cyan
$ProtectionJson = @{
    required_status_checks = $null
    enforce_admins = $false
    required_pull_request_reviews = @{
        dismiss_stale_reviews = $true
        require_code_owner_reviews = $false
        required_approving_review_count = 1
    }
    restrictions = $null
} | ConvertTo-Json -Depth 10

foreach ($branch in @("main", "staging", "dev")) {
    Write-Host "   -> Schütze Branch: $branch" -ForegroundColor Gray
    $ProtectionJson | gh api --method PUT "/repos/$GithubUser/$RepoName/branches/$branch/protection" --input - | Out-Null
}

Write-Host "✅ Fertig! Dein Repository '$RepoName' ist komplett bereit." -ForegroundColor Green