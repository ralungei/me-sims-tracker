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
        case .fasting:      return "En ayunas"
        case .midMorning:   return "Media mañana"
        case .beforeMeal:   return "Antes de comida"
        case .beforeLunch:  return "Antes del almuerzo"
        case .beforeDinner: return "Antes de cenar"
        case .withMeal:     return "Con la comida"
        case .afterMeal:    return "Después de comer"
        case .beforeBed:    return "Al acostarse"
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

enum AspirationKind: String, Codable, CaseIterable {
    case dailySimple    // Tap once per day. Ej: creatina 5g
    case dailyTimed     // Daily + duration. Ej: Gateway Tapes 25min
    case treatment      // Finite course, day N/M. Ej: Prebióticos día 12/30
    case weekly         // Once per week. Ej: Reel IG

    var label: String {
        switch self {
        case .dailySimple: return "Diario"
        case .dailyTimed:  return "Diario · sesión"
        case .treatment:   return "Tratamiento"
        case .weekly:      return "Semanal"
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
        case .dailySimple: return "Diario"
        case .dailyTimed:  return "Diario con sesión"
        case .treatment:   return "Tratamiento"
        case .weekly:      return "Semanal"
        }
    }

    var hint: String {
        switch self {
        case .dailySimple: return "Una vez al día (ej: creatina)"
        case .dailyTimed:  return "Diario con duración (ej: meditar 25 min)"
        case .treatment:   return "Curso finito con progreso (ej: prebióticos 30 días)"
        case .weekly:      return "Una vez por semana (ej: postear reel)"
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
        reminderTime: Date? = nil
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
        self.completionsLog = []
        self.createdAt = Date()
    }

    var dosingMoment: DosingMoment? {
        get { dosingMomentRaw.flatMap { DosingMoment(rawValue: $0) } }
        set { dosingMomentRaw = newValue?.rawValue }
    }

    /// True if `startedAt` is in the future. Treatment-kind aspirations should be hidden until then.
    func isScheduledForFuture(reference: Date = Date()) -> Bool {
        guard kind == .treatment, let started = startedAt else { return false }
        return started > reference
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
