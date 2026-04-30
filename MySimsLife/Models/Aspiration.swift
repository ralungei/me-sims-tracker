import SwiftUI
import SwiftData

// MARK: - Aspiration Kind

// MARK: - Dosing Moment (when to take a recurring intake)

enum DosingMoment: String, Codable, CaseIterable {
    case fasting       // en ayunas
    case midMorning    // media mañana
    case beforeMeal    // antes de la comida
    case beforeLunch   // antes del almuerzo
    case beforeDinner  // antes de cenar
    case withMeal      // con la comida
    case afterMeal     // después de comer
    case beforeBed     // antes de dormir

    var label: String {
        switch self {
        case .fasting:      return String(localized: "En ayunas")
        case .midMorning:   return String(localized: "Media mañana")
        case .beforeMeal:   return String(localized: "Antes de comida")
        case .beforeLunch:  return String(localized: "Antes del almuerzo")
        case .beforeDinner: return String(localized: "Antes de cenar")
        case .withMeal:     return String(localized: "Con la comida")
        case .afterMeal:    return String(localized: "Después de comer")
        case .beforeBed:    return String(localized: "Al acostarse")
        }
    }

    var icon: String {
        switch self {
        case .fasting:      return "sunrise"
        case .midMorning:   return "sun.max.fill"
        case .beforeMeal,
             .beforeLunch,
             .beforeDinner: return "fork.knife.circle"
        case .withMeal:     return "fork.knife"
        case .afterMeal:    return "checkmark.circle"
        case .beforeBed:    return "moon.stars.fill"
        }
    }

    /// Suggested wall-clock hour (Europe/Madrid-ish defaults).
    var defaultHour: Int {
        switch self {
        case .fasting:      return 8
        case .midMorning:   return 11
        case .beforeMeal,
             .beforeLunch:  return 14
        case .beforeDinner: return 21
        case .withMeal:     return 14
        case .afterMeal:    return 15
        case .beforeBed:    return 23
        }
    }
}

// MARK: - Dose schedule (variable dose per treatment week)

/// One contiguous range of weeks during a treatment with a fixed dose count.
struct DoseStep: Codable, Equatable, Hashable {
    var fromWeek: Int       // 1-based, inclusive
    var toWeek: Int         // 1-based, inclusive
    var count: Int          // number of units (sobres / cápsulas / etc.) per intake
}

enum AspirationKind: String, Codable, CaseIterable {
    case dailySimple    // Tap once per day. Ej: creatina 5g
    case dailyTimed     // Daily + duration. Ej: Gateway Tapes 25min
    case treatment      // Finite course, day N/M. Ej: Prebióticos día 12/30
    case weekly         // Once per week. Ej: Reel IG

    var label: String {
        switch self {
        case .dailySimple: return String(localized: "Diario")
        case .dailyTimed:  return String(localized: "Diario · sesión")
        case .treatment:   return String(localized: "Tratamiento")
        case .weekly:      return String(localized: "Semanal")
        }
    }

    var icon: String {
        switch self {
        case .dailySimple: return "sun.max.fill"
        case .dailyTimed:  return "timer"
        case .treatment:   return "leaf.fill"
        case .weekly:      return "calendar"
        }
    }

    var title: String {
        switch self {
        case .dailySimple: return String(localized: "Diario")
        case .dailyTimed:  return String(localized: "Diario con sesión")
        case .treatment:   return String(localized: "Tratamiento")
        case .weekly:      return String(localized: "Semanal")
        }
    }

    var hint: String {
        switch self {
        case .dailySimple: return String(localized: "Una vez al día (ej: creatina)")
        case .dailyTimed:  return String(localized: "Diario con duración (ej: meditar 25 min)")
        case .treatment:   return String(localized: "Curso finito con progreso (ej: prebióticos 30 días)")
        case .weekly:      return String(localized: "Una vez por semana (ej: postear reel)")
        }
    }
}

// MARK: - Aspiration (SwiftData @Model — syncs via CloudKit)

@Model
final class Aspiration {
    var id: UUID = UUID()
    var name: String = ""
    var emoji: String = "✨"
    var kindRaw: String = AspirationKind.dailySimple.rawValue
    var hue: Double = 220
    var xp: Int = 10

    var durationMinutes: Int?
    var totalDays: Int?
    var startedAt: Date?

    var notes: String?
    var dosingMomentRaw: String?
    /// Stored as a `Date`; only the hour/minute components are meaningful.
    var reminderTime: Date?

    /// Free-form unit name shown in the card: "sobre", "cápsula", "comprimido", "ml"…
    /// Empty / nil → no dose label is rendered.
    var unit: String?
    /// Dose used when there's no `schedule` covering the current week.
    var defaultDose: Int = 1
    /// JSON-encoded `[DoseStep]`. Variable doses per week of treatment.
    var scheduleRaw: String?

