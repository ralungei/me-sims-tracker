import SwiftUI
import SwiftData

// MARK: - Treatment (medication / supplement — Botiquín tab)

/// One pill, supplement, or vitamin the user takes. Distinct from
/// `Aspiration` (self-improvement goals) because the UX needs are different:
/// adherence tracking (X/Y days), per-week dose variation, scheduled
/// reminders, finite courses, etc.
@Model
final class Treatment {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "💊"
    var hue: Double = 195

    /// Unit name (e.g. "sobre", "cápsula", "comprimido", "ml").
    var unit: String = ""
    /// Doses per take (1 cápsula, 2 sobres, etc.).
    var defaultDose: Int = 1
    /// Variation per range of weeks. Empty = always `defaultDose`.
    var schedule: [DoseStep] = []

    /// Finite course length in days. `nil` for an indefinite ongoing
    /// regimen (vitamins, chronic meds).
    var totalDays: Int?
    /// When the course started — used to compute day N/M.
    var startedAt: Date?

    /// Time of day when the user typically takes it.
    var dosingMomentRaw: String?
    /// Specific reminder time (only hour/minute matter).
    var reminderTime: Date?
    /// Whether to fire a local notification at `reminderTime`.
    var notify: Bool = false

    var notes: String?

    /// Last time the user marked it as taken. Used to know if today's dose
    /// is logged.
    var lastTakenAt: Date?
    /// Whether the course is active (paused/resumed without deletion).
    var isActive: Bool = true
    var createdAt: Date = Date()

    init(name: String,
         emoji: String = "💊",
         hue: Double = 195,
         unit: String = "",
         defaultDose: Int = 1,
         schedule: [DoseStep] = [],
         totalDays: Int? = nil,
         startedAt: Date? = nil,
         dosingMoment: DosingMoment? = nil,
         reminderTime: Date? = nil,
         notify: Bool = false,
         notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.hue = hue
        self.unit = unit
        self.defaultDose = defaultDose
        self.schedule = schedule
        self.totalDays = totalDays
        self.startedAt = startedAt
        self.dosingMomentRaw = dosingMoment?.rawValue
        self.reminderTime = reminderTime
        self.notify = notify
        self.notes = notes
    }

    var dosingMoment: DosingMoment? {
        get { dosingMomentRaw.flatMap(DosingMoment.init(rawValue:)) }
        set { dosingMomentRaw = newValue?.rawValue }
    }

    /// Day N out of `totalDays` for finite courses (1-indexed). Returns
    /// `nil` if the course has no defined length / start date.
    func currentDay(reference: Date = Date()) -> Int? {
        guard let started = startedAt, let total = totalDays else { return nil }
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: started)
        let d1 = cal.startOfDay(for: reference)
        let diff = cal.dateComponents([.day], from: d0, to: d1).day ?? 0
        return min(max(1, diff + 1), total)
    }

    /// Pluralise `unit` naively for Spanish display (sobres, cápsulas).
    static func pluralize(_ unit: String) -> String {
        guard !unit.isEmpty else { return unit }
        let last = unit.last!
        if "aeiouAEIOU".contains(last) { return unit + "s" }
        return unit + "es"
    }

    /// How many doses to take this week, considering the schedule overrides.
    func currentDose(reference: Date = Date()) -> Int {
        guard let day = currentDay(reference: reference) else { return defaultDose }
        let week = (day - 1) / 7 + 1
        // Comparison form (not `fromWeek...toWeek`): a malformed step with
        // fromWeek > toWeek would trap when constructing the ClosedRange.
        // Bad data can arrive via CloudKit from an older/buggy client.
        for step in schedule where week >= step.fromWeek && week <= step.toWeek {
            return step.count
        }
        return defaultDose
    }

    /// Today's display label, e.g. "1 sobre", "2 cápsulas".
    func currentDoseLabel(reference: Date = Date()) -> String? {
        guard !unit.isEmpty else { return nil }
        let n = currentDose(reference: reference)
        return "\(n) \(n == 1 ? unit : Self.pluralize(unit))"
    }

    /// Did the user log today's dose?
    func isTakenToday(reference: Date = Date()) -> Bool {
        guard let last = lastTakenAt else { return false }
        return Calendar.current.isDate(last, inSameDayAs: reference)
    }

    /// `true` when the course is scheduled to start on a calendar day after
    /// `reference`. Used to surface future tratamientos in a "Próximamente"
    /// section instead of mixing them with active ones.
    func isScheduledForFuture(reference: Date = Date()) -> Bool {
        guard let started = startedAt else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: started) > cal.startOfDay(for: reference)
    }
}

extension Treatment: Identifiable {}
