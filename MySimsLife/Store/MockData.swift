import Foundation
import SwiftData

// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  MockData — solo se ejecuta cuando la app se lanza con `-MockData YES`. ║
// ║  Usado para generar las screenshots de App Store en simulator. NO se     ║
// ║  carga nunca en una build distribuida — el flag solo se inyecta desde    ║
// ║  el shell script `Tools/screenshots.sh` que orquesta la captura.         ║
// ║                                                                          ║
// ║  Los nombres de aspiraciones / tratamientos / tareas dependen del idioma ║
// ║  activo (detectado via `Locale.preferredLanguages.first`).               ║
// ╚══════════════════════════════════════════════════════════════════════════╝

enum MockData {
    /// Returns `true` if the app was launched with `-MockData YES`.
    static var isRequested: Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-MockData"),
              idx + 1 < args.count else { return false }
        return args[idx + 1].uppercased() == "YES"
    }

    enum Lang { case en, es }

    private static var currentLang: Lang {
        // `Bundle.main.preferredLocalizations` reflects the localization
        // SwiftUI actually loaded resources from — respects both the
        // simulator's system locale and `-AppleLanguages` launch arg.
        // `Locale.preferredLanguages` only reads the device-wide default
        // and misses launch-arg overrides.
        let code = Bundle.main.preferredLocalizations.first ?? "en"
        return code.hasPrefix("es") ? .es : .en
    }

    /// Wipes any existing local data and inserts a curated bilingual set of
    /// aspirations, treatments, tasks, activity log entries, and need
    /// anchors — sized to make every dashboard tab look "lived-in" without
    /// being chaotic.
    static func inject(into context: ModelContext) {
        guard isRequested else { return }

        wipeAll(in: context)
        injectAspirations(in: context)
        injectTreatments(in: context)
        injectTasks(in: context)
        injectActivityLog(in: context)
        injectAnchors(in: context)
        try? context.save()
    }

    // MARK: - Wipe

    private static func wipeAll(in context: ModelContext) {
        for asp in (try? context.fetch(FetchDescriptor<Aspiration>())) ?? [] { context.delete(asp) }
        for t in (try? context.fetch(FetchDescriptor<LifeTask>())) ?? [] { context.delete(t) }
        for tr in (try? context.fetch(FetchDescriptor<Treatment>())) ?? [] { context.delete(tr) }
        for log in (try? context.fetch(FetchDescriptor<ActivityLog>())) ?? [] { context.delete(log) }
        for a in (try? context.fetch(FetchDescriptor<NeedAnchor>())) ?? [] { context.delete(a) }
    }

    // MARK: - Aspirations

    private static func injectAspirations(in context: ModelContext) {
        let now = Date()
        let cal = Calendar.current
        let todayMorning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now

        let copy = aspirationCopy(for: currentLang)

        let a1 = Aspiration(
            name: copy.creatine,
            emoji: "💊",
            kind: .dailySimple,
            hue: 38,
            xp: 10,
            notes: nil
        )
        a1.lastCompletedAt = todayMorning
        // 5-day chain so screenshots show the "🔥 5 días seguidos" streak.
        a1.completionsLog = (0..<5).compactMap {
            cal.date(byAdding: .day, value: -$0, to: todayMorning)
        }.reversed()

        let a2 = Aspiration(
            name: copy.steps,
            emoji: "👟",
            kind: .dailySimple,
            hue: 195,
            xp: 25,
            notes: nil
        )

        let a3 = Aspiration(
            name: copy.noPhone,
            emoji: "📵",
            kind: .dailySimple,
            hue: 258,
            xp: 25,
            notes: nil
        )

        let a4 = Aspiration(
            name: copy.hyrox,
            emoji: "🏃",
            kind: .oneTime,
            hue: 335,
            xp: 100,
            startedAt: cal.date(byAdding: .month, value: 5, to: now),
            notes: nil
        )

        a1.sortOrder = 0; a2.sortOrder = 1; a3.sortOrder = 2; a4.sortOrder = 3
        [a1, a2, a3, a4].forEach { context.insert($0) }
    }

    // MARK: - Treatments

    private static func injectTreatments(in context: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        let breakfast = cal.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
        let bedtime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: now) ?? now

        let copy = treatmentCopy(for: currentLang)

        let t1 = Treatment(
            name: copy.creatine,
            emoji: "💊",
            hue: 38,
            unit: copy.scoop,
            defaultDose: 1,
            schedule: [],
            totalDays: nil,
            startedAt: nil,
            dosingMoment: .withMeal,
            reminderTime: breakfast,
            notify: true,
            notes: copy.creatineNotes
        )

        let t2 = Treatment(
            name: copy.magnesium,
            emoji: "🌙",
            hue: 258,
            unit: copy.capsule,
            defaultDose: 1,
            schedule: [],
            totalDays: nil,
            startedAt: nil,
            dosingMoment: .beforeBed,
            reminderTime: bedtime,
            notify: true,
            notes: copy.magnesiumNotes
        )

        let t3 = Treatment(
            name: copy.vitD,
            emoji: "☀️",
            hue: 38,
            unit: copy.drop,
            defaultDose: 1,
            schedule: [],
            totalDays: nil,
            startedAt: startOfToday,
            dosingMoment: .withMeal,
            reminderTime: breakfast,
            notify: false,
            notes: nil
        )

        [t1, t2, t3].forEach { context.insert($0) }
    }

    // MARK: - Tasks

    private static func injectTasks(in context: ModelContext) {
        let cal = Calendar.current
        let now = Date()
        let tomorrowAt5 = cal.date(byAdding: .day, value: 1, to:
                                    cal.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now) ?? now
        let in11Days = cal.date(byAdding: .day, value: 11,
                                to: cal.date(bySettingHour: 10, minute: 30, second: 0, of: now) ?? now) ?? now

        let copy = taskCopy(for: currentLang)

        let t1 = LifeTask(title: copy.mealPrep, dueDate: nil, notes: nil, notify: false)
        t1.sortOrder = 0
        let t2 = LifeTask(title: copy.therapy, dueDate: tomorrowAt5, notes: nil, notify: true)
        t2.sortOrder = 1
        let t3 = LifeTask(title: copy.checkup, dueDate: in11Days, notes: nil, notify: true)
        t3.sortOrder = 2

        [t1, t2, t3].forEach { context.insert($0) }
    }

    // MARK: - Activity log (recent pills under each bar)

    private static func injectActivityLog(in context: ModelContext) {
        let now = Date()
        let cal = Calendar.current
        func t(_ hoursAgo: Double) -> Date {
            now.addingTimeInterval(-hoursAgo * 3600)
        }

        let copy = activityCopy(for: currentLang)

        // (NeedType, actionName, icon, boost, hoursAgo)
        let entries: [(NeedType, String, String, Double, Double)] = [
            (.energy,       copy.sleep8h,    "bed.double.fill",     100, 7),
            (.energy,       copy.nap,        "powersleep",           25, 1),
            (.mentalHealth, copy.meditated,  "brain.head.profile",   35, 3),
            (.mentalHealth, copy.journal,    "book.closed.fill",     25, 5),
            (.nutrition,    copy.breakfast,  "cup.and.saucer.fill",  50, 4),
            (.nutrition,    copy.coffee,     "cup.and.saucer.fill",  18, 1),
            (.exercise,     copy.walk,       "figure.walk",          35, 2),
            (.exercise,     copy.yoga,       "figure.yoga",          40, 9),
            (.hygiene,      copy.shower,     "shower.fill",          65, 6),
            (.hygiene,      copy.brushed,    "mouth.fill",           20, 3),
            (.social,       copy.call,       "phone.fill",           30, 4),
        ]

        for (need, name, icon, boost, hours) in entries {
            let log = ActivityLog(
                needType: need,
                actionName: name,
                actionIcon: icon,
                boostAmount: boost,
                notes: nil
            )
            log.timestamp = t(hours)
            context.insert(log)
        }
        _ = cal
    }

    // MARK: - Need anchors

    private static func injectAnchors(in context: ModelContext) {
        let now = Date()
        // Mix de valores pensado para que la captura comunique de un vistazo
        // que el color = estado: dos barras altas (verde), un par mid
        // (amarillo) y dos bajas (naranja/rojo). Cuenta una historia
        // creíble — Alex ha desayunado y dormido bien, pero hoy le toca
        // moverse y socializar.
        // (NeedType, value 0-1, enabled, anchored "hoursAgo")
        let snapshot: [(NeedType, Double, Bool, Double)] = [
            (.energy,       0.78, true, 0.5),   // verde
            (.mentalHealth, 0.88, true, 1.0),   // verde
            (.nutrition,    0.62, true, 1.0),   // amarillo
            (.exercise,     0.22, true, 1.5),   // rojo — pendiente del día
            (.hygiene,      0.92, true, 3.0),   // verde alto
            (.social,       0.35, true, 4.0),   // naranja
            (.health,       1.00, true, 0.0),
            // Not visible (disabled) in Balanced plan
            (.hydration,    0.50, false, 1.0),
            (.bladder,      0.50, false, 1.0),
            (.environment,  0.50, false, 1.0),
            (.leisure,      0.50, false, 1.0)
        ]
        for (need, value, enabled, hoursAgo) in snapshot {
            let anchor = NeedAnchor(
                needType: need,
                value: value,
                enabled: enabled,
                anchoredAt: now.addingTimeInterval(-hoursAgo * 3600)
            )
            context.insert(anchor)
        }
    }
}

