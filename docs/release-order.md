# SDK Release Order

Verbindliche Promote-Reihenfolge für die BieberWorks-SDK-Module. Abgeleitet aus den
echten `PackageReference Include="BieberWorks.SDK.*"`-Einträgen aller `.csproj`
(Stand 2026-06-25), **nicht** aus dem Gedächtnis. Bei Struktur-Änderungen neu prüfen via:

```powershell
rg 'PackageReference\s+Include="BieberWorks\.SDK\.' -g 'SDK-*/**/*.csproj'
```

## Kernaussage

Eine **perfekt lineare** Reihenfolge existiert nicht: Auf Repo-Ebene gibt es Zyklen
rund um den Auth-Knoten (jedes Repo bündelt `Contracts` **und** `Impl` in *einem*
Release). Die *Contracts*-Pakete selbst bilden jedoch einen sauberen DAG
(`SharedKernel → Auth.Contracts/Settings.Contracts/… → Theme.Contracts → Email.Contracts`).
Mit den floatenden Ranges (`0.*-*` / `1.*-*`) ist das im Alltag unkritisch, solange die
**konsumierte Contracts-Version schon im Feed liegt**.

## Tiers

| Tier | Repos | Hängt ab von |
|---|---|---|
| 0 | `SDK-Foundation` (SharedKernel, Core, Core.Web, Core.Postgres) | — |
| 1 | `SDK-UI`, `SDK-Components`, `SDK-Export` | Foundation |
| 2 | `SDK-Auth`, `SDK-Admin`, `SDK-Settings`, `SDK-Account` | Foundation, UI + **wechselseitig** (zyklisch) |
| 3 | `SDK-Storage`, `SDK-Theme` | Tier 2 (Theme: + Storage.Contracts) |
| 4 | `SDK-Email`, `SDK-Audit`, `SDK-Pages`, `SDK-Legal`, `SDK-Wallet`, `SDK-Localization` | Tier ≤3 (Email: + Theme.Contracts; Pages/Legal: + Components) |
| 5 | `SDK-Maintenance`, `SDK-Notifications` | Tier ≤4 (Maintenance: + Theme.Contracts; Notifications: + Email.Contracts) |
| — | `Sandbox`, `DotnetTemplates` | Consumer — **immer zuletzt** |

## Der Auth-Knoten (Tier 2, zyklisch)

| Repo | braucht (impl) | liefert Contracts an |
|---|---|---|
| `SDK-Auth` | Admin.Contracts, Account.Contracts, Settings.Contracts, Email.Contracts, Pages.Contracts | praktisch alle |
| `SDK-Admin` | Auth.Contracts, Settings.Contracts | Account, Audit, Email, Storage, … |
| `SDK-Account` | Admin.Contracts | Storage, Theme, Wallet, Notifications |
| `SDK-Settings` | Auth.Contracts, Admin.Contracts | Theme, Maintenance, Wallet |

→ Bei wechselseitigen Änderungen **gemeinsam und iterativ** promoten, nicht einzeln.

## Praxisregeln

1. **Normaler Flow:** Tier 0 → 5 von oben nach unten. Innerhalb eines Tiers sequenziell
   auf CI-Abschluss warten (dependent Repo restored Pakete, die erst in GitHub Packages
   liegen müssen — sonst rote Builds).
2. **Breaking Contract-Change** (z. B. `Auth.Contracts` Major): Erst das Contract-Repo
   voll durch (main + Feed), **dann** alle Tier-≥2-Konsumenten neu bauen.
3. **Auth/Admin/Settings/Account:** als verschränkten Block behandeln.
