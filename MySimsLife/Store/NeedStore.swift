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
    var enabledNeeds: Set<NeedType> = Set(NeedType.allCases)
    var aspirations: [Aspiration] = []
    var tasks: [LifeTask] = []
    private var recentActionsCache: [NeedType: [LastActionRecord]] = [:]
    private var recentActionKeys: Set<String> = []
    private var alertsCache: (hour: Int, hash: Int, alerts: [SimAlert])?

    static let recentActionsLimit = 3

    /// Lightweight read-model for views (derived from ActivityLog).
    struct LastActionRecord: Equatable, Hashable {
        let actionName: String
        let icon: String
        let boost: Double
        let at: Date
    }

    let calibration = CalibrationEngine()

    private var modelContext: ModelContext?
    private var decayTimer: Timer?

    // MARK: - Lifecycle

    init() {
        for need in NeedType.allCases {
            needs[need] = need.decaysAutomatically ? 0.5 : 1.0  // health starts full
            lastUpdated[need] = Date()
        }
        loadEnabledNeeds()
        loadNeedsState()
    }

    var sortedEnabledNeeds: [NeedType] {
        NeedType.sorted.filter { enabledNeeds.contains($0) }
    }

    func setEnabled(_ enabled: Bool, for need: NeedType) {
        if enabled { enabledNeeds.insert(need) }
        else       { enabledNeeds.remove(need) }
        saveEnabledNeeds()
        let now = Date()
        lastUpdated[need] = now
        let value = needs[need] ?? 0
        Task { await BackendSync.shared.pushNeedState(need, value: value, lastUpdated: now, enabled: enabled) }
    }

    // MARK: - Sync helpers

    private func firePush(_ asp: Aspiration) {
        Task { await BackendSync.shared.pushAspiration(asp) }
    }

    private func firePush(_ task: LifeTask) {
        Task { await BackendSync.shared.pushTask(task) }
    }

    private func saveEnabledNeeds() {
        let raw = enabledNeeds.map { $0.rawValue }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: UDKey.enabledNeeds)
        }
    }

    private func loadEnabledNeeds() {
        guard let data = UserDefaults.standard.data(forKey: UDKey.enabledNeeds),
              let raw = try? JSONDecoder().decode([String].self, from: data),
              !raw.isEmpty
        else { return }
        enabledNeeds = Set(raw.compactMap { NeedType(rawValue: $0) })
    }

    func configure(with context: ModelContext) {
        modelContext = context
        refreshAspirations()
        refreshTasks()
        refreshRecentActionsCache()
        startDecayTimer()
        recalibrate()
        Task { @MainActor in
            await pullAndApply(context: context)
            RealtimeSync.shared.onEvent = { [weak self] _ in
                guard let self, let ctx = self.modelContext else { return }
                Task { @MainActor in await self.pullAndApply(context: ctx) }
            }
            RealtimeSync.shared.start(with: context)
        }
    }

    /// Single entry point used both at boot and after every realtime event.
    /// Pulls the backend delta, applies SwiftData rows, then merges the
    /// in-memory needs state and refreshes derived caches.
    @MainActor
    private func pullAndApply(context: ModelContext) async {
        let result = await BackendSync.shared.pull(into: context)
        applyRemoteNeeds(result.needsState)
        refreshAspirations()
        refreshTasks()
        refreshRecentActionsCache()
    }

    @MainActor
    private func applyRemoteNeeds(_ remotes: [BackendSync.RemoteNeedState]) {
        guard !remotes.isEmpty else { return }
        var changed = false
        for remote in remotes {
            guard let need = NeedType(rawValue: remote.needType) else { continue }
            let remoteUpdated = Date(timeIntervalSince1970: TimeInterval(remote.lastUpdatedMs) / 1000)
            // Only overwrite if the server's value is newer than what we have.
            if let local = lastUpdated[need], local >= remoteUpdated { continue }
            needs[need] = max(0, min(1, remote.value))
            lastUpdated[need] = remoteUpdated
            if remote.enabled { enabledNeeds.insert(need) }
            else              { enabledNeeds.remove(need) }
            changed = true
        }
        if changed {
            saveNeedsState()
            saveEnabledNeeds()
            alertsCache = nil   // bust the cache, value tier may have flipped
        }
    }

    func onBecomeActive() {
        loadNeedsState()
        refreshAspirations()
        refreshTasks()
        refreshRecentActionsCache()
        startDecayTimer()
        recalibrate()
        if let context = modelContext {
            // Catch up on anything the backend changed while we were in the
            // background, then re-open the WS for live events.
            Task { @MainActor in
                await pullAndApply(context: context)
                RealtimeSync.shared.start(with: context)
            }
        }
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        #endif
    }

    func onEnterBackground() {
        saveNeedsState()
        decayTimer?.invalidate()
        decayTimer = nil
        Task { @MainActor in RealtimeSync.shared.stop() }
    }

    // MARK: - Actions

    func logAction(_ action: QuickAction, for need: NeedType) {
        let current = needs[need] ?? 0
        let delta = action.boost / 100.0
        needs[need] = max(0.0, min(1.0, current + delta))
        let now = Date()
        lastUpdated[need] = now

        var pushedLog: ActivityLog?
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
            pushedLog = log

            let count = (try? context.fetchCount(FetchDescriptor<ActivityLog>())) ?? 0
            if count % 10 == 0 { recalibrate() }
        }

        saveNeedsState()
        triggerHaptic(negative: action.isNegative)

        let value = needs[need] ?? 0
        let needLastUpdated = lastUpdated[need] ?? now
        let enabled = enabledNeeds.contains(need)
        Task {
            if let log = pushedLog { await BackendSync.shared.pushActivityLog(log) }
            await BackendSync.shared.pushNeedState(need, value: value, lastUpdated: needLastUpdated, enabled: enabled)
        }
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
        let now = Date()
        needs[need] = max(0.0, min(1.0, current - delta))
        // Bump the timestamp so other devices accept the lower value over their cached one.
        lastUpdated[need] = now

        let removedID = removed.id
        context.delete(removed)
        try? context.save()
        refreshRecentActionsCache(for: need)
        saveNeedsState()
        let value = needs[need] ?? 0
        let enabled = enabledNeeds.contains(need)
        Task {
            await BackendSync.shared.deleteActivityLog(id: removedID)
            await BackendSync.shared.pushNeedState(need, value: value, lastUpdated: now, enabled: enabled)
        }
    }

    func setValue(_ value: Double, for need: NeedType) {
        needs[need] = max(0, min(1, value))
        lastUpdated[need] = Date()
        saveNeedsState()
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

    /// VITAL score 0–100 — overall mood + aspiration bonus (max +10)
    var vitalScore: Int {
        let base = overallMood * 90.0
        let donesToday = aspirations.filter { $0.isDoneNow() }.count
        let bonus = min(10.0, Double(donesToday) * 3.0)
        return Int((base + bonus).rounded())
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

    var activeAlerts: [SimAlert] {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // Re-use the previous result while neither the hour nor the rounded
        // need values have changed — alerts are stable second-to-second.
        let stateHash = needsStateHash()
        if let cached = alertsCache, cached.hour == hour, cached.hash == stateHash {
            return cached.alerts
        }

        var alerts: [SimAlert] = []

        let v = { (n: NeedType) -> Double in self.needs[n] ?? 0.5 }

        let allAbove60 = NeedType.allCases.allSatisfy { v($0) >= 0.60 }
        if allAbove60 {
            alerts.append(SimAlert(message: "¡Todo por encima del 60%! Gran momento",
                                   icon: "star.fill", severity: .positive))
        }

        if hour >= 23 || hour < 5 {
            alerts.append(SimAlert(message: "Es tarde — hora de dormir",
                                   icon: "moon.zzz.fill", severity: .urgent))
        } else if hour >= 22 && v(.energy) < 0.20 {
            alerts.append(SimAlert(message: "Tu energía está agotada — ve a descansar",
                                   icon: "battery.0percent", severity: .warning))
        }

        if hour >= 7 && hour <= 9 && v(.nutrition) < 0.30 {
            alerts.append(SimAlert(message: "Desayuna — tu cuerpo necesita combustible",
                                   icon: "cup.and.saucer.fill", severity: .nudge))
        }
        if hour >= 12 && hour <= 14 && v(.nutrition) < 0.25 {
            alerts.append(SimAlert(message: "Hora de comer — no saltes el almuerzo",
                                   icon: "fork.knife", severity: .warning))
        }
        if hour >= 19 && hour <= 21 && v(.nutrition) < 0.30 {
            alerts.append(SimAlert(message: "¿Has cenado? Tu nutrición está baja",
                                   icon: "fork.knife", severity: .nudge))
        }

        if v(.hydration) < 0.15 {
            alerts.append(SimAlert(message: "Bebe agua — llevas demasiado sin hidratarte",
                                   icon: "drop.fill", severity: .urgent))
        } else if v(.hydration) < 0.30 && hour >= 10 && hour <= 20 {
            alerts.append(SimAlert(message: "Un vaso de agua te vendría bien",
                                   icon: "drop.fill", severity: .nudge))
        }

        if v(.exercise) < 0.15 && hour >= 10 && hour <= 20 {
            alerts.append(SimAlert(message: "Llevas mucho sin moverte — aunque sea un paseo",
                                   icon: "figure.walk", severity: .warning))
        }

        if v(.social) < 0.15 {
            alerts.append(SimAlert(message: "Habla con alguien — tu social está muy bajo",
                                   icon: "person.2.fill", severity: .warning))
        }

        if v(.environment) < 0.20 {
            alerts.append(SimAlert(message: "Tu entorno necesita atención — ordena un poco",
                                   icon: "sparkles", severity: .nudge))
        }

        if v(.leisure) < 0.15 && hour >= 18 {
            alerts.append(SimAlert(message: "Date un respiro — haz algo que disfrutes",
                                   icon: "gamecontroller.fill", severity: .nudge))
        }

        if v(.hygiene) < 0.20 && hour >= 8 && hour <= 22 {
            alerts.append(SimAlert(message: "¿Te duchaste hoy? Tu higiene está baja",
                                   icon: "shower.fill", severity: .nudge))
        }

        if hour >= 6 && hour <= 8 && v(.energy) < 0.15 {
            alerts.append(SimAlert(message: "Buenos días — registra cómo dormiste",
                                   icon: "sunrise.fill", severity: .nudge))
        }

        let critCount = NeedType.allCases.filter { v($0) < 0.15 }.count
        if critCount >= 3 {
            alerts.append(SimAlert(message: "\(critCount) barras en rojo — cuídate, prioriza lo básico",
                                   icon: "exclamationmark.triangle.fill", severity: .urgent))
        }

        let isWeekend = weekday == 1 || weekday == 7
        if isWeekend && v(.social) < 0.40 && hour >= 10 && hour <= 20 {
            alerts.append(SimAlert(message: "Es fin de semana — buen momento para socializar",
                                   icon: "person.3.fill", severity: .nudge))
        }

        let result = Array(alerts.prefix(3))
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

    /// Only the aspirations the user can interact with right now (excludes future-scheduled ones).
    var activeAspirations: [Aspiration] {
        aspirations.filter { !$0.isScheduledForFuture() }
    }

    /// Aspirations whose `startedAt` is in the future — shown separately as "upcoming".
    var upcomingAspirations: [Aspiration] {
        aspirations.filter { $0.isScheduledForFuture() }
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
        firePush(aspiration)
    }

    func addAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        aspiration.sortOrder = (aspirations.map(\.sortOrder).max() ?? 0) + 1
        context.insert(aspiration)
        try? context.save()
        refreshAspirations()
        firePush(aspiration)
    }

    func updateAspiration(_ aspiration: Aspiration) {
        // Aspiration is a @Model class — caller mutates props directly; we just persist.
        guard let context = modelContext else { return }
        try? context.save()
        refreshAspirations()
        firePush(aspiration)
    }

    func deleteAspiration(_ aspiration: Aspiration) {
        guard let context = modelContext else { return }
        let id = aspiration.id
        context.delete(aspiration)
        try? context.save()
        refreshAspirations()
        Task { await BackendSync.shared.deleteAspiration(id: id) }
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
        firePush(task)
    }

    func updateTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        try? context.save()
        refreshTasks()
        firePush(task)
    }

    func deleteTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        let id = task.id
        context.delete(task)
        try? context.save()
        refreshTasks()
        Task { await BackendSync.shared.deleteTask(id: id) }
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
        // Push every task whose sortOrder changed so the order replicates.
        Task {
            for task in reordered { await BackendSync.shared.pushTask(task) }
        }
    }

    func toggleTask(_ task: LifeTask) {
        guard let context = modelContext else { return }
        task.isDone.toggle()
        task.completedAt = task.isDone ? Date() : nil
        try? context.save()
        refreshTasks()
        triggerHaptic(negative: false)
        firePush(task)
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

    // MARK: - Decay (uses calibrated rates)

    private func startDecayTimer() {
        decayTimer?.invalidate()
        decayTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.applyDecay() }
        }
    }

    private func applyDecay() {
        let now = Date()
        var changed = false
        for need in NeedType.allCases where need.decaysAutomatically && enabledNeeds.contains(need) {
            guard let current = needs[need] else { continue }
            // Decay measures time since the previous decay tick (or last user
            // mutation, whichever is more recent). It does NOT touch
            // `lastUpdated` — that field carries the LWW timestamp for sync.
            let lastTick = lastDecayTick[need] ?? lastUpdated[need] ?? now
            let hours = now.timeIntervalSince(lastTick) / 3600.0
            guard hours > 0 else { continue }
            let rate = calibration.effectiveDecayRate(for: need)
            let decay = rate * hours / 100.0
            let newValue = max(0.0, current - decay)
            lastDecayTick[need] = now
            if abs(newValue - current) > 0.00001 {
                needs[need] = newValue
                changed = true
            }
        }
        if changed { saveNeedsState() }
    }

    // MARK: - Persistence (only the live needs values — small + non-critical)

    private func saveNeedsState() {
        var dict: [String: [String: Double]] = [:]
        for (need, value) in needs {
            dict[need.rawValue] = [
                "value": value,
                "ts": (lastUpdated[need] ?? Date()).timeIntervalSince1970
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: UDKey.needsState)
        }
    }

    private func loadNeedsState() {
        guard let data = UserDefaults.standard.data(forKey: UDKey.needsState),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Double]]
        else { return }

        let now = Date()
        for (key, state) in dict {
            guard let needType = NeedType(rawValue: key),
                  let savedValue = state["value"],
                  let ts = state["ts"]
            else { continue }
            if needType.decaysAutomatically {
                let hours = now.timeIntervalSince(Date(timeIntervalSince1970: ts)) / 3600.0
                let rate = calibration.effectiveDecayRate(for: needType)
                let decay = rate * hours / 100.0
                needs[needType] = max(0.0, savedValue - decay)
            } else {
                needs[needType] = savedValue   // manual-only: keep as saved
            }
            lastUpdated[needType] = now
        }
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