// MARK: - Localized copy

private struct AspirationCopy {
    let creatine: String
    let steps: String
    let noPhone: String
    let hyrox: String
}

private struct TreatmentCopy {
    let creatine: String
    let magnesium: String
    let vitD: String
    let scoop: String
    let capsule: String
    let drop: String
    let creatineNotes: String
    let magnesiumNotes: String
}

private struct TaskCopy {
    let mealPrep: String
    let therapy: String
    let checkup: String
}

private struct ActivityCopy {
    let sleep8h: String
    let nap: String
    let meditated: String
    let journal: String
    let breakfast: String
    let coffee: String
    let walk: String
    let yoga: String
    let shower: String
    let brushed: String
    let call: String
}

private func aspirationCopy(for lang: MockData.Lang) -> AspirationCopy {
    switch lang {
    case .es:
        return AspirationCopy(
            creatine: "Creatina 5g",
            steps: "10.000 pasos",
            noPhone: "Sin móvil 1h antes de dormir",
            hyrox: "Preparación Hyrox"
        )
    case .en:
        return AspirationCopy(
            creatine: "Creatine 5g",
            steps: "10,000 steps",
            noPhone: "No phone 1h before bed",
            hyrox: "Hyrox prep"
        )
    }
}

private func treatmentCopy(for lang: MockData.Lang) -> TreatmentCopy {
    switch lang {
    case .es:
        return TreatmentCopy(
            creatine: "Creatina",
            magnesium: "Magnesio glicinato",
            vitD: "Vitamina D",
            scoop: "scoop",
            capsule: "cápsula",
            drop: "gota",
            creatineNotes: "5 g/día, evidencia ISSN. Cualquier momento del día.",
            magnesiumNotes: "1 cáps. antes de dormir. Mejora sueño y reduce ansiedad."
        )
    case .en:
        return TreatmentCopy(
            creatine: "Creatine",
            magnesium: "Magnesium glycinate",
            vitD: "Vitamin D",
            scoop: "scoop",
            capsule: "capsule",
            drop: "drop",
            creatineNotes: "5 g/day, ISSN-backed. Any time of day works.",
            magnesiumNotes: "1 capsule before bed. Improves sleep and reduces anxiety."
        )
    }
}

