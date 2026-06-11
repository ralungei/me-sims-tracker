# CLAUDE.md

Project-specific notes for myself. Read this before doing anything in this repo.

## Quick orientation

**My Sims Life** — Sims-2-style life tracker (iOS + macOS). SwiftUI front, SwiftData persistence, **CloudKit** for cross-device sync. No backend, no MCP. The user pays Apple Developer Program; iCloud handles all sync.

- Models: `MySimsLife/Models/` — `NeedType` (enum, 11 needs), `NeedAnchor`, `Aspiration`, `LifeTask`, `Treatment`, `ActivityLog`. All except `NeedType` are `@Model` synced via CloudKit.
- Single store: `MySimsLife/Store/NeedStore.swift` (`@Observable`). Mutations write to SwiftData; CloudKit pushes/pulls automatically.
- `MySimsLife/Store/CloudPrefsMirror.swift` — small helper that mirrors UserDefaults prefs (userName, notif toggles) to `NSUbiquitousKeyValueStore` (iCloud Key-Value Store).
- Theme primitives: `MySimsLife/Theme/SimsTheme.swift` — reuse `simsFieldStyle`, `simsChipStyle`, `simsPanelStyle`, `simsCardMenu`, `SimsSection`, `SimsEditorScaffold`, `SimsDeleteButton`, `SimsSelectableChip`, `SimsCreateCard`, `SimsOutlinedIcon`, `SimsTintedTile` BEFORE writing new ones.
- Build: `xcodebuild -project MySimsLife.xcodeproj -scheme MySimsLife -destination 'generic/platform=iOS Simulator' -configuration Debug build`
- New file added → `xcodegen generate` BEFORE building.

## Architecture: source of truth = CloudKit

Everything synced lives in SwiftData with `cloudKitDatabase: .automatic`. There's no Cloudflare worker, no custom backend, no MCP server. **Don't recreate any of those.**

What flows through CloudKit (free, automatic, encrypted, per-Apple-ID):
- `Aspiration` rows
- `LifeTask` rows
- `Treatment` rows
- `ActivityLog` rows
- `NeedAnchor` rows (one per need; carries `value`, `anchoredAt`, `enabled`)

What flows through iCloud Key-Value Store (`CloudPrefsMirror`):
- `userName`
- `NotificationsPrefs.*` (master + sub-toggles + threshold + cooldown)

What stays per-device (UserDefaults, never synced):
- `notif.lastFired.<need>` cooldown timestamps
- The in-memory cache of decayed values (recomputed locally from anchors)

### Realtime cross-device updates

`NeedStore.startRemoteChangeListener()` subscribes to `NSPersistentStoreRemoteChange`. When CloudKit pushes a change from another device, the listener debounces 0.5 s and re-runs `ensureAnchors() / refreshAspirations() / refreshTasks() / refreshRecentActionsCache()`. UI updates without waiting for foreground.

## When the user asks me to add personal data ("añademe X")

Use the **app's editors**. They write to SwiftData → CloudKit propagates.

- Treatment → Botiquín tab → "+ Nuevo tratamiento"
- Aspiration → Aspiraciones tab → "+ Nueva aspiración"
- Task → Agenda tab → "+ Nueva tarea"

If the user wants me to insert programmatically, **don't write a `OneShotMigrations` file** — the user explicitly burned us on that pattern (each device runs the migration → duplicate items in CloudKit). Two valid alternatives:

1. Walk the user through adding it from the app's UI (preferred).
2. Use the Xcode model debugger or a temporary code path the user runs once on a single device, then deletes the code.

**Never seed data in `NeedStore.configure(with:)` or `MySimsLifeApp.init()`**. Anything inserted there will run on every device, every install — that's the bug we deleted.

## Working with anchors (NeedAnchor)

- One row per `NeedType`. Created on first launch by `ensureAnchors()`.
- `value` + `anchoredAt` form the source of truth for the bar's position.
- `enabled` carries which categories the user has switched on.
- Decay is **never written**. Each device computes `displayValue = anchor.value − decay(now − anchor.anchoredAt)` locally so all devices converge.
- User actions update the anchor: `upsertAnchor(for: need, value: newValue, bumpTimestamp: true)`. SwiftData saves → CloudKit pushes → other devices receive the new anchor → their local recompute lands on the same value.

If two devices anchor the same need simultaneously, CloudKit creates two rows. `ensureAnchors()` dedupes on read by keeping the one with the latest `anchoredAt`.

## Cálculos / dosis

When the user asks for calculations (ej: "creatina para 74kg"):
- Do the math inline; cite the standard (ISSN, ACSM, etc.).
- Put the rationale in `notes` on the model so the user sees it from the editor later.
- Default to evidence-based values; round to a standard scoop / pill size unless the user wants exact.

## Field-value cheat sheet (when adding via editors)

**`hue`** — match the activity. Palette presets: `[22, 38, 158, 195, 220, 258, 295, 335]`.
- 22 (honey/orange) → digestion, prebióticos
- 38 (champagne) → energía, creatina, vitamina D
- 158 (sage mint) → higiene, plantas
- 195 (dusty teal) → hidratación, omega 3
- 220 (indigo) → ocio, estudio
- 258 (lavender) → entorno, casa
- 280 (violet) → salud mental, meditación
- 295 (orchid) → social
- 335 (dusty rose) → cuidado personal, ejercicio

**`xp` (Aspirations)**: 5 mini · 10 small · 25 medium · 50 big · 100 epic

**`AspirationKind`** (pickable only): `.dailySimple` · `.dailyTimed` · `.weekly` · `.oneTime`

## Calibration (gate antes de subir cambios al modelo)

La app vive y muere por su calibración — cómo de rápido decaen las
barras, cuánto boost da cada acción, qué VITAL se considera "sano".
Hay un harness reproducible en `Tools/CalibrationCheck.swift`.

**Cuándo correr (obligatorio):**

- Toco `decayRatePerHour` o `moodWeight` en `NeedType.swift`
- Añado / cambio el `boost` de alguna `QuickAction`
- Cambio la fórmula de `vitalScore` o `overallMood` en `NeedStore`
- Añado una `NeedType` nueva → actualizar también las tablas del script

**Cómo:**

```bash
swift Tools/CalibrationCheck.swift
```

35 checks pasan en estado base. Si añado algo que rompe alguno, o lo
arreglo o justifico el cambio en `docs/CALIBRATION.md` y ajusto la
expectativa allí mismo. Nunca silenciar un FAIL sin documentar.

Spec completa de qué verifica cada escenario (y por qué los rangos son
los que son) → **[docs/CALIBRATION.md](docs/CALIBRATION.md)**.

## Conventions

- **Localizable strings** → `MySimsLife/Localizable.xcstrings`. Spanish first. `String(localized: ...)` or `Text("...")`.
- **Build verification** after each change. No "done" without `BUILD SUCCEEDED`.
- **SourceKit "cannot find type"** = multi-file Swift indexing noise. Ignore if `xcodebuild` passes.
- **No `print` debugging** left in code.
