import SwiftUI

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║ Accessibility helpers                                                    ║
// ║                                                                          ║
// ║ Centralizes the qualitative descriptions VoiceOver speaks for need bars  ║
// ║ and other 0-1 values, so we stay consistent across views.                ║
// ║                                                                          ║
// ║ The thresholds match the visual colour tiers in `SimsTheme.valueColor`:  ║
// ║ red < 0.25 < orange < 0.50 < yellow < 0.75 < green.                      ║
// ╚══════════════════════════════════════════════════════════════════════════╝

enum BarLevel {
    case critical, low, okay, good, full

    init(value: Double) {
        switch value {
        case ..<0.25: self = .critical
        case ..<0.50: self = .low
        case ..<0.75: self = .okay
        case ..<0.95: self = .good
        default:      self = .full
        }
    }

    /// Localized one-word status. Used in VoiceOver values like
    /// "78 percent, good".
    var spokenWord: String {
        switch self {
        case .critical: return String(localized: "crítico")
        case .low:      return String(localized: "bajo")
        case .okay:     return String(localized: "regular")
        case .good:     return String(localized: "bien")
        case .full:     return String(localized: "lleno")
        }
    }
}

extension Double {
    /// Pre-formatted VoiceOver value for a 0–1 need value, e.g.
    /// `"78 por ciento, bien"`. Saves wiring `BarLevel` everywhere.
    var accessibilityNeedValue: String {
        let pct = Int((self * 100).rounded())
        let level = BarLevel(value: self).spokenWord
        return String(localized: "\(pct) por ciento, \(level)")
    }
}
