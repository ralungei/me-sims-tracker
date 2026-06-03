import Foundation

/// Local UserDefaults keys. Most user prefs are mirrored to iCloud KVS via
/// `CloudPrefsMirror`; per-need state (`enabled`, `value`, `anchoredAt`)
/// lives in the `NeedAnchor` SwiftData model instead.
enum UDKey {
    /// Set once the user finishes onboarding. Mirrored to iCloud KVS so a
    /// second device skips the flow (and doesn't re-seed duplicate
    /// aspirations / treatments) once the first device has completed it.
    static let onboardingComplete = "onboardingComplete"
}
