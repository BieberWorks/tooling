# Implementierungsplan: BieberWorks.RepoSetup als installierbares PowerShell-Modul

Erstellt: 2026-06-20

---

## 1. Technische Entscheidung: Distribution via GitHub NuGet-Feed (PowerShellGet v2)

### Befund

GitHub Packages hat **keine** eigenständige PowerShell-Gallery-Registry. PowerShellGet v2
(das auf Windows vorinstallierte `Install-Module`) nutzt intern den NuGet-OneGet-Provider.
Es kann gegen jeden NuGet v2-kompatiblen Feed registriert werden:

```powershell
Register-PSRepository `
  -Name BieberWorks `
  -SourceLocation "https://nuget.pkg.github.com/BieberWorks/index.json" `
  -PublishLocation "https://nuget.pkg.github.com/BieberWorks/" `
  -InstallationPolicy Trusted
```

`Publish-Module` verpackt das Modul intern als `.nupkg` und pushed es gegen den
`-PublishLocation`-Endpunkt. Die resultierende `.nupkg` landet im GitHub Packages
NuGet-Feed der Org `BieberWorks` — sichtbar unter demselben Feed, den die .NET-Module
nutzen. `Install-Module` restored daraus via PowerShellGet/NuGet.

**Einschränkungen (bekannt):**
- Der GitHub Packages NuGet-Feed (v3/`index.json`) ist nur bedingt mit PowerShellGet v2
  kompatibel, das NuGet v2 erwartet. Praxisbewährt: `PublishLocation` auf den v2-Upload-
  Endpunkt (`https://nuget.pkg.github.com/BieberWorks/`) setzen, `SourceLocation` auf
  `https://nuget.pkg.github.com/BieberWorks/index.json`. Find-/Install-Module funktioniert
  anschließend für private Feeds wenn ein PAT als Credential übergeben wird.
- Private Feeds erfordern bei `Install-Module` ein `-Credential`-Argument (PAT mit
  `read:packages`). Das ist akzeptabel, da das Modul intern/tooling-only ist.

### Entscheidung

Distribution: **GitHub Packages NuGet-Feed** der Org `BieberWorks` (kein separater Feed).
Kein separates GitHub Release ZIP (zu viel Manuelles), keine externe PS-Gallery (proprietär).

---

## 2. Öffentliche API des Moduls (neue Funktionen)

Die neuen High-Level-Funktionen sind dünne Wrapper um die bestehenden internen Funktionen.
Sie ersetzen die `create-repo-*.ps1`-Wrapper-Scripts.

| Neue öffentliche Funktion | Ruft intern auf | SDK-Prefix-Prüfung |
|---|---|---|
| `New-BwModuleRepo` | `New-BwTemplateRepo` mit `bieberworks-module` + `packages` | Ja (`SDK-`-Prefix erzwingen) |
| `New-BwAppRepo` | `New-BwTemplateRepo` mit `bw-blazor` + `docker` | Nein |
| `New-BwApiRepo` | `New-BwTemplateRepo` mit `bw-api` + `docker` | Nein |
| `New-BwWasmApiRepo` | `New-BwTemplateRepo` mit `bw-wasm-api` + `docker` | Nein |
| `New-BwWasmRepo` | `New-BwTemplateRepo` mit `bw-wasm` + `docker` | Nein |
| `New-BwBlankRepo` | `New-BwRepo` (Blanko) | Nein |

**Einheitliche Parametersignatur für alle 6 Funktionen:**
```
-RepoName     [string] Mandatory
-Owner        [string] Mandatory
-TargetDirectory [string] optional, default ''
-Public       [switch]
```

**Interne Funktionen (NICHT exportiert):**
`New-BwRepoBase`, `New-BwRepo`, `New-BwTemplateRepo`, `Add-BwPackageDeployment`,
`Add-BwDockerPublish`, `Add-BwSlnxItem`, `Write-Utf8NoBom`, `Expand-BwTemplate`,
`Invoke-BwCommitPush`, `Write-BwPackagesTokenHint`

