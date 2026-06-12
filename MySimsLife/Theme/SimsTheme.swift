import SwiftUI

enum SimsTheme {

    // MARK: - Backgrounds

    /// App-wide solid background tint (#5665A7). Use this for places that
    /// need a single colour (e.g. UITabBar, system controls).
    static let background       = Color(red: 0.337, green: 0.396, blue: 0.655) // #5665A7
    /// Subtle gradient around the same #5665A7 tone — ~10 % lighter at the
    /// top-left and ~10 % darker at the bottom-right. Use for fullscreen view
    /// backgrounds where you want depth without a hard contrast.
    static let backgroundGradient: LinearGradient = LinearGradient(
        colors: [
            Color(red: 0.405, green: 0.475, blue: 0.745),  // ≈ #67799F-ish (lighter)
            Color(red: 0.337, green: 0.396, blue: 0.655),  // base #5665A7
            Color(red: 0.270, green: 0.317, blue: 0.563)   // darker
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    /// Navy outline (#0E135B) — the unified border colour for cards, tiles,
    /// chips, fields and pills across the app.
    static let frame            = Color(red: 0.055, green: 0.075, blue: 0.357)

    // MARK: - Foreground

    static let textPrimary  = Color(red: 0.055, green: 0.075, blue: 0.357)   // #0E135B
    // Secondary / dim opacities raised so navy text on `panelPeriwinkle`
    // reaches WCAG AA 4.5:1 for normal body copy. Previous values (0.65 /
    // 0.40) only gave 3.4 / 2.1, which fails on captions and section
    // headers — measured with sRGB contrast formula, not eyeballed.
    static let textSecondary = Color(red: 0.055, green: 0.075, blue: 0.357).opacity(0.80)
    static let textDim       = Color(red: 0.055, green: 0.075, blue: 0.357).opacity(0.80)

    // MARK: - Accent
    //
    // The app has ONE identity colour (`accentPrimary`, blue). Everything the
    // user reads as "selected" / "highlighted" / "CTA" uses it.
    // `accentGreen` is reserved for a *semantic* "completed / positive" signal
    // and shouldn't be used decoratively.

    static let accentPrimary = Color(red: 0.055, green: 0.075, blue: 0.357) // #0E135B — deep navy
    static let accentGreen   = Color(hue: 155/360, saturation: 0.50, brightness: 0.72) // semantic — positive / done
    /// Off-white used for the active chip in the dashboard tab cluster.
    static let tabActive     = Color(hue: 40/360,  saturation: 0.12, brightness: 0.92)

    // MARK: - Negative / Moodlet (dusty rose, not crimson)

    static let negativeTint = Color(hue: 345/360, saturation: 0.45, brightness: 0.68)

    // MARK: - Per-need helpers — bar color follows VALUE (sims-style indicative)

    /// Bar fill follows VALUE, not the need's identity hue (Sims-style
    /// indicative colour).
    static func needFill(value: Double) -> Color {
        valueColor(for: value)
    }

    /// Neutral track so the coloured fill stands out.
    static let needTrack = Color.white.opacity(0.06)

    // Sims classic moodlet palette (5 tiers) — used for bars, plumbob, VITAL.
    static let simsGreen       = Color(red: 0.298, green: 0.769, blue: 0.090)   // #4CC417 — genial
    static let simsGreenYellow = Color(red: 0.773, green: 0.867, blue: 0.239)   // #C5DD3D — bien
    static let simsYellow      = Color(red: 0.957, green: 0.878, blue: 0.157)   // #F4E028 — regular
    static let simsOrange      = Color(red: 0.941, green: 0.502, blue: 0.125)   // #F08020 — mal
    static let simsRed         = Color(red: 0.878, green: 0.188, blue: 0.125)   // #E03020 — fatal

    /// Boost text colours — darker than the moodlet greens/reds so they
    /// read clearly against the periwinkle panel bg. Use these for the
    /// `+30%` / `-10%` indicators on action cards and history rows.
    /// Tuned via WCAG sRGB ratio: #003F00 gives 4.66:1 on panelPeriwinkle,
    /// #6A0000 gives 4.95:1 — both above the AA threshold for body text.
    static let boostPositive = Color(red: 0.00, green: 0.247, blue: 0.00) // #003F00
    static let boostNegative = Color(red: 0.416, green: 0.00, blue: 0.00) // #6A0000

    /// Sims-style indicative color — 5 tiers calibrated to The Sims 2's mood
    /// bar feel: anything ≤ 45% reads as warning (orange) so the user knows to
    /// act, not just "still yellow, fine".
    static func valueColor(for value: Double) -> Color {
        switch value {
        case 0.75...:     return simsGreen        // 75-100  Genial
        case 0.60..<0.75: return simsGreenYellow  // 60-74   Bien
        case 0.45..<0.60: return simsYellow       // 45-59   Regular
        case 0.25..<0.45: return simsOrange       // 25-44   Mal
        default:          return simsRed          //  0-24   Fatal
        }
    }

    // MARK: - Per-hue helpers (need / aspiration identity colours)
    //
    // Each need (or aspiration) has a `hue` in degrees (0…360). These helpers
    // produce coherent variants — keep all hue-based saturations/brightnesses
    // here so a future palette change only needs to touch this file.

    /// Muted version used as the body of an aspiration card or similar.
    static func hueBody(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.55, brightness: 0.55)
    }

    /// Bright preview swatch used in editors (color picker circles).
    static func hueSwatch(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.55, brightness: 0.62)
    }

