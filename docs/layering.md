# BieberWorks SDK — Layering & Package Taxonomy

This is the canonical reference for how a BieberWorks SDK module is sliced into packages,
and — most importantly — **what each layer is and is not**.

> **Read the "Presentation is not UI" section first.** It is the single most common source of
> confusion, and getting it wrong defeats the entire point of the layering.

---

## TL;DR

A module is split so that **business logic**, **presentation logic**, and the **rendered UI**
are separate packages on separate axes:

- `*.Presentation` = **ViewModels** — framework-neutral presentation *logic*. **This is not the UI.**
- `*.UI.<host>` = the **View** — the rendered widgets, bound to a specific UI framework.
- One `*.Presentation` can be rendered by **many** UIs (Blazor today; Avalonia / WPF / MAUI later).

That "one ViewModel, many Views" property is what makes the SDK portable across UI frameworks.
Collapsing the two back together re-couples the logic to Blazor and removes that property.

---

## Presentation is *not* UI

This trips up almost everyone, because the word "presentation" is overloaded.

| Reading | "Presentation" means | We use this? |
| --- | --- | --- |
| n-tier (Presentation / Business / Data) | the **whole frontend** (= the UI) | **No** |
| MVVM / Fowler "Presentation Model" | the **ViewModel** — logic behind the view | **Yes** |

In this SDK, **Presentation = ViewModel**, never "the screen".

- **`*.Presentation` (ViewModel)** — holds field values, validation state, "is loading", error
  messages, and commands. It contains **no widgets, no markup, no UI framework**. It talks to the
  backend only through `*.Contracts` (via a `*.Client`). It is unit-testable with **no renderer**
  (our `LoginViewModel`/`AuditLogViewModel` tests run green without bUnit and without a screen).
- **`*.UI.Blazor(.MudBlazor)` (View)** — the actual `.razor` / MudBlazor components the user sees
  and clicks. Framework-bound. It *binds to* a ViewModel; it is not the ViewModel.

### The litmus test

> Can the one exist without the other?
> - ViewModel without UI → **yes** (a unit test, no screen).
> - UI without ViewModel → **yes** (a dumb view).
>
> Separable ⇒ **two different layers**. Keep them in two different packages.

### The mental model

```
                 Auth.Presentation        ← ViewModel (neutral, written ONCE)
                ┌────────┼─────────┐
        Auth.UI.Blazor   │   Auth.UI.Avalonia   Auth.UI.Wpf
         (Blazor View)   │     (Linux View)     (Windows View)
                         └── all bind to the same ViewModel
```

If you ever feel the urge to "remove the UI layer because presentation is already UI" — stop. The
View has to live somewhere (the `.razor` files do not disappear), and renaming it into
`*.Presentation` makes one word mean two different things at two levels. That is *more* confusion,
not less.

---

## Package taxonomy of a full module

Example module: `Auth` (package prefix `BieberWorks.SDK.Auth`).

| Package | Layer | Contains | May reference | Must **not** reference |
| --- | --- | --- | --- | --- |
| `*.Contracts` | Contract | DTOs, interfaces, domain events | SharedKernel | EF, MudBlazor, AspNetCore.Components |
| `*.Client` | Client | HTTP client implementing the contract interfaces (for WASM / native hosts) | Contracts, `Microsoft.Extensions.Http` | EF, MudBlazor, AspNetCore.Components |
| `*.Presentation` | **ViewModel** | MVVM ViewModels (CommunityToolkit.Mvvm), view-state, commands | Contracts, Client | **any** UI framework — `AspNetCore.Components`, MudBlazor, Avalonia, … |
| `*` (bare name, e.g. `Auth`) | Server impl | EF, endpoints, `IModule`, business logic | Contracts, `Core.Web` | UI packages |
| `*.UI.Blazor` | **View** (presenter base) | framework-bound base classes that adapt a ViewModel | Presentation, Contracts, `AspNetCore.Components` | a concrete component library (MudBlazor) |
| `*.UI.Blazor.MudBlazor` | **View** (skin) | the actual `.razor` markup / MudBlazor components | its own `*.UI.Blazor`, the shared `SDK.UI.Blazor.MudBlazor` | **another module's skin** |