private func taskCopy(for lang: MockData.Lang) -> TaskCopy {
    switch lang {
    case .es:
        return TaskCopy(
            mealPrep: "Preparar tuppers",
            therapy: "Sesión con psicóloga",
            checkup: "Revisión médico anual"
        )
    case .en:
        return TaskCopy(
            mealPrep: "Weekly meal prep",
            therapy: "Therapy session",
            checkup: "Annual checkup"
        )
    }
}

private func activityCopy(for lang: MockData.Lang) -> ActivityCopy {
    switch lang {
    case .es:
        return ActivityCopy(
            sleep8h:   "Dormí 8h",
            nap:       "Siesta",
            meditated: "Medité",
            journal:   "Diario",
            breakfast: "Desayuno",
            coffee:    "Café",
            walk:      "Caminata",
            yoga:      "Yoga",
            shower:    "Ducha",
            brushed:   "Lavé dientes",
            call:      "Llamada"
        )
    case .en:
        return ActivityCopy(
            sleep8h:   "Slept 8h",
            nap:       "Nap",
            meditated: "Meditated",
            journal:   "Journal",
            breakfast: "Breakfast",
            coffee:    "Coffee",
            walk:      "Walk",
            yoga:      "Yoga",
            shower:    "Shower",
            brushed:   "Brushed teeth",
            call:      "Phone call"
        )
    }
}