    // MARK: - Mood / VITAL color (indicative — same scale as bars)

    static func plumbobColor(for mood: Double) -> Color {
        valueColor(for: mood)
    }

    static func vitalLabel(for vital: Int) -> String {
        switch vital {
        case 80...:   return String(localized: "Pleno")
        case 60..<80: return String(localized: "Ok")
        case 40..<60: return String(localized: "Cuidado")
        case 20..<40: return String(localized: "Bajo")
        default:      return String(localized: "Crítico")
        }
    }

    // MARK: - Bar gradient (built from valueColor for coherence)

    static func barGradient(for value: Double) -> LinearGradient {
        let base = valueColor(for: value)
        return LinearGradient(
            colors: [base.opacity(0.70), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Typography

    static let valueFont = Font.system(.caption2, design: .rounded, weight: .bold)

    // MARK: - Dimensions (adaptive)

    static func barSpacing(compact: Bool) -> CGFloat { compact ? 8 : 14 }
    static let cornerRadius: CGFloat = 28

    // MARK: - Form field styling

    /// Periwinkle (#929FCA) — same panel colour as the needs grid. Used as
    /// the base fill for editor / form fields so input cards read against the
    /// dark gradient outer background.
    static let panelPeriwinkle = Color(red: 0.573, green: 0.624, blue: 0.792)
}

// MARK: - Form field modifier

extension View {
    /// Periwinkle fill + navy frame stroke. The unified look for input fields,
    /// pickers, and option rows across editor sheets.
    func simsFieldStyle(cornerRadius: CGFloat = 12,
                        selected: Bool = false) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(selected ? SimsTheme.tabActive : SimsTheme.panelPeriwinkle)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(SimsTheme.frame, lineWidth: selected ? 1.5 : 1.2)
                )
        )
    }

    /// Capsule variant of `simsFieldStyle` for chip-style controls.
    func simsChipStyle(selected: Bool = false) -> some View {
        background(
            Capsule()
                .fill(selected ? SimsTheme.tabActive : SimsTheme.panelPeriwinkle)
                .overlay(
                    Capsule()
                        .stroke(SimsTheme.frame, lineWidth: selected ? 1.5 : 1.0)
                )
        )
    }

    /// Large periwinkle panel with navy frame — used for grouped sections in
    /// Ajustes / sheets ("Tú", "Notificaciones", etc.). Heavier line weight
    /// (1.5pt) than `simsFieldStyle` (1.2pt) so big surfaces still read.
    func simsPanelStyle(cornerRadius: CGFloat = SimsTheme.cornerRadius) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(SimsTheme.panelPeriwinkle)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
                )
        )
    }

    /// Adds a small ellipsis menu in the bottom-right corner of the card with
    /// "Editar" / "Eliminar" actions. The visible button replaces the
    /// invisible long-press affordance so users who don't know about context
    /// menus still discover edit/delete. Long-press (`.contextMenu`) on the
    /// card itself stays as a redundant power-user shortcut.
    ///
    /// Stacks the menu as a sibling of the receiver in a ZStack so it gets
    /// its own hit area and doesn't trigger the underlying card's tap.
    func simsCardMenu(onEdit: @escaping () -> Void,
                      onDelete: @escaping () -> Void,
                      extras: [SimsCardMenuAction] = []) -> some View {
        modifier(SimsCardMenuModifier(onEdit: onEdit, onDelete: onDelete, extras: extras))
    }
}

/// Extra entry for `simsCardMenu` between Editar and Eliminar — e.g. the
/// botiquín's "Pausar". Plain data so call sites stay declarative.
struct SimsCardMenuAction: Identifiable {
    let id = UUID()
    let title: String
    let systemImage: String
    let action: () -> Void
}

private struct SimsCardMenuModifier: ViewModifier {
    let onEdit: () -> Void
    let onDelete: () -> Void
    var extras: [SimsCardMenuAction] = []

