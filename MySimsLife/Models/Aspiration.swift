import SwiftUI
import SwiftData

// MARK: - Aspiration Kind

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
        startedAt: Date? = nil
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
        self.completionsLog = []
        self.createdAt = Date()
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

    func progress(reference: Date = Date()) -> Double {
        switch kind {
        case .dailySimple, .dailyTimed, .weekly:
            return isDoneNow(reference: reference) ? 1.0 : 0.0
        case .treatment:
            guard let day = treatmentDay(reference: reference), let total = totalDays else { return 0 }
            return Double(day) / Double(total)
        }
    }

    // MARK: - Defaults seed

    static func seedDefaults(into context: ModelContext) {
        let aspirations: [Aspiration] = [
            Aspiration(
                name: "Gateway Tapes", emoji: "🧘",
                kind: .dailyTimed, hue: 258, xp: 25,
                durationMinutes: 25
            ),
            Aspiration(
                name: "Creatina 5g", emoji: "💊",
                kind: .dailySimple, hue: 22, xp: 10
            ),
            Aspiration(
                name: "Prebióticos", emoji: "🌱",
                kind: .treatment, hue: 158, xp: 10,
                totalDays: 30,
                startedAt: Calendar.current.date(byAdding: .day, value: -11, to: Date())
            ),
            Aspiration(
                name: "Reel en IG", emoji: "🎬",
                kind: .weekly, hue: 295, xp: 50
            )
        ]
        for (i, asp) in aspirations.enumerated() {
            asp.sortOrder = i
            context.insert(asp)
        }
        try? context.save()
    }
}
