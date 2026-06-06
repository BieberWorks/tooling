# 🚀 GitHub Repository Initializer (Bash)

Dieses Skript automatisiert das Erstellen eines neuen GitHub-Repositories inklusive Best-Practice Branch-Struktur, Branch-Protections und fertigen CI/CD-Pipelines für Docker und Versionierung.

## 📦 Globale Einrichtung (Alias)

Füge diese Funktion in deine Terminal-Konfigurationsdatei ein (z. B. `~/.bashrc`, `~/.zshrc` oder `~/.bash_profile`):

```bash
function gh-init() {
    # Streamt das Skript live aus dem GitHub-Repository und führt es aus
    curl -s "https://raw.githubusercontent.com/p-bieber/dev-scripts/main/bash/github/init-repo.sh" | bash -s -- "$1"
}
```

## 🛠️ Nutzung

Öffne ein neues Terminal und führe den Befehl mit deinem Wunschnamen aus:
```bash
gh-init mein-neues-projekt
```

## 🤖 Features

   - Erstellt die Branches main ← staging ← dev (Default branch).
   - Schützt alle drei Branches vor direkten Pushes (Admins ausgenommen).
   - Generiert die Ordnerstruktur src/, tests/, docs/, deploy/.
   - Fügt automatische Docker-Builds (GHCR) und Semantic-Versioning hinzu.