Not every module has every package. A "shell" module (e.g. `Admin`, `Account`) may have only
`*.Contracts` + a skin. A module with no portable client may omit `*.Client`. **Only logic-heavy
modules get a `*.Presentation`** — the extra package and DI wiring are not worth it for thin shells.

### The three independent axes

1. **UI framework / skin** — MudBlazor today; FluentUI/Radzen possible. A second Blazor skin is a
   sibling package `*.UI.Blazor.FluentUI` next to `*.UI.Blazor.MudBlazor`, sharing the same
   `*.UI.Blazor` base.
2. **Host model** — Blazor Server vs WASM. Same View, different host. The `*.Client` (in-proc vs
   HTTP) is the seam.
3. **Non-Blazor / native** — Avalonia (Linux), WPF (Windows), MAUI. A new View package
   `*.UI.Avalonia` binds to the **same** `*.Presentation`. Only the View is new.

### Localization split (resx ownership)

When a module has both a ViewModel and a View:

- Strings that become **observable state** in the ViewModel (e.g. error messages set on
  `ErrorMessage`) own their `.resx` in `*.Presentation` (its own anchor resource class,
  `IStringLocalizer<TPresentationResources>`).
- Strings consumed **only** in markup (`@Loc["…"]`) or in DataAnnotations validation attributes
  stay in `*.UI.<host>`.

Rule of thumb: *observable-state string → Presentation; markup-only string → UI.*

---

## Shared libraries (not feature modules)

| Library | Role | Notes |
| --- | --- | --- |
| `SDK-Foundation` | `SharedKernel`, `Core`, `Core.Web`, `Core.Postgres` | dependency-free primitives + host-neutral module/messaging infra (`SharedKernel`/`Core` are portable; `Core.Web`/`Core.Postgres` are server-bound). |
| `SDK-Presentation` | shared **ViewModel base class** | `BwViewModel` (CommunityToolkit.Mvvm): `IsBusy`/`ErrorMessage`/`SuccessMessage` + `RunGuardedAsync`/`<T>`. Framework-neutral, no UI. Every `*.Presentation` **inherits** it. |
| `SDK-UI` | shared **View** layer — *two natures* (see below) | `UI.Contracts` = framework-neutral abstractions (theming, cookies, overrides, time zone, viewport). `UI.Blazor` = the **View base class** `BwViewComponent<TVm>` (MudBlazor-free, holds the ViewModel→view bridge). `UI.Blazor.MudBlazor` = the shared MudBlazor **component library** (`BwDataView`, `BwShellLayout`, `BwAppBar`, `BwThemeProvider`, …). |
| `SDK-Components` | shared **content-rendering** lib (opt-in) | Markdown / code-highlighting / rich-text. Self-contained, depends on neither SDK-UI nor any feature module. Pulled in **only** by modules that render rich content (today: Pages, Legal). The neutral parsers live in `Components.Contracts` and are reusable by any host. |

### Base class vs library — the key distinction

The two "shared base" modules are **different kinds of thing**, which is why their references differ:

- **Inheritance base** (`SDK-Presentation`'s `BwViewModel`, `SDK-UI`'s `BwViewComponent<TVm>`): a layer
  **inherits** from it (`LoginViewModel : BwViewModel`, `LoginBase : BwViewComponent<LoginViewModel>`).
  This is an *is-a* relationship → a **mandatory** reference for that layer. Every `*.Presentation`
  references `SDK.Presentation`; every `*.UI.Blazor` references `SDK.UI.Blazor`.
