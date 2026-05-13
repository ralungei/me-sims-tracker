import Foundation

/// Local UserDefaults keys. Most user prefs are mirrored to iCloud KVS via
/// `CloudPrefsMirror`; per-need state (`enabled`, `value`, `anchoredAt`)
/// lives in the `NeedAnchor` SwiftData model instead.
enum UDKey {
    static let userName = "userName"
}
