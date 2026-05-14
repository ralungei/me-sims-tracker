import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

@Observable
final class NeedStore {

    // MARK: - State (in-memory; aspirations + history live in SwiftData/CloudKit)

    var needs: [NeedType: Double] = [:]
    /// Timestamp of the last *user* mutation per need (action / undo / toggle).
    /// Drives last-write-wins conflict resolution on pull. NEVER bumped by decay.
    var lastUpdated: [NeedType: Date] = [:]
    /// Internal: when the decay loop last subtracted from each need.
    /// Local-only, never synced.
    private var lastDecayTick: [NeedType: Date] = [:]
    /// Default for fresh installs. Real values come from `ensureAnchors()`
    /// which reads each `NeedAnchor.enabled` flag from SwiftData/CloudKit.
    var enabledNeeds: Set<NeedType> = NeedPlan.essential.needs
    var aspirations: [Aspiration] = []
    var tasks: [LifeTask] = []
    private var recentActionsCache: [NeedType: [LastActionRecord]] = [:]
    private var recentActionKeys: Set<String> = []
    private var alertsCache: (hour: Int, hash: Int, alerts: [SimAlert])?

    static let recentActionsLimit = 3

    /// Lightweight read-model for views (derived from ActivityLog).
    struct LastActionRecord: Equatable, Hashable {
        /// Canonical (Spanish) name as stored in the log — kept stable across languages.
        let actionName: String
        let icon: String
        let boost: Double
        let at: Date

        /// Display string in the user's current locale. Falls back to
        /// `actionName` for custom user-typed actions not in the catalog.
        var localizedName: String {
            Bundle.main.localizedString(forKey: actionName, value: actionName, table: nil)
        }
    }

    let calibration = CalibrationEngine()

    private var modelContext: ModelContext?
    private var decayTimer: Timer?
    private var remoteChangeObserver: NSObjectProtocol?

    // MARK: - Lifecycle

    init() {
        for need in NeedType.allCases {
            needs[need] = need.decaysAutomatically ? 0.5 : 1.0  // health starts full
        }
        // Real values land in `ensureAnchors()` once `configure(with:)` runs
        // — these defaults just stop the dashboard from rendering empty in
        // the brief window before the first context fetch.
    }

    var sortedEnabledNeeds: [NeedType] {
        NeedType.sorted.filter { enabledNeeds.contains($0) }
    }

    func setEnabled(_ enabled: Bool, for need: NeedType) {
        if enabled { enabledNeeds.insert(need) }
        else       { enabledNeeds.remove(need) }
        upsertAnchor(for: need, enabled: enabled, bumpTimestamp: false)
        lastUpdated[need] = Date()
    }

    /// Applies a preset plan from the onboarding's category step.
    func applyPlan(_ plan: NeedPlan) {
        let target = plan.needs
        guard target != enabledNeeds else { return }
        let now = Date()
        let changed = NeedType.allCases.filter { target.contains($0) != enabledNeeds.contains($0) }
        guard !changed.isEmpty else { return }
        enabledNeeds = target
        for need in changed {
            lastUpdated[need] = now
            upsertAnchor(for: need, enabled: target.contains(need), bumpTimestamp: false)
        }
    }

    func configure(with context: ModelContext) {
        modelContext = context
        // Screenshot harness — only runs when `-MockData YES` was passed
        // at launch (Tools/screenshots.sh). No-op in normal use.
        MockData.inject(into: context)
        ensureAnchors()
        refreshAspirations()
        refreshTasks()
        refreshRecentActionsCache()
        startDecayTimer()
        recalibrate()
        startRemoteChangeListener()
    }

