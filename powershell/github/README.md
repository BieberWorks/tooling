# 🚀 GitHub Repository Initializer (PowerShell)

Dieses Skript automatisiert das Erstellen eines neuen GitHub-Repositories unter Windows inklusive Best-Practice Branch-Struktur, Branch-Protections und fertigen CI/CD-Pipelines für Docker und Versionierung.

## 📦 Globale Einrichtung (Funktion)

Füge diese Funktion in dein PowerShell-Profil ein. Du öffnest dein Profil am schnellsten im Editor mit dem Befehl `notepad $PROFILE`.

```powershell
function New-GitHubRepo {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepoName
    )
    # Lädt den Code von GitHub und führt ihn im aktuellen Kontext aus
    $Url = "https://raw.githubusercontent.com/p-bieber/dev-scripts/main/powershell/github/init-repo.ps1"
    $Script = Invoke-RestMethod -Uri $Url
    Invoke-Expression ([scriptblock]::Create($Script)) -ArgumentList $RepoName
}
```

## 🛠️ Nutzung

Öffne eine neue PowerShell-Instanz und führe den Befehl aus:
```PowerShell
New-GitHubRepo mein-neues-projekt
```

## 🤖 Features

   - Erstellt die Branches main ← staging ← dev (Default branch).
   - Schützt alle drei Branches vor direkten Pushes (Admins ausgenommen).
   - Generiert die Ordnerstruktur src/, tests/, docs/, deploy/.
   - Fügt automatische Docker-Builds (GHCR) und Semantic-Versioning hinzu.