    var lastCompletedAt: Date?
    var completionsLog: [Date] = []

    var createdAt: Date = Date()
    var sortOrder: Int = 0

    init(
        name: String,
        emoji: String = "✨",
        kind: AspirationKind = .dailySimple,
        hue: Double = 220,
        xp: Int = 10,
        durationMinutes: Int? = nil,
        totalDays: Int? = nil,
        startedAt: Date? = nil,
        notes: String? = nil,
        dosingMoment: DosingMoment? = nil,
        reminderTime: Date? = nil,
        unit: String? = nil,
        defaultDose: Int = 1,
        schedule: [DoseStep] = []
    ) {
        self.id = UUID()
        self.name = name
        self.emoji = emoji
        self.kindRaw = kind.rawValue
        self.hue = hue
        self.xp = xp
        self.durationMinutes = durationMinutes
        self.totalDays = totalDays
        self.startedAt = startedAt
        self.notes = notes
        self.dosingMomentRaw = dosingMoment?.rawValue
        self.reminderTime = reminderTime
        self.unit = unit
        self.defaultDose = defaultDose
        self.completionsLog = []
        self.createdAt = Date()
        self.schedule = schedule
    }

    // MARK: - Schedule

    var schedule: [DoseStep] {
        get {
            guard let raw = scheduleRaw, !raw.isEmpty else { return [] }
            return (try? JSONDecoder().decode([DoseStep].self, from: Data(raw.utf8))) ?? []
        }
        set {
            guard !newValue.isEmpty else { scheduleRaw = nil; return }
            scheduleRaw = (try? String(data: JSONEncoder().encode(newValue), encoding: .utf8)) ?? nil
        }
    }

    /// 1-based week index inside the treatment for `reference`. nil if N/A.
    func treatmentWeek(reference: Date = Date()) -> Int? {
        guard let day = treatmentDay(reference: reference) else { return nil }
        return ((day - 1) / 7) + 1
    }

    /// Number of units to take today, taking the schedule into account if any.
    /// nil if `unit` isn't set (caller should hide the dose row).
    func currentDoseCount(reference: Date = Date()) -> Int? {
        guard let unit, !unit.isEmpty else { return nil }
        if let week = treatmentWeek(reference: reference),
           let step = schedule.first(where: { week >= $0.fromWeek && week <= $0.toWeek }) {
            return step.count
        }
        return defaultDose
    }

    /// Pretty "1 sobre" / "2 cápsulas" / nil.
    func currentDoseLabel(reference: Date = Date()) -> String? {
        guard let unit, !unit.isEmpty,
              let count = currentDoseCount(reference: reference) else { return nil }
        return "\(count) \(count == 1 ? unit : Aspiration.pluralize(unit))"
    }

    /// Spanish: vowel-ending → +s, consonant → +es. Good enough for "sobre",
    /// "cápsula", "comprimido", "ml". Static so views (the editor's preview
    /// label) can reuse it without instantiating a model.
    static func pluralize(_ word: String) -> String {
        guard let last = word.last?.lowercased().first else { return word }
        return "aeiouáéíóú".contains(last) ? word + "s" : word + "es"
    }

    var dosingMoment: DosingMoment? {
        get { dosingMomentRaw.flatMap { DosingMoment(rawValue: $0) } }
        set { dosingMomentRaw = newValue?.rawValue }
    }

    /// True if `startedAt` is on a calendar day after `reference`. Treatments
    /// scheduled for *today* count as active so the user sees the card from
    /// the very first day, regardless of the time of day stored in `startedAt`.
    func isScheduledForFuture(reference: Date = Date()) -> Bool {
        guard kind == .treatment, let started = startedAt else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: started) > cal.startOfDay(for: reference)
    }

    var kind: AspirationKind {
        get { AspirationKind(rawValue: kindRaw) ?? .dailySimple }
        set { kindRaw = newValue.rawValue }
    }

    // MARK: - Derived state

    func isDoneNow(reference: Date = Date()) -> Bool {
        guard let last = lastCompletedAt else { return false }
        let cal = Calendar.current
        switch kind {
        case .dailySimple, .dailyTimed, .treatment:
            return cal.isDate(last, inSameDayAs: reference)
        case .weekly:
            return cal.isDate(last, equalTo: reference, toGranularity: .weekOfYear)
        }
    }

    func treatmentDay(reference: Date = Date()) -> Int? {
        guard kind == .treatment, let started = startedAt, let total = totalDays else { return nil }
        let cal = Calendar.current
        let d0 = cal.startOfDay(for: started)
        let d1 = cal.startOfDay(for: reference)
        let diff = cal.dateComponents([.day], from: d0, to: d1).day ?? 0
        return min(max(1, diff + 1), total)
    }

}

// `var id: UUID = UUID()` is already defined above; conformance is a one-liner.
extension Aspiration: Identifiable {}