    func body(content: Content) -> some View {
        ZStack(alignment: .bottomTrailing) {
            content
                // Long-press shortcut for users who prefer it. Same actions
                // as the visible ellipsis Menu — one declaration, two
                // surfaces.
                .contextMenu {
                    Button { onEdit() } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    ForEach(extras) { extra in
                        Button { extra.action() } label: {
                            Label(extra.title, systemImage: extra.systemImage)
                        }
                    }
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            Menu {
                Button { onEdit() } label: {
                    Label("Editar", systemImage: "pencil")
                }
                ForEach(extras) { extra in
                    Button { extra.action() } label: {
                        Label(extra.title, systemImage: extra.systemImage)
                    }
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(SimsTheme.frame)
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.7))
                            .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }
}

// MARK: - Editor scaffold (NavigationStack + bg + ScrollView + toolbar)

/// Wraps the `NavigationStack { ZStack { gradient + ScrollView } }` shell that
/// every editor sheet (Aspiration / Task / Treatment / CustomAction / Profile)
/// was repeating. Editors only describe their fields — title, validity, save.
///
/// Pass `saveLabel: "Registrar"` for `CustomActionSheet`; the default
/// `"Guardar"` covers the rest.
struct SimsEditorScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let saveLabel: LocalizedStringKey
    let isValid: Bool
    let onSave: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.dismiss) private var dismiss

    init(title: LocalizedStringKey,
         saveLabel: LocalizedStringKey = "Guardar",
         isValid: Bool,
         onSave: @escaping () -> Void,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.saveLabel = saveLabel
        self.isValid = isValid
        self.onSave = onSave
        self.content = content
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        content()
                    }
                    .padding(20)
                }
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(SimsTheme.panelPeriwinkle, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saveLabel) { onSave() }
                        .disabled(!isValid)
                        .bold()
                }
            }
        }
    }
}

// MARK: - Section header + content

/// Caption-2 uppercase title above a content block. The standard "field
/// section" used inside every editor.
struct SimsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(SimsTheme.textSecondary)
            content()
        }
    }
}

// MARK: - Destructive button used at the bottom of editors

/// Full-width "Eliminar X" button — `boostNegative` solid bg + navy frame +
/// white text. Pass the action; the view doesn't manage dismiss/state itself.
struct SimsDeleteButton: View {
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                Image(systemName: "trash")
                Text(label)
            }
            .font(.system(.body, design: .rounded, weight: .bold))
            .frame(maxWidth: .infinity)
            .padding(14)
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SimsTheme.boostNegative)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SimsTheme.frame, lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selectable icon-and-label chip

/// Compact chip with leading SF Symbol + label. Selection tinted via
/// `simsChipStyle`. Used by editors with single-select scrollable choosers
/// (dosing moments, etc.).
struct SimsSelectableChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(.caption, design: .rounded, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(SimsTheme.textPrimary)
            .simsChipStyle(selected: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable "create" card (Nueva aspiración / Nueva tarea / Añadir personalizada)

/// Dashed-border card for "create new" affordances. Single label so there's
/// no awkward gap between "Nueva" and "aspiración". Reused across the three
/// add-flows so they look identical (size and style).
struct SimsCreateCard: View {
    let label: LocalizedStringKey
    var width: CGFloat = 96
    var height: CGFloat = 100
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(SimsTheme.frame.opacity(0.55),
                                style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
                Text(label)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(10)
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SimsTheme.panelPeriwinkle.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SimsTheme.frame,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sims-style outlined icon

/// Faked-stroke SF Symbol — navy outline (heavier weight) layered behind a
/// white fill (regular weight). Used on tile-backgrounds across the app
/// (need bars, alert tiles, action previews, category rows) so SF Symbols
/// read with a consistent Sims-2 outlined look.
struct SimsOutlinedIcon: View {
    let systemName: String
    /// Point size of the white fill. The navy outline renders at `size + 2`
    /// to fake the stroke.
    let size: CGFloat

    var body: some View {
        ZStack {
            Image(systemName: systemName)
                .font(.system(size: size + 2, weight: .black))
                .foregroundStyle(SimsTheme.frame)
            Image(systemName: systemName)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }
}

/// Tinted gradient + navy frame — the standard "icon tile" backdrop used
/// next to outlined icons. Pair with `SimsOutlinedIcon` for the full Sims-2
/// avatar look.
struct SimsTintedTile: View {
    let tint: Color
    var cornerRadius: CGFloat = 12
    var lineWidth: CGFloat = 1.5

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient(
                colors: [tint.opacity(0.85), tint.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(SimsTheme.frame, lineWidth: lineWidth)
            )
    }
}