    /// Listens for SwiftData/CloudKit-driven remote changes (another device
    /// pushed a write). Re-reads anchors + aspirations + tasks so the UI
    /// reflects the change without waiting for the next foreground.
    /// Coalesced with a 0.5 s debounce since CloudKit can fire bursts.
    private func startRemoteChangeListener() {
        guard remoteChangeObserver == nil else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRemoteChangeReload()
        }
    }

    private var remoteReloadDebounce: DispatchWorkItem?

    private func scheduleRemoteChangeReload() {
        remoteReloadDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.ensureAnchors()
            self.refreshAspirations()
            self.refreshTasks()
            self.refreshRecentActionsCache()
        }
        remoteReloadDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func onBecomeActive() {
        ensureAnchors()
        refreshAspirations()
        refreshTasks()
        refreshRecentActionsCache()
        startDecayTimer()
        recalibrate()
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    func onEnterBackground() {
        decayTimer?.invalidate()
        decayTimer = nil
    }

    // MARK: - Actions

    func logAction(_ action: QuickAction, for need: NeedType) {
        let current = needs[need] ?? 0
        let delta = action.boost / 100.0
        let newValue = max(0.0, min(1.0, current + delta))
        needs[need] = newValue
        let now = Date()
        lastUpdated[need] = now
        lastDecayTick[need] = now

        if let context = modelContext {
            let log = ActivityLog(
                needType: need,
                actionName: action.name,
                actionIcon: action.icon,
                boostAmount: action.boost
            )
            context.insert(log)
            try? context.save()
            refreshRecentActionsCache(for: need)

            let count = (try? context.fetchCount(FetchDescriptor<ActivityLog>())) ?? 0
            if count % 10 == 0 { recalibrate() }
        }

        // Persist the new bar value as the synced anchor → CloudKit pushes
        // to the user's other devices.
        upsertAnchor(for: need, value: newValue, bumpTimestamp: true)
        triggerHaptic(negative: action.isNegative)
    }

    /// Undo the Nth most recent log for this need: subtracts boost and deletes the SwiftData row.
    func removeRecentAction(for need: NeedType, at index: Int) {
        guard let context = modelContext else { return }
        let needRaw = need.rawValue
        let descriptor = FetchDescriptor<ActivityLog>(
            predicate: #Predicate { $0.needType == needRaw },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        guard let logs = try? context.fetch(descriptor),
              logs.indices.contains(index) else { return }
        let removed = logs[index]
        let current = needs[need] ?? 0
        let delta = removed.boostAmount / 100.0
        let newValue = max(0.0, min(1.0, current - delta))
        let now = Date()
        needs[need] = newValue
        lastUpdated[need] = now
        lastDecayTick[need] = now

        context.delete(removed)
        try? context.save()
        refreshRecentActionsCache(for: need)
        upsertAnchor(for: need, value: newValue, bumpTimestamp: true)
    }

    func setValue(_ value: Double, for need: NeedType) {
        let clamped = max(0, min(1, value))
        needs[need] = clamped
        let now = Date()
        lastUpdated[need] = now
        lastDecayTick[need] = now
        upsertAnchor(for: need, value: clamped, bumpTimestamp: true)
    }

    /// "Estoy estable": parks every enabled need at 0.5.
    func resetAllToBaseline(_ value: Double = 0.5) {
        let clamped = max(0, min(1, value))
        let now = Date()
        for need in enabledNeeds {
            needs[need] = clamped
            lastUpdated[need] = now
            lastDecayTick[need] = now
            upsertAnchor(for: need, value: clamped, bumpTimestamp: true)
        }
        alertsCache = nil
    }

    /// Wipes all SwiftData rows + UserDefaults caches + pending notifications.
    /// SwiftData propagates the deletions through CloudKit, so other devices
    /// see them on their next foreground. `userName` and prefs survive.
    func resetEverything() async {
        guard let context = modelContext else { return }

        await NotificationManager.shared.cancelAllTaskReminders()
        await NotificationManager.shared.cancelAllTreatmentReminders()

        let treatments = (try? context.fetch(FetchDescriptor<Treatment>())) ?? []
        let allLogs = (try? context.fetch(FetchDescriptor<ActivityLog>())) ?? []
        let allAnchors = (try? context.fetch(FetchDescriptor<NeedAnchor>())) ?? []
        for asp in aspirations { context.delete(asp) }
        for task in tasks { context.delete(task) }
        for log in allLogs { context.delete(log) }
        for t in treatments { context.delete(t) }
        for anchor in allAnchors { context.delete(anchor) }
        try? context.save()

        aspirations.removeAll()
        tasks.removeAll()
        recentActionsCache.removeAll()
        recentActionKeys.removeAll()
        alertsCache = nil

        for need in NeedType.allCases {
            UserDefaults.standard.removeObject(forKey: "notif.lastFired.\(need.rawValue)")
        }

        // Recreate fresh anchors with Esencial defaults — also re-syncs to
        // any other device the user has signed into iCloud.
        ensureAnchors()
        refreshAspirations()
        refreshTasks()
    }

    // MARK: - Recent actions (cached; refreshed on log/undo)

    /// Most recent N actions for a given need. O(1) read from cache — no SwiftData fetch per call.
    func recentActions(for need: NeedType) -> [LastActionRecord] {
        recentActionsCache[need] ?? []
    }

    private func refreshRecentActionsCache(for need: NeedType? = nil) {
        guard let context = modelContext else { return }
        let needsToRefresh: [NeedType] = need.map { [$0] } ?? NeedType.allCases
        for n in needsToRefresh {
            let needRaw = n.rawValue
            var descriptor = FetchDescriptor<ActivityLog>(
                predicate: #Predicate { $0.needType == needRaw },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = Self.recentActionsLimit
            let logs = (try? context.fetch(descriptor)) ?? []
            recentActionsCache[n] = logs.map {
                LastActionRecord(
                    actionName: $0.actionName,
                    icon: $0.actionIcon,
                    boost: $0.boostAmount,
                    at: $0.timestamp
                )
            }
        }
        rebuildRecentActionKeys()
    }

    private func rebuildRecentActionKeys() {
        var set = Set<String>()
        for (need, records) in recentActionsCache {
            for rec in records {
                set.insert("\(need.rawValue):\(rec.actionName)")
            }
        }
        recentActionKeys = set
    }

    // MARK: - Calibration

    private static let recalibrationWindow = 1000

    private func recalibrate() {
        guard let context = modelContext else { return }
        var descriptor = FetchDescriptor<ActivityLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = Self.recalibrationWindow
        guard let logs = try? context.fetch(descriptor) else { return }
        calibration.calibrate(from: logs)
    }

    // MARK: - Computed

    var overallMood: Double {
        guard !needs.isEmpty else { return 0.5 }
        var totalWeight = 0.0
        var weightedSum = 0.0
        for (need, value) in needs where enabledNeeds.contains(need) {
            weightedSum += value * need.moodWeight
            totalWeight += need.moodWeight
        }
        return totalWeight > 0 ? weightedSum / totalWeight : 0.5
    }

    /// VITAL score 0–100 — mood mapped 1:1 to the centred pip bar (so all
    /// needs at 50 % reads as a *neutral* VITAL of 50, not "1 pip into the
    /// red") plus a small aspirations bonus that can lift the bar above
    /// the centre. Clamped at 100 so excellent days don't overflow.
    ///
    /// Old formula was `mood * 90 + bonus(max 10)` — that capped neutral
    /// mood at 45, which the VITAL bar (centre = 50) always rendered as
    /// "slightly negative". Visible bug at app launch with default state.
    var vitalScore: Int {
        let base = overallMood * 100.0
        let donesToday = aspirations.filter { $0.isDoneNow() }.count
        let bonus = min(10.0, Double(donesToday) * 3.0)
        return Int(min(100.0, base + bonus).rounded())
    }

    var vitalLabel: String { SimsTheme.vitalLabel(for: vitalScore) }

    var mostUrgentNeed: NeedType? {
        needs.min { $0.value < $1.value }?.key
    }

    var criticalNeeds: [NeedType] {
        needs.filter { enabledNeeds.contains($0.key) && $0.value < 0.30 }
            .sorted { $0.value < $1.value }
            .map(\.key)
    }

    // MARK: - Alerts

    struct SimAlert: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let icon: String
        let severity: Severity

        enum Severity: Equatable {
            case positive, nudge, warning, urgent
        }

        static func == (lhs: SimAlert, rhs: SimAlert) -> Bool {
            lhs.message == rhs.message
        }
    }

    /// Single rule for `activeAlerts`. The closure receives need values via a
    /// `(NeedType) -> Double` accessor and the current hour/weekday — returns
    /// a `SimAlert` if the rule fires, `nil` otherwise. Living as data lets
    /// `activeAlerts` be a `compactMap` instead of a 90-line if-chain.
    private struct AlertRule {
        let evaluate: (_ v: (NeedType) -> Double, _ hour: Int, _ weekday: Int) -> SimAlert?
    }

    private static let alertRules: [AlertRule] = [
        // "All above 60%" — positive moodlet when the user is sailing.
        AlertRule { v, _, _ in
            guard NeedType.allCases.allSatisfy({ v($0) >= 0.60 }) else { return nil }
            return SimAlert(message: String(localized: "¡Todo por encima del 60%! Gran momento"),
                            icon: "star.fill", severity: .positive)
        },
        // Late-night sleep nudge (urgent).
        AlertRule { _, hour, _ in
            guard hour >= 23 || hour < 5 else { return nil }
            return SimAlert(message: String(localized: "Es tarde — hora de dormir"),
                            icon: "moon.zzz.fill", severity: .urgent)
        },
        // Pre-bed energy collapse (only if not already in late-night urgent window).
        AlertRule { v, hour, _ in
            guard hour >= 22, hour < 23, v(.energy) < 0.20 else { return nil }
            return SimAlert(message: String(localized: "Tu energía está agotada — ve a descansar"),
                            icon: "battery.0percent", severity: .warning)
        },
        // Meal-time prompts.
        AlertRule { v, hour, _ in
            guard (7...9).contains(hour), v(.nutrition) < 0.30 else { return nil }
            return SimAlert(message: String(localized: "Desayuna — tu cuerpo necesita combustible"),
                            icon: "cup.and.saucer.fill", severity: .nudge)
        },
        AlertRule { v, hour, _ in
            guard (12...14).contains(hour), v(.nutrition) < 0.25 else { return nil }
            return SimAlert(message: String(localized: "Hora de comer — no saltes el almuerzo"),
                            icon: "fork.knife", severity: .warning)
        },
        AlertRule { v, hour, _ in
            guard (19...21).contains(hour), v(.nutrition) < 0.30 else { return nil }
            return SimAlert(message: String(localized: "¿Has cenado? Tu nutrición está baja"),
                            icon: "fork.knife", severity: .nudge)
        },
        // Hydration — urgent below 15% any hour, nudge below 30% during day.
        AlertRule { v, _, _ in
            guard v(.hydration) < 0.15 else { return nil }
            return SimAlert(message: String(localized: "Bebe agua — llevas demasiado sin hidratarte"),
                            icon: "drop.fill", severity: .urgent)
        },
        AlertRule { v, hour, _ in
            guard v(.hydration) >= 0.15, v(.hydration) < 0.30, (10...20).contains(hour) else { return nil }
            return SimAlert(message: String(localized: "Un vaso de agua te vendría bien"),
                            icon: "drop.fill", severity: .nudge)
        },
        AlertRule { v, hour, _ in
            guard v(.exercise) < 0.15, (10...20).contains(hour) else { return nil }
            return SimAlert(message: String(localized: "Llevas mucho sin moverte — aunque sea un paseo"),
                            icon: "figure.walk", severity: .warning)
        },
        AlertRule { v, _, _ in
            guard v(.social) < 0.15 else { return nil }
            return SimAlert(message: String(localized: "Habla con alguien — tu social está muy bajo"),
                            icon: "person.2.fill", severity: .warning)
        },
        AlertRule { v, _, _ in
            guard v(.environment) < 0.20 else { return nil }
            return SimAlert(message: String(localized: "Tu entorno necesita atención — ordena un poco"),
                            icon: "sparkles", severity: .nudge)
        },
        AlertRule { v, hour, _ in
            guard v(.leisure) < 0.15, hour >= 18 else { return nil }
            return SimAlert(message: String(localized: "Date un respiro — haz algo que disfrutes"),
                            icon: "gamecontroller.fill", severity: .nudge)
        },
        AlertRule { v, hour, _ in
            guard v(.hygiene) < 0.20, (8...22).contains(hour) else { return nil }
            return SimAlert(message: String(localized: "¿Te duchaste hoy? Tu higiene está baja"),
                            icon: "shower.fill", severity: .nudge)
        },
        AlertRule { v, hour, _ in
            guard (6...8).contains(hour), v(.energy) < 0.15 else { return nil }
            return SimAlert(message: String(localized: "Buenos días — registra cómo dormiste"),
                            icon: "sunrise.fill", severity: .nudge)
        },
        // 3+ barras críticas — composite alert.
        AlertRule { v, _, _ in
            let count = NeedType.allCases.filter { v($0) < 0.15 }.count
            guard count >= 3 else { return nil }
            return SimAlert(message: String(localized: "\(count) barras en rojo — cuídate, prioriza lo básico"),
                            icon: "exclamationmark.triangle.fill", severity: .urgent)
        },
        // Weekend social nudge (Sat/Sun).
        AlertRule { v, hour, weekday in
            let isWeekend = weekday == 1 || weekday == 7
            guard isWeekend, v(.social) < 0.40, (10...20).contains(hour) else { return nil }
            return SimAlert(message: String(localized: "Es fin de semana — buen momento para socializar"),
                            icon: "person.3.fill", severity: .nudge)
        }
    ]

    var activeAlerts: [SimAlert] {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // Re-use the previous result while neither the hour nor the rounded
        // need values have changed — alerts are stable second-to-second.
        let stateHash = needsStateHash()
        if let cached = alertsCache, cached.hour == hour, cached.hash == stateHash {
            return cached.alerts
        }

        let v: (NeedType) -> Double = { self.needs[$0] ?? 0.5 }
        let result = Array(Self.alertRules.compactMap { $0.evaluate(v, hour, weekday) }.prefix(3))
        alertsCache = (hour: hour, hash: stateHash, alerts: result)
        return result
    }

    /// Cheap hash that only changes when an alert-relevant value tier flips
    /// (we round to the closest 5% so tiny decay ticks don't bust the cache).
    private func needsStateHash() -> Int {
        var hasher = Hasher()
        for need in NeedType.allCases {
            hasher.combine(need.rawValue)
            hasher.combine(Int(((needs[need] ?? 0) * 20).rounded()))
        }
        return hasher.finalize()
    }

    /// Below this, a need is "low" and earns top-up suggestions.
    private static let lowNeedThreshold = 0.65
    /// At/above this, a need is "satisfied" — skip its actions to avoid noise.
    private static let highNeedThreshold = 0.85
    private static let topUpPerNeed = 2

    var smartSuggestions: [QuickAction] {
        let hour = Calendar.current.component(.hour, from: Date())
        var candidates: [QuickAction] = []

        switch hour {
        case 6...9:
            candidates += makeActions(.energy, filter: { $0.contains("Dormí") }, limit: 1)
            candidates += makeActions(.nutrition, filter: { $0 == "Desayuno" })
            candidates += makeActions(.hydration, filter: { $0 == "Café" || $0 == "Agua" })
        case 10...13:
            candidates += makeActions(.hydration, filter: { $0 == "Agua" })
            candidates += makeActions(.nutrition, filter: { $0 == "Almuerzo" })
            candidates += makeActions(.environment, limit: 1)
        case 14...17:
            candidates += makeActions(.hydration, filter: { $0 == "Agua" })
            candidates += makeActions(.exercise, limit: 1)
        case 18...21:
            candidates += makeActions(.nutrition, filter: { $0 == "Cena" })
            candidates += makeActions(.leisure, limit: 1)
            candidates += makeActions(.social, limit: 1)
        default:
            candidates += makeActions(.hygiene, filter: { $0 == "Ducha" || $0 == "Lavé dientes" })
            candidates += makeActions(.leisure, filter: { $0 == "Medité" || $0 == "Leí" })
        }

        for need in criticalNeeds.prefix(2) {
            if let top = need.positiveActions.first {
                candidates.insert(withNeed(top, need), at: 0)
            }
        }

        // Backfill from low needs so the chip row never looks empty after filtering.
        for need in NeedType.sorted where (needs[need] ?? 0) < Self.lowNeedThreshold {
            candidates += makeActions(need, limit: Self.topUpPerNeed)
        }

        let filtered = candidates
            .filter { enabledNeeds.contains($0.needType)
                      && !recentActionKeys.contains("\($0.needType.rawValue):\($0.name)")
                      && (needs[$0.needType] ?? 0) < Self.highNeedThreshold }
            .deduplicated()
        return Array(filtered.prefix(5))
    }

    private func makeActions(_ need: NeedType, filter: ((String) -> Bool)? = nil, limit: Int = 5) -> [QuickAction] {
        let actions = need.positiveActions
        let filtered = filter != nil ? actions.filter { filter!($0.name) } : Array(actions.prefix(limit))
        return filtered.map { withNeed($0, need) }
    }

    private func withNeed(_ action: QuickAction, _ need: NeedType) -> QuickAction {
        var a = action
        a.needType = need
        return a
    }

    // MARK: - Aspirations (SwiftData backed)

    private func refreshAspirations() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<Aspiration>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        aspirations = (try? context.fetch(descriptor)) ?? []
    }

    /// Only the aspirations the user can interact with right now (excludes
    /// future-scheduled ones AND legacy `.treatment` records — those now
    /// live in the Botiquín tab as `Treatment`).
    var activeAspirations: [Aspiration] {
        aspirations.filter {
            !$0.isScheduledForFuture() && $0.kind != .treatment
        }
    }

    /// Aspirations whose `startedAt` is in the future — shown separately as
    /// "upcoming". Legacy `.treatment` records are filtered out.
    var upcomingAspirations: [Aspiration] {
        aspirations.filter { $0.isScheduledForFuture() && $0.kind != .treatment }
            .sorted { ($0.startedAt ?? Date.distantFuture) < ($1.startedAt ?? Date.distantFuture) }
    }

    func toggleAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        if aspiration.isDoneNow() {
            aspiration.lastCompletedAt = nil
            if let last = aspiration.completionsLog.last,
               Calendar.current.isDateInToday(last) {
                aspiration.completionsLog.removeLast()
            }
        } else {
            let now = Date()
            aspiration.lastCompletedAt = now
            aspiration.completionsLog.append(now)
        }
        try? context.save()
        refreshAspirations()
        triggerHaptic(negative: false)
    }

    func addAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        aspiration.sortOrder = (aspirations.map(\.sortOrder).max() ?? 0) + 1
        context.insert(aspiration)
        try? context.save()
        refreshAspirations()
    }

    func updateAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        try? context.save()
        refreshAspirations()
    }

    func deleteAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        context.delete(aspiration)
        try? context.save()
        refreshAspirations()
    }

    // MARK: - Tasks (one-off agenda items)

    private func refreshTasks() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<LifeTask>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.createdAt)]
        )
        tasks = (try? context.fetch(descriptor)) ?? []
    }

    func addTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        task.sortOrder = (tasks.map(\.sortOrder).max() ?? 0) + 1
        context.insert(task)
        try? context.save()
        refreshTasks()
        syncTaskReminder(task)
    }

    func updateTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        try? context.save()
        refreshTasks()
        syncTaskReminder(task)
    }

    func deleteTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        let id = task.id
        Task { @MainActor in
            NotificationManager.shared.cancelTaskReminder(taskID: id)
        }
        context.delete(task)
        try? context.save()
        refreshTasks()
    }

    /// Programs or cancels the local reminder for a task based on its
    /// current `notify` + `dueDate` state. Centralised here so every entry
    /// point that mutates a task (editor, MCP server, future shortcuts…)
    /// stays consistent without each caller wiring `NotificationManager`.
    /// `NotificationManager` is `@MainActor`-isolated so we hop onto it.
    private func syncTaskReminder(_ task: LifeTask) {
        let id = task.id
        let title = task.title
        let due = task.dueDate
        let shouldSchedule = task.notify && due != nil && task.hasSpecificTime
        Task { @MainActor in
            if shouldSchedule, let due {
                NotificationManager.shared.scheduleTaskReminder(taskID: id, title: title, at: due)
            } else {
                NotificationManager.shared.cancelTaskReminder(taskID: id)
            }
        }
    }

    func moveTask(withID draggedID: UUID, toBefore targetID: UUID) {
        guard let context = modelContext,
              let from = tasks.firstIndex(where: { $0.id == draggedID }),
              let to = tasks.firstIndex(where: { $0.id == targetID }),
              from != to else { return }
        var reordered = tasks
        let moved = reordered.remove(at: from)
        let insertIndex = to > from ? to - 1 : to
        reordered.insert(moved, at: insertIndex)
        for (i, t) in reordered.enumerated() {
            t.sortOrder = i
        }
        try? context.save()
        refreshTasks()
    }

    func toggleTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        task.isDone.toggle()
        task.completedAt = task.isDone ? Date() : nil
        try? context.save()
        refreshTasks()
        triggerHaptic(negative: false)
    }

    /// Tasks due today or overdue, with not-done first, then ordered by time.
    var visibleTasks: [LifeTask] {
        let cal = Calendar.current
        let now = Date()
        return tasks.filter { task in
            if task.isDone {
                return cal.isDateInToday(task.completedAt ?? task.createdAt)
            }
            guard let due = task.dueDate else { return true }     // no date = inbox
            return cal.isDateInToday(due) || due < now            // today or overdue
        }
    }

    /// Tasks scheduled for a calendar day after today. Surfaced separately
    /// in the agenda's "Próximamente" row so future tasks don't clutter
    /// today's view.
    var upcomingTasks: [LifeTask] {
        let cal = Calendar.current
        let now = Date()
        return tasks.filter { task in
            guard !task.isDone, let due = task.dueDate else { return false }
            return cal.startOfDay(for: due) > cal.startOfDay(for: now)
        }
        .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
    }

    // MARK: - Decay (uses calibrated rates)

    private func startDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyDecay() }
        }
    }

    private func applyDecay() {
        let now = Date()
        for need in NeedType.allCases where need.decaysAutomatically && enabledNeeds.contains(need) {
            guard let current = needs[need] else { continue }
            // Decay accumulates locally on top of the synced anchor — the
            // anchor itself is only bumped when the user takes an action.
            let lastTick = lastDecayTick[need] ?? lastUpdated[need] ?? now
            let hours = now.timeIntervalSince(lastTick) / 3600.0
            guard hours > 0 else { continue }
            let rate = calibration.effectiveDecayRate(for: need)
            let decay = rate * hours / 100.0
            let newValue = max(0.0, current - decay)
            lastDecayTick[need] = now
            if abs(newValue - current) > 0.00001 {
                needs[need] = newValue
                let prev = current
                let next = newValue
                let n = need
                Task { @MainActor in
                    NotificationManager.shared.notifyIfLow(
                        need: n, currentValue: next, previousValue: prev
                    )
                }
            }
        }
    }

    // MARK: - Anchors (CloudKit-synced source of truth)

    /// Loads the cross-device anchors into the in-memory cache. Dedupes
    /// concurrent inserts that may briefly exist while CloudKit reconciles
    /// (keeping the most recent `anchoredAt`). Creates anchors for any need
    /// that doesn't have one yet — happens on first launch and after wipes.
    func ensureAnchors() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<NeedAnchor>()
        let rows = (try? context.fetch(descriptor)) ?? []

        var byNeed: [NeedType: NeedAnchor] = [:]
        for row in rows {
            guard let need = row.needType else {
                context.delete(row); continue
            }
            if let kept = byNeed[need] {
                if row.anchoredAt > kept.anchoredAt {
                    context.delete(kept); byNeed[need] = row
                } else {
                    context.delete(row)
                }
            } else {
                byNeed[need] = row
            }
        }

        // Create rows for missing needs using the in-memory defaults so the
        // dashboard has something to show before the first user action.
        for need in NeedType.allCases where byNeed[need] == nil {
            let anchor = NeedAnchor(
                needType: need,
                value: needs[need] ?? (need.decaysAutomatically ? 0.5 : 1.0),
                enabled: NeedPlan.essential.needs.contains(need),
                anchoredAt: Date()
            )
            context.insert(anchor)
            byNeed[need] = anchor
        }

        try? context.save()

        // Hydrate caches from anchors. Decay applied later by the timer.
        let now = Date()
        for (need, anchor) in byNeed {
            let decay: Double
            if need.decaysAutomatically && anchor.enabled {
                let elapsedHours = max(0, now.timeIntervalSince(anchor.anchoredAt) / 3600.0)
                let rate = calibration.effectiveDecayRate(for: need)
                decay = rate * elapsedHours / 100.0
            } else {
                decay = 0
            }
            needs[need] = max(0.0, min(1.0, anchor.value - decay))
            lastUpdated[need] = anchor.anchoredAt
            lastDecayTick[need] = now
        }
        enabledNeeds = Set(byNeed.compactMap { $0.value.enabled ? $0.key : nil })
        alertsCache = nil
    }

    /// Get-or-create the anchor row for `need`, applying optional updates.
    /// `bumpTimestamp = true` for user actions (the bar value is "now"),
    /// `false` for enable/disable toggles where the value didn't change.
    @discardableResult
    private func upsertAnchor(for need: NeedType,
                              value: Double? = nil,
                              enabled: Bool? = nil,
                              bumpTimestamp: Bool = true) -> NeedAnchor? {
        guard let context = modelContext else { return nil }
        let needRaw = need.rawValue
        let descriptor = FetchDescriptor<NeedAnchor>(predicate: #Predicate { $0.needTypeRaw == needRaw })
        let anchor: NeedAnchor
        if let existing = (try? context.fetch(descriptor))?.first {
            anchor = existing
        } else {
            anchor = NeedAnchor(needType: need)
            context.insert(anchor)
        }
        if let value { anchor.value = value }
        if let enabled { anchor.enabled = enabled }
        if bumpTimestamp { anchor.anchoredAt = Date() }
        try? context.save()
        return anchor
    }

    // MARK: - Haptic

    private func triggerHaptic(negative: Bool = false) {
        #if os(iOS)
        if negative {
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        } else {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
        }
        #endif
    }
}

private extension Array where Element == QuickAction {
    func deduplicated() -> [QuickAction] {
        var seen = Set<String>()
        return filter { seen.insert("\($0.needType.rawValue):\($0.name)").inserted }
    }
}
