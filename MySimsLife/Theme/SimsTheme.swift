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
    /// Translucent surface for cards and pills sitting on top of `background`.
    static let cardBackground   = Color.white.opacity(0.05)
    static let surfaceHighlight = Color.white.opacity(0.08)
    /// Navy outline (#0E135B) — the unified border colour for cards, tiles,
    /// chips, fields and pills across the app.
    static let frame            = Color(red: 0.055, green: 0.075, blue: 0.357)
    /// Slightly darker overlay used inside sheets/list rows when something
    /// needs to read as "panel on the surface". Kept opt-in.
    static let panelBackground  = Color.black.opacity(0.18)

    // MARK: - Foreground

    static let textPrimary  = Color(red: 0.055, green: 0.075, blue: 0.357)   // #0E135B
    static let textSecondary = Color(red: 0.055, green: 0.075, blue: 0.357).opacity(0.65)
    static let textDim       = Color(red: 0.055, green: 0.075, blue: 0.357).opacity(0.40)

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

    static let negativeTint        = Color(hue: 345/360, saturation: 0.45, brightness: 0.68)
    static let moodletBackground   = Color(hue: 345/360, saturation: 0.30, brightness: 0.18)
    static let moodletActiveBorder = Color(hue: 345/360, saturation: 0.40, brightness: 0.55)

    // MARK: - Per-need helpers — bar color follows VALUE (sims-style indicative)

    static func needFill(hue: Double, value: Double) -> Color {
        // Ignore hue: bar color reflects state, not identity
        valueColor(for: value)
    }

    static func needTrack(hue: Double) -> Color {
        // Neutral track so the colored fill stands out
        Color.white.opacity(0.06)
    }

    // Sims classic moodlet palette (5 tiers) — used for bars, plumbob, VITAL.
    static let simsGreen       = Color(red: 0.298, green: 0.769, blue: 0.090)   // #4CC417 — genial
    static let simsGreenYellow = Color(red: 0.773, green: 0.867, blue: 0.239)   // #C5DD3D — bien
    static let simsYellow      = Color(red: 0.957, green: 0.878, blue: 0.157)   // #F4E028 — regular
    static let simsOrange      = Color(red: 0.941, green: 0.502, blue: 0.125)   // #F08020 — mal
    static let simsRed         = Color(red: 0.878, green: 0.188, blue: 0.125)   // #E03020 — fatal
    /// "Platino" — reserved for completion / aspiración cumplida.
    static let simsPlatinum    = Color.white

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

    static func needTileGradient(hue: Double) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: hue/360, saturation: 0.55, brightness: 0.30),
                Color(hue: hue/360, saturation: 0.45, brightness: 0.20)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    // MARK: - Per-hue helpers (need / aspiration identity colours)
    //
    // Each need (or aspiration) has a `hue` in degrees (0…360). These helpers
    // produce coherent variants — keep all hue-based saturations/brightnesses
    // here so a future palette change only needs to touch this file.

    /// Bright, saturated tint used for a hue's icon on dark backgrounds.
    static func hueIconColor(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.50, brightness: 0.95)
    }

    /// Muted version used as the body of an aspiration card or similar.
    static func hueBody(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.55, brightness: 0.55)
    }

    /// Bright preview swatch used in editors (color picker circles).
    static func hueSwatch(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.55, brightness: 0.62)
    }

    /// Top stop of a per-hue card gradient.
    static func hueGradientTop(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.65, brightness: 0.30)
    }

    /// Bottom stop of a per-hue card gradient.
    static func hueGradientBottom(_ hueDeg: Double) -> Color {
        Color(hue: hueDeg/360, saturation: 0.55, brightness: 0.20)
    }

    /// Stroke colour for a per-hue card / chip border.
    static func hueStroke(_ hueDeg: Double, opacity: Double = 0.5) -> Color {
        Color(hue: hueDeg/360, saturation: 0.65, brightness: 0.55).opacity(opacity)
    }

    // MARK: - Mood / VITAL color (indicative — same scale as bars)

    static func plumbobColor(for mood: Double) -> Color {
        valueColor(for: mood)
    }

    static func vitalColor(for vital: Int) -> Color {
        valueColor(for: Double(vital) / 100.0)
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

    static func barColor(for value: Double) -> Color { valueColor(for: value) }

    static func barGradient(for value: Double) -> LinearGradient {
        let base = valueColor(for: value)
        return LinearGradient(
            colors: [base.opacity(0.70), base],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Typography

    static let titleFont    = Font.system(.title2, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let labelFont    = Font.system(.caption, design: .rounded, weight: .medium)
    static let valueFont    = Font.system(.caption2, design: .rounded, weight: .bold)

    // MARK: - Dimensions (adaptive)

    static func barHeight(compact: Bool) -> CGFloat { compact ? 14 : 22 }
    static func barSpacing(compact: Bool) -> CGFloat { compact ? 8 : 14 }
    static let cornerRadius: CGFloat = 28
    static let panelPadding: CGFloat = 22

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