**Weiterhin exportiert (Standalone-Use):**
`Get-BwGithubUser`, `Get-BwRepoIdentity`

---

## 3. Schritt-für-Schritt-Implementierung

### Schritt 1: `.psm1` — neue Wrapper-Funktionen ergänzen

In `BieberWorks.RepoSetup.psm1` am Ende (vor `Export-ModuleMember`) einfügen:

- `New-BwModuleRepo`: Enthält die `SDK-`-Prefix-Validierung aus `create-repo-module.ps1`
  (inkl. `$DotnetName = "BieberWorks.SDK.$ModuleName"`) und ruft `New-BwTemplateRepo` auf.
- `New-BwAppRepo`, `New-BwApiRepo`, `New-BwWasmApiRepo`, `New-BwWasmRepo`:
  Je eine Funktion, die den richtigen Template-Namen und `DbPropsTemplate` setzt.
- `New-BwBlankRepo`: Delegiert an `New-BwRepo`.

`Export-ModuleMember` aktualisieren: nur die 6 neuen + `Get-BwGithubUser` + `Get-BwRepoIdentity`.
Die bisherigen internen Funktionen (`New-BwRepoBase`, `New-BwTemplateRepo` etc.) aus dem
Export entfernen — sie sollen nicht mehr Teil der öffentlichen API sein.

### Schritt 2: `.psd1` — Manifest vollständig befüllen

Felder die ergänzt/korrigiert werden müssen:

```
ModuleVersion     = '1.0.0'                # Erst-Release als installierbare Version
RootModule        = 'BieberWorks.RepoSetup.psm1'
GUID              = '4074db7a-...'         # behalten (GUID nie ändern)
Author            = 'Pierre Bieber'
CompanyName       = 'BieberWorks'
Description       = 'Erstellt neue BieberWorks-Repos (SDK-Module, Consumer-Apps, APIs,
                     Blazor, WASM) mit CI/CD, Branches und Deployment-Konfiguration.'
PowerShellVersion = '7.2'                  # Hochsetzen: 5.1 hat zu viele Reibungspunkte
                                           # mit Encoding + Invoke-RestMethod; 7.2 = LTS
FunctionsToExport = @(
    'New-BwModuleRepo',
    'New-BwAppRepo',
    'New-BwApiRepo',
    'New-BwWasmApiRepo',
    'New-BwWasmRepo',
    'New-BwBlankRepo',
    'Get-BwGithubUser',
    'Get-BwRepoIdentity'
)
PrivateData = @{
    PSData = @{
        Tags        = @('BieberWorks', 'SDK', 'RepoSetup', 'GitHub', 'DevTools')
        ProjectUri  = 'https://github.com/BieberWorks/tooling'
        LicenseUri  = 'https://github.com/BieberWorks/tooling/blob/main/LICENSE'
        ReleaseNotes = ''   # CI befüllt ggf. aus Changelog
    }
}
```

**Offene Frage:** `PowerShellVersion = '5.1'` vs `'7.2'`.
- 5.1 wird auf Windows vorinstalliert mitgeliefert, 7.x muss extra installiert werden.
- Das Modul nutzt `Invoke-RestMethod`, `[System.IO.File]::WriteAllText`, XML-Manipulation —
  alles kompatibel mit 5.1. ABER: `gh`-CLI und `dotnet`-CLI als externe Prozesse setzen
  kein bestimmtes PS voraus.
- **Empfehlung:** `'7.2'` setzen. Das Modul ist internes Dev-Tooling (nicht für Endkunden),
  der Entwickler hat PS 7.x. 5.1-Kompatibilität ist kein Ziel.

### Schritt 3: `TemplateRoot`-Problem lösen

Das Modul referenziert Templates relativ zu `$PSScriptRoot`:
```powershell
$script:TemplateRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\templates')).Path
```

