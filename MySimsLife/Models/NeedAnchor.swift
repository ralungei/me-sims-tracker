import Foundation
import SwiftData

/// Synced "anchor" for a single NeedType — the value at the moment of the
/// last user action (or reset / toggle), plus the timestamp it was set.
/// Decay is **not stored**: every device computes elapsed decay locally on
/// top of this anchor, so as long as both devices see the same anchor they
/// render the same effective bar value.
///
/// One row per NeedType is the intent. Concurrent inserts on different
/// devices can briefly produce duplicates while CloudKit reconciles —
/// `NeedStore` dedupes on read by keeping the row with the latest
/// `anchoredAt`.
@Model
final class NeedAnchor {
    var needTypeRaw: String = ""
    /// Value (0…1) at `anchoredAt`. The displayed bar is
    /// `value − decay(now − anchoredAt)`.
    var value: Double = 0.5
    /// Last user action / reset timestamp. Decay is measured from here.
    var anchoredAt: Date = Date()
    /// Whether this need is shown in the dashboard. Lives here so a
    /// category toggle on one device flows to others.
    var enabled: Bool = true
    var createdAt: Date = Date()

    init(needType: NeedType,
         value: Double = 0.5,
         enabled: Bool = true,
         anchoredAt: Date = Date()) {
        self.needTypeRaw = needType.rawValue
        self.value = value
        self.enabled = enabled
        self.anchoredAt = anchoredAt
        self.createdAt = Date()
    }

    var needType: NeedType? { NeedType(rawValue: needTypeRaw) }
}

extension NeedAnchor: Identifiable {}
