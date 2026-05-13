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

// MARK: - Reduce Motion

/// A view modifier wrapping `.animation(_:value:)` that collapses to
/// no-animation when `accessibilityReduceMotion` is on. Use instead of
/// `.animation()` everywhere a state change triggers spring/bounce
/// motion — those are the kind that cause vestibular discomfort.
private struct ReduceMotionAware<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation?
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Drop-in replacement for `.animation(_:value:)` that honours
    /// Reduce Motion. The whole app should funnel through this so we
    /// don't have to remember to add `@Environment(\.reduceMotion)`
    /// in every view.
    func simsAnimation<V: Equatable>(_ animation: Animation?,
                                     value: V) -> some View {
        modifier(ReduceMotionAware(animation: animation, value: value))
    }
}

extension AnyTransition {
    /// `transition` collapsed to no-op when Reduce Motion is on, otherwise
    /// the supplied transition. Wrap with a SwiftUI environment lookup at
    /// the use site since `AnyTransition` itself can't read the environment.
    static func simsRespectingMotion(_ transition: AnyTransition,
                                     reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .identity : transition
    }
}