Nach `Install-Module` liegt das Modul unter
`~\Documents\PowerShell\Modules\BieberWorks.RepoSetup\1.0.0\` — der relative Pfad zu
`templates/` existiert dort nicht mehr.

**Lösung:** Templates direkt ins Modul einbetten. Zwei Optionen:

**Option A (empfohlen): Templates als Unterordner ins Modul-Verzeichnis kopieren.**
- Beim Publishing lädt `Publish-Module -Path <ModulDir>` den gesamten Ordnerinhalt
  als `.nupkg`. Ein `templates/`-Unterordner im Modul-Verzeichnis wird mitgepackt.
- `$script:TemplateRoot` zeigt dann auf `Join-Path $PSScriptRoot 'templates'`.
- Im Repo bleibt `tooling/templates/` als Single-Source. Der CI-Build-Schritt
  kopiert `templates/` in den Modul-Ordner vor dem Publishing.

**Option B: Templates als Here-Strings direkt im `.psm1` hardcoden.**
- Zu wartungsintensiv, große Datei. Verwerfen.

**Entscheidung: Option A.** Templates bleiben Single-Source in `tooling/templates/`.
Ein Pre-Publish-Schritt im Workflow kopiert sie ins Modulverzeichnis.

### Schritt 4: `BieberWorks.RepoSetup.nuspec` nicht erforderlich

`Publish-Module` generiert die `.nuspec` automatisch aus dem `.psd1`. Kein manuelles
`.nuspec` nötig.

### Schritt 5: Versionierung

Konvention wie bei .NET-Modulen: Conventional Commits → Auto-Tag via
`mathieudutour/github-tag-action`. `ModuleVersion` im `.psd1` wird im CI-Workflow
vor dem Publishing auf die berechnete Tag-Version gesetzt (sed/PowerShell-Replace).

Die bestehende Tooling-Versionierung (manuell via Tags `@v1`) bleibt für die
reusable Workflows. Das PS-Modul bekommt eigene SemVer-Tags mit dem Prefix `ps-`
um Konflikte zu vermeiden, z.B. `ps-v1.0.0`.

**Offene Frage:** Oder einfach denselben Tag-Mechanismus ohne Prefix nutzen?
Risiko: `v1.0.0` kollidiert mit dem Workflow-Tag `@v1`. Empfehlung: `ps-v` Prefix
damit der `@v1` Workflow-Pin unberührt bleibt.

### Schritt 6: Neuer CI-Workflow `ps-module-release.yml`

Datei: `tooling/.github/workflows/ps-module-release.yml`

Trigger: Push auf `main` (Branch ohne Staging-Stufe — Tooling hat keinen `dev`/`staging`).

Schritte:
1. Checkout (full depth für Tag-Action)
2. Compute version via `mathieudutour/github-tag-action` (dry_run, tag prefix `ps-v`)
3. `Copy-Item templates/ -> powershell/modules/BieberWorks.RepoSetup/templates/`
4. Replace `ModuleVersion` im `.psd1` mit der berechneten Version (PowerShell-Inline)
5. Register PSRepository (NuGet-Feed der BieberWorks Org) via `Register-PSRepository`
6. `Publish-Module -Path powershell/modules/BieberWorks.RepoSetup -Repository BieberWorks
   -NuGetApiKey ${{ secrets.GITHUB_TOKEN }}`
7. Echter Tag via `mathieudutour/github-tag-action` (kein dry_run)
8. GitHub Release (optional, `softprops/action-gh-release`)

**Auth:** `GITHUB_TOKEN` hat `packages:write` auf dem eigenen Repo. Das reicht für
`Publish-Module` gegen den NuGet-Feed der Org, solange der Caller `permissions: packages: write`
deklariert.

### Schritt 7: Migration der `create-repo-*.ps1` Wrapper

Die alten Scripts unter `powershell/github/create-repo-*.ps1` haben zwei Nutzungsszenarien:
- **Vor Install-Module:** direkt mit `& ".\tooling\powershell\github\create-repo-app.ps1"`.
- **Nach Install-Module:** die neuen Funktionen direkt aufrufen.

**Entscheidung:** Wrapper-Scripts beibehalten, aber auf die neuen Modul-Funktionen umleiten.
Statt `Import-Module ..\modules\...` → `Import-Module BieberWorks.RepoSetup` (installed).
Fallback: wenn installiertes Modul nicht gefunden, lokalen Pfad nutzen.

Konkret: Jeden Wrapper auf 2 Zeilen reduzieren:
```powershell
Import-Module BieberWorks.RepoSetup -ErrorAction SilentlyContinue
if (-not (Get-Module BieberWorks.RepoSetup)) { Import-Module (Join-Path $PSScriptRoot '...psd1') -Force }
New-BwAppRepo @PSBoundParameters
```

Das macht die Scripts weiter nutzbar ohne installierten Modul (lokale Entwicklung am
Tooling selbst), aber profitiert von installierter Version wenn vorhanden.

### Schritt 8: `docs/powershell-module.md` anlegen

Inhalt:
- Einmalige Installation (PSRepository registrieren + `Install-Module`)
- Alle 6 öffentlichen `New-Bw*`-Funktionen mit Parametertabelle + je einem Beispiel
- `Get-BwGithubUser` / `Get-BwRepoIdentity` als Hilfsfunktionen dokumentieren
- Hinweis: privater Feed, PAT-Credential nötig
- Hinweis: `gh`-CLI und `dotnet`-CLI müssen installiert sein (externe Abhängigkeiten)

Datei in `tooling/docs/` — neuer `docs/`-Ordner muss angelegt werden.

Modul-eigene `CLAUDE.md` muss Tabelle ergänzen: "Änderung an `.psm1` oder `.psd1`
→ `docs/powershell-module.md` prüfen."

---

## 4. Reihenfolge der Umsetzung

1. `.psm1`: neue 6 High-Level-Funktionen ergänzen; `Export-ModuleMember` aktualisieren
2. `.psd1`: alle Felder befüllen; `FunctionsToExport` anpassen; `PowerShellVersion = '7.2'`
3. `create-repo-*.ps1`: auf Fallback-Import umstellen
4. CI-Workflow `ps-module-release.yml` anlegen
5. `docs/powershell-module.md` anlegen
6. Modul-`CLAUDE.md` Docs-Tabelle ergänzen
7. Commit auf `main` → CI-Workflow triggered erstes Publishing

---

## 5. Offene Fragen (vor Umsetzung klären)

| Frage | Empfehlung / Default |
|---|---|
| `PowerShellVersion` 5.1 oder 7.2? | 7.2 — internes Tooling, kein Endkunden-Szenario |
| Tag-Prefix für PS-Modul? | `ps-v` Prefix (z.B. `ps-v1.0.0`) um Workflow-Tag `@v1` nicht zu stören |
| Wrapper-Scripts löschen oder behalten? | Behalten, auf Fallback-Import umstellen |
| Separate Staging-Stufe (`-rc`) für PS-Modul? | Nein — Tooling hat keinen `dev`/`staging`-Branch-Flow; direkt auf `main` |
| Templates in Modul-Ordner kopieren: im Repo commiten oder nur CI-Artefakt? | Nur im CI kopieren; `templates/` als Unterordner des Moduls **.gitignore**n (Single-Source bleibt `tooling/templates/`) |

---

## 6. Nicht-Ziele (explizit ausgeklammert)

- Keine Veröffentlichung auf der öffentlichen PowerShell Gallery (proprietär/intern)
- Kein PowerShellGet v3 (`PSResourceGet`) — v2 ist Standardwerkzeug auf Windows 11,
  v3 ist noch Preview-Phase und wäre zusätzliche Installationsvoraussetzung
- Kein Bash-Äquivalent der neuen Funktionen (Bash-Scripts unter `bash/github/` bleiben
  wie sie sind — separates Thema)
