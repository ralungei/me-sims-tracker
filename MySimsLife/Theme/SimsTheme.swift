import SwiftUI

enum SimsTheme {

    // MARK: - Backgrounds (elegant deep — graphite-indigo-teal)

    static let bgTopLeft     = Color(hue: 230/360, saturation: 0.30, brightness: 0.09)
    static let bgMid         = Color(hue: 250/360, saturation: 0.25, brightness: 0.08)
    static let bgBottomRight = Color(hue: 200/360, saturation: 0.32, brightness: 0.07)

    static let background       = Color(hue: 230/360, saturation: 0.22, brightness: 0.07)
    static let panelBackground  = Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.55)
    static let cardBackground   = Color.white.opacity(0.05)
    static let surfaceHighlight = Color.white.opacity(0.08)

    static let mainBackground: LinearGradient = LinearGradient(
        colors: [bgTopLeft, bgMid, bgBottomRight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Foreground

    static let textPrimary  = Color(red: 0.94, green: 0.91, blue: 1.0)
    static let textSecondary = Color(red: 0.94, green: 0.91, blue: 1.0).opacity(0.55)
    static let textDim       = Color(red: 0.94, green: 0.91, blue: 1.0).opacity(0.30)

    // MARK: - Accent (elegant)

    static let accentGreen = Color(hue: 155/360, saturation: 0.40, brightness: 0.70)   // sage
    static let accentWarm  = Color(hue: 38/360,  saturation: 0.55, brightness: 0.78)   // champagne

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

    /// Sims-style indicative color — green = full, yellow = ok, orange = low, red = critical.
    /// Tones are dusty/elegant rather than fluo.
    static func valueColor(for value: Double) -> Color {
        switch value {
        case 0.65...:     return Color(hue: 145/360, saturation: 0.50, brightness: 0.68)  // sage green
        case 0.40..<0.65: return Color(hue:  45/360, saturation: 0.62, brightness: 0.72)  // champagne yellow
        case 0.20..<0.40: return Color(hue:  22/360, saturation: 0.68, brightness: 0.65)  // caramel orange
        default:          return Color(hue: 358/360, saturation: 0.55, brightness: 0.62)  // dusty red
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

    // MARK: - Mood / VITAL color (indicative — same scale as bars)

    static func plumbobColor(for mood: Double) -> Color {
        valueColor(for: mood)
    }

    static func vitalColor(for vital: Int) -> Color {
        valueColor(for: Double(vital) / 100.0)
    }

    static func vitalLabel(for vital: Int) -> String {
        switch vital {
        case 80...:   return "Pleno"
        case 60..<80: return "Ok"
        case 40..<60: return "Cuidado"
        case 20..<40: return "Bajo"
        default:      return "Crítico"
        }
    }

    // MARK: - Bar Colors (kept for legacy callers)

    static func barColor(for value: Double) -> Color {
        switch value {
        case 0.65...:     return Color(red: 0.28, green: 0.88, blue: 0.40)
        case 0.40..<0.65: return Color(red: 0.96, green: 0.78, blue: 0.08)
        case 0.20..<0.40: return Color(red: 0.96, green: 0.46, blue: 0.14)
        default:          return Color(red: 0.94, green: 0.22, blue: 0.20)
        }
    }

    static func barGradient(for value: Double) -> LinearGradient {
        let base = barColor(for: value)
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
}