- **Library** (`SDK-UI`'s `UI.Blazor.MudBlazor` components like `BwDataView`, and `SDK-Components`):
  a layer **uses** it *when it needs it* (`<BwDataView … />`). This is *uses-a* → an **on-demand**
  reference. A skin references `UI.Blazor.MudBlazor` only because it actually renders a `BwDataView` /
  shell; a form-only skin that needs neither simply doesn't.

So **not** every `*.UI.Blazor` references SDK-UI's components, and `*.Contracts`/`*` (impl) reference
neither base — they sit directly on Foundation. Dependencies always flow **downward** (feature layer →
its base → Foundation); nothing shared ever references a feature module.

> **SDK-UI is not renamed to "Presentation".** It is the shared *View* layer; calling it
> Presentation would name it after the opposite of what it is.

---

## Package granularity — when does something get its own package?

Neither a grab-bag nor nano-packages. The deciding factor is **dependency footprint**, *not* how many
modules use it:

- A component gets its **own package** only when it brings a **distinct heavy or conflicting
  dependency** that non-users would otherwise have to carry (e.g. a PDF engine, a native binary, a
  charting JS lib with version constraints).
- Otherwise it stays in the **cohesive, opt-in** library — even if used once.
- **Anything placed in `SDK.UI.Blazor.MudBlazor` is carried by *every* skin** (it is the universal
  shared component lib). So only broadly-relevant app-frame infrastructure with **no extra third-party
  deps** belongs there (data grid, shell, app bar, theme, time, viewport, cookies). Specialised
  concerns with their own deps (markdown via Markdig, highlighting via ColorCode) live in a separate
  opt-in lib (`SDK-Components`).
- Split **on demand**, when a real dependency boundary appears — never pre-emptively per component.

---

## Naming rules

- Base View per framework: `*.UI.Blazor`, `*.UI.Avalonia`, `*.UI.Wpf`.
- Blazor skin (one per component library): `*.UI.Blazor.MudBlazor`, `*.UI.Blazor.FluentUI`.
- **XAML skins differ from Blazor skins.** In Blazor, a different look = a different markup package.
  In XAML, a different look = a swapped `ResourceDictionary` / `ControlTheme` over the **same**
  View — *not* a parallel markup package. A dedicated `*.UI.Avalonia.Theme.*` **package** is created
  only when a second theme actually ships and needs its own versioning. No theme packages on spec.

---

## Enforced contract (CI)

The reusable workflow `BieberWorks/tooling/.github/workflows/check-sdk-deps.yml` (`@v1`) enforces
the boundaries on every pull request:

1. `*.Contracts` / `*.Presentation` must not reference MudBlazor or `AspNetCore.Components`.
2. `*.UI.Blazor` (base) must not reference MudBlazor — only the skin may.
3. No skin → skin references (`*.UI.Blazor.MudBlazor` → another `*.UI.Blazor.MudBlazor`). Shared
   component libs (`SDK.UI`, and `SDK.Components` once whitelisted) are the allowed exceptions.
4. `*.Presentation` must not use `FrameworkReference` or reference `AspNetCore.Components`.

---

## FAQ

**Is `*.Presentation` the same as `*.UI`?**
No. `*.Presentation` is the ViewModel (logic, no framework). `*.UI` is the View (widgets,
framework-bound). One ViewModel, many Views. See the litmus test above.

**Why is the ViewModel layer called "Presentation" and not "ViewModels"?**
"Presentation Model" is the established MVVM term (Fowler) for this layer. If a team finds the word
ambiguous, `*.ViewModels` is an acceptable unambiguous alternative — but the layer's *meaning* never
changes: framework-neutral logic, never the rendered UI.

**Can a native (Avalonia/WPF) app reuse a module?**
Yes — it consumes `*.Contracts` + `*.Client` + `*.Presentation` and writes its own
`*.UI.Avalonia` / `*.UI.Wpf` View. The backend (`*` server impl) is reached over HTTP via the
`*.Client`. Nothing below the View needs to change.
