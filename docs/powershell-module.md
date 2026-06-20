# BieberWorks.RepoSetup — PowerShell-Modul

Das Modul `BieberWorks.RepoSetup` stellt High-Level-Funktionen bereit, um neue BieberWorks-Repos
vollstaendig aufzusetzen: GitHub-Repo anlegen, Branches (`main`/`staging`/`dev`, Default `dev`),
CI/CD-Workflows, Solution-Skeleton und Deployment-Konfiguration — alles in einem Aufruf.

Das Modul wird als NuGet-Paket im GitHub Packages NuGet-Feed der Org `BieberWorks` veroeffentlicht
und kann ueber PowerShellGet v2 (`Install-Module`) installiert werden.

> Alternativ: die Wrapper-Scripts unter `powershell/github/create-repo-*.ps1` funktionieren
> weiterhin ohne installierten Modul und laden es bei Bedarf lokal.

---

## Voraussetzungen

- PowerShell 7.2 oder neuer
- `gh` CLI (GitHub CLI) installiert und eingeloggt (`gh auth login`)
- `dotnet` CLI (fuer Template-basierte Repos)

---

## Installation (einmalig)

Zunaechst den privaten Feed registrieren. Der PACKAGES_TOKEN (PAT mit `read:packages`) liegt in
`C:\Users\biebe\source\repos\BieberWorks\.secrets.txt`.

PowerShellGet v2 (Windows PowerShell 5.1 Standard) unterstützt den NuGet v3-Feed von GitHub Packages nicht — PSResourceGet ist erforderlich.

```powershell
$token = (Get-Content "C:\Users\biebe\source\repos\BieberWorks\.secrets.txt" |
          Select-String "^ghp_" | ForEach-Object { $_.Line.Trim() })

$cred = New-Object PSCredential("BieberWorks", (ConvertTo-SecureString $token -AsPlainText -Force))

Register-PSResourceRepository `
    -Name BieberWorks `
    -Uri "https://nuget.pkg.github.com/BieberWorks/index.json" `
        -InstallationPolicy Trusted `
    -Credential $cred

Install-PSResource BieberWorks.RepoSetup -Repository BieberWorks -Credential $cred
```

---

## Funktionen

### New-BwModuleRepo

Legt ein neues SDK-Fachmodul-Repo an (`bieberworks-module`-Template, NuGet-Deployment).
Erzwingt den `SDK-`-Prefix im Repo-Namen.

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Muss mit `SDK-` beginnen (z.B. `SDK-Forum`) |
| `-Owner` | string | Ja | GitHub-Org oder -User (z.B. `BieberWorks`) |
| `-TargetDirectory` | string | Nein | Zielordner; Standard: aktuelles Verzeichnis |
| `-Public` | switch | Nein | Oeffentliches Repo (Standard: privat) |

```powershell
New-BwModuleRepo -RepoName SDK-Forum -Owner BieberWorks
```

---

### New-BwAppRepo

Legt ein neues Consumer-Blazor-App-Repo an (`bw-blazor`-Template, Docker-Deployment).

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Repo-Name (z.B. `MyApp`) |
| `-Owner` | string | Ja | GitHub-Org oder -User |
| `-TargetDirectory` | string | Nein | Zielordner |
| `-Public` | switch | Nein | Oeffentliches Repo |

```powershell
New-BwAppRepo -RepoName MyPortal -Owner BieberWorks
```

---

### New-BwApiRepo

Legt ein neues Consumer-REST-API-Repo an (`bw-api`-Template, Docker-Deployment).

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Repo-Name (z.B. `MyApi`) |
| `-Owner` | string | Ja | GitHub-Org oder -User |
| `-TargetDirectory` | string | Nein | Zielordner |
| `-Public` | switch | Nein | Oeffentliches Repo |

```powershell
New-BwApiRepo -RepoName MyBackend -Owner BieberWorks
```

---

### New-BwWasmApiRepo

Legt ein neues Consumer-Repo mit WASM-Frontend + API-Backend an (`bw-wasm-api`-Template, Docker-Deployment).

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Repo-Name |
| `-Owner` | string | Ja | GitHub-Org oder -User |
| `-TargetDirectory` | string | Nein | Zielordner |
| `-Public` | switch | Nein | Oeffentliches Repo |

```powershell
New-BwWasmApiRepo -RepoName MyWasmApp -Owner BieberWorks
```

---

### New-BwWasmRepo

Legt ein WASM-Only-Repo an (`bw-wasm`-Template, Docker-Deployment). Die API-URL wird in
`wwwroot/appsettings.json` konfiguriert.

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Repo-Name |
| `-Owner` | string | Ja | GitHub-Org oder -User |
| `-TargetDirectory` | string | Nein | Zielordner |
| `-Public` | switch | Nein | Oeffentliches Repo |

```powershell
New-BwWasmRepo -RepoName MyFrontend -Owner BieberWorks
```

---

### New-BwBlankRepo

Legt ein leeres Repo an (kein Template, kein Deployment-Workflow). Nuetzlich fuer
Tooling-Repos, Docs oder sonstige Infrastruktur.

| Parameter | Typ | Pflicht | Beschreibung |
|---|---|---|---|
| `-RepoName` | string | Ja | Repo-Name |
| `-Owner` | string | Ja | GitHub-Org oder -User |
| `-TargetDirectory` | string | Nein | Zielordner |
| `-Public` | switch | Nein | Oeffentliches Repo |

```powershell
New-BwBlankRepo -RepoName SDK-Docs -Owner BieberWorks
```

---

## Hilfsfunktionen

### Get-BwGithubUser

Gibt den eingeloggten GitHub-Usernamen zurueck (`gh api user`).

```powershell
$user = Get-BwGithubUser
```

### Get-BwRepoIdentity

Gibt `Org`, `Repo` und `NameWithOwner` des aktuellen Repos zurueck (muss im Repo-Verzeichnis aufgerufen werden).

```powershell
$id = Get-BwRepoIdentity
Write-Host $id.NameWithOwner  # z.B. BieberWorks/SDK-Forum
```

---

## Update

```powershell
$cred = New-Object PSCredential("BieberWorks", (ConvertTo-SecureString $token -AsPlainText -Force))
Update-PSResource BieberWorks.RepoSetup -Repository BieberWorks -Credential $cred
```

---

## Hinweise

- Der GitHub Packages NuGet-Feed ist privat — bei `Install-Module` und `Update-Module` immer
  `-Credential` mit dem PACKAGES_TOKEN uebergeben.
- `gh` CLI und `dotnet` CLI muessen installiert und erreichbar sein (`$env:PATH`).
- Die Wrapper-Scripts unter `powershell/github/create-repo-*.ps1` bleiben erhalten und
  nutzen das installierte Modul wenn vorhanden, sonst laden sie es lokal.
- Bei Aenderungen an `.psm1` oder `.psd1` diese Datei auf Aktualitaet pruefen.
