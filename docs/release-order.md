# SDK Release Order

Verbindliche Promote-Reihenfolge für die BieberWorks-SDK-Module. Abgeleitet aus den
echten `PackageReference Include="BieberWorks.SDK.*"`-Einträgen aller `.csproj`
(Stand 2026-06-25), **nicht** aus dem Gedächtnis. Bei Struktur-Änderungen neu prüfen via:

```powershell
rg 'PackageReference\s+Include="BieberWorks\.SDK\.' -g 'SDK-*/**/*.csproj'
```

> **Maschinenlesbare Quelle:** Die kanonische Promote-Reihenfolge (Modul → Stufe 0–5) liegt als
> [`tooling/release-order.json`](../release-order.json) — **die eine Wahrheit**. Diese .md ist die
> erzählerische Begleitung. Die SdkInfoApp liest `release-order.json` (release-Modus via gh, local
> aus der tooling-Working-Copy) und zeigt sie als `releaseOrder` neben dem berechneten
> `dependencyTier` (impl-Longest-Path) an. Die `releaseOrder` ist **kuratiert** (kein sauberer
> Longest-Path — Begründung siehe Memory `sdk-release-order`); ein Drift-Check in der App warnt,
> wenn eine neue `impl`-Dependency ihr widerspricht.

## Kernaussage

**Es gibt keinen echten Architektur-Zyklus.** Die `*.Contracts`-Pakete bilden einen
sauberen DAG — die vier Tier-2-Contracts (`Auth.Contracts`, `Admin.Contracts`,
`Account.Contracts`, `Settings.Contracts`) hängen alle nur von `SharedKernel` ab, nicht
voneinander.

Was nach „Zyklus" aussieht, ist nur ein Verpackungs-Effekt: Jedes Repo veröffentlicht
`Contracts` **und** `Impl/UI` in *einem* Release. Eine tieferliegende Impl (z. B. `Auth.UI`)
greift dabei quer nach oben auf fremde Contracts (sie registriert sich als Admin-/Account-Seite
→ braucht `Admin.Contracts`/`Account.Contracts`), während `Admin.Impl` zurück `Auth.Contracts`
braucht. Auf **Paket-Ebene** baut die Reihenfolge *alle Contracts → alle Impl* trotzdem
zyklenfrei.

**Praktische Folge:** Im Normalbetrieb spielt die Reihenfolge innerhalb Tier 2 keine Rolle —
die konsumierte Contracts-Version liegt durch die floatenden Ranges (`0.*-*` / `1.*-*`)
bereits aus dem letzten Release im Feed. Die Reihenfolge wird **nur** bei einem
**Breaking-Contract-Change** relevant (siehe Praxisregeln).

## Tiers

| Tier | Repos | Hängt ab von |
|---|---|---|
| 0 | `SDK-Foundation` (SharedKernel, Core, Core.Web, Core.Postgres) | — |
| 1 | `SDK-UI`, `SDK-Components`, `SDK-Export` | Foundation |
| 2 | `SDK-Auth`, `SDK-Admin`, `SDK-Settings`, `SDK-Account` | Foundation, UI; Contracts nur SharedKernel, Impl greift quer (kein echter Zyklus — s. Kernaussage) |
| 3 | `SDK-Storage`, `SDK-Theme` | Tier 2 (Theme: + Storage.Contracts) |
| 4 | `SDK-Email`, `SDK-Audit`, `SDK-Pages`, `SDK-Legal`, `SDK-Wallet`, `SDK-Localization` | Tier ≤3 (Email: + Theme.Contracts; Pages/Legal: + Components) |
| 5 | `SDK-Maintenance`, `SDK-Notifications` | Tier ≤4 (Maintenance: + Theme.Contracts; Notifications: + Email.Contracts) |
| — | `Sandbox`, `DotnetTemplates` | Consumer — **immer zuletzt** |

## Der Auth-Knoten (Tier 2)

Hier greift die *Impl/UI* quer auf fremde Contracts — das erzeugt die scheinbare
Verschränkung. Die Contracts selbst (rechte Bedingung) hängen aber nur von SharedKernel ab:

| Repo | Impl/UI braucht | dessen `*.Contracts` braucht |
|---|---|---|
| `SDK-Auth` | Admin.Contracts, Account.Contracts, Settings.Contracts, Email.Contracts, Pages.Contracts | nur SharedKernel |
| `SDK-Admin` | Auth.Contracts, Settings.Contracts | nur SharedKernel |
| `SDK-Account` | Admin.Contracts, Settings.Contracts | nur SharedKernel |
| `SDK-Settings` | Auth.Contracts, Admin.Contracts | nur SharedKernel |

→ Im Normalbetrieb beliebige Reihenfolge (Contracts liegen schon im Feed). Nur bei einem
**Breaking-Contract-Change** diese vier als Block gemeinsam und iterativ promoten.

## Praxisregeln

1. **Normaler Flow:** Tier 0 → 5 von oben nach unten. Innerhalb eines Tiers sequenziell
   auf CI-Abschluss warten (dependent Repo restored Pakete, die erst in GitHub Packages
   liegen müssen — sonst rote Builds).
2. **Breaking Contract-Change** (z. B. `Auth.Contracts` Major): Erst das Contract-Repo
   voll durch (main + Feed), **dann** alle Tier-≥2-Konsumenten neu bauen. Nur dann ist
   die Tier-2-Reihenfolge überhaupt relevant.
3. **Kein echter Zyklus:** Die Tier-2-Contracts sind eine flache Schicht über SharedKernel.
   Eine separate Contracts-Release-Lane würde die scheinbare Verschränkung ganz auflösen,
   lohnt aber den dauerhaften Zwei-Stufen-Release-Aufwand nicht (bewusste Entscheidung).
