import Foundation
import SwiftData

// Cloudflare D1 stores ids as TEXT and treats case as significant. Both ends
// must agree on a single canonical case (Swift's `UUID.uuidString` is uppercase
// but `crypto.randomUUID()` on Workers is lowercase) — we standardise on
// lowercase to match the wire format the backend produces.
extension UUID {
    var canonical: String { uuidString.lowercased() }
}

// MARK: - Backend sync client

/// Local-first sync with the Cloudflare Worker backend.
/// Pull on launch + push on every mutation. Last-write-wins by `updated_at`.
actor BackendSync {

    // MARK: Config (read from gitignored BackendCredentials.swift)

    static var baseURL: URL { BackendCredentials.baseURL }
    static var apiKey:  String { BackendCredentials.apiKey }

    static let shared = BackendSync()

    /// Stable per-install identifier so we can ignore broadcasts originated by ourselves.
    /// Stateless codecs — reused across every push/pull so we don't allocate
    /// a fresh encoder on each call.
    nonisolated static let encoder = JSONEncoder()
    nonisolated static let decoder = JSONDecoder()

    nonisolated static let clientID: String = {
        if let existing = UserDefaults.standard.string(forKey: UDKey.backendClientID) { return existing }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: UDKey.backendClientID)
        return new
    }()

    private init() {}

    private var lastSync: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: UDKey.backendLastSyncMs)) }
        set { UserDefaults.standard.set(newValue, forKey: UDKey.backendLastSyncMs) }
    }

    // MARK: Generic request

    private func request(_ path: String, method: String = "GET", body: Encodable? = nil) async throws -> Data {
        var url = Self.baseURL.appendingPathComponent(path)
        if method == "GET", let q = path.split(separator: "?").last, path.contains("?") {
            // path may already include query string; URL append handles it via raw component
            url = URL(string: Self.baseURL.absoluteString + path)!
            _ = q
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(Self.apiKey, forHTTPHeaderField: HTTPHeader.apiKey)
        req.setValue(Self.clientID, forHTTPHeaderField: HTTPHeader.clientID)
        if let body {
            req.httpBody = try Self.encoder.encode(AnyEncodable(body))
        }
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "BackendSync", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "http \(http.statusCode)"])
        }
        return data
    }

    // MARK: Pull

    struct SyncResponse: Decodable {
        let server_time: Int64
        let aspirations: [AspirationDTO]
        let tasks: [TaskDTO]
        let activity_log: [ActivityLogDTO]
        let needs_state: [NeedStateDTO]
    }

    struct PullResult {
        let needsState: [RemoteNeedState]
    }

    struct RemoteNeedState {
        let needType: String
        let value: Double
        let lastUpdatedMs: Int64
        let enabled: Bool
    }

    /// Fetches everything modified since `lastSync` and applies it to the local SwiftData store.
    /// Returns the remote `needs_state` rows so the caller can merge them into `NeedStore.needs`
    /// (those values live in-memory + UserDefaults, not in SwiftData).
    /// `forceFullSync` ignores `lastSync` and asks the server for everything.
    /// Used at boot / foreground so the device gets the full needs_state set
    /// (not just rows changed since last pull) — needed for cross-device
    /// convergence when a need hasn't been touched in a while.
    @discardableResult
    func pull(into context: ModelContext, forceFullSync: Bool = false) async -> PullResult {
        let empty = PullResult(needsState: [])
        do {
            let since = forceFullSync ? 0 : lastSync
            let data = try await request("/sync?since=\(since)")
            let decoded: SyncResponse
            do {
                decoded = try Self.decoder.decode(SyncResponse.self, from: data)
            } catch let DecodingError.dataCorrupted(ctx) {
                print("[BackendSync] decode dataCorrupted: \(ctx)"); return empty
            } catch let DecodingError.keyNotFound(key, ctx) {
                print("[BackendSync] decode keyNotFound: \(key.stringValue) — \(ctx.codingPath.map(\.stringValue))"); return empty
            } catch let DecodingError.typeMismatch(type, ctx) {
                print("[BackendSync] decode typeMismatch: \(type) at \(ctx.codingPath.map(\.stringValue)) — \(ctx.debugDescription)"); return empty
            } catch let DecodingError.valueNotFound(type, ctx) {
                print("[BackendSync] decode valueNotFound: \(type) at \(ctx.codingPath.map(\.stringValue)) — \(ctx.debugDescription)"); return empty
            } catch {
                print("[BackendSync] decode other: \(error)"); return empty
            }
            await MainActor.run {
                applyAspirations(decoded.aspirations, context: context)
                applyTasks(decoded.tasks, context: context)
                applyActivityLog(decoded.activity_log, context: context)
                try? context.save()
            }
            lastSync = decoded.server_time
            return PullResult(needsState: decoded.needs_state.compactMap {
                guard let type = $0.need_type else { return nil }
                return RemoteNeedState(
                    needType: type,
                    value: $0.value,
                    lastUpdatedMs: $0.last_updated,
                    enabled: $0.enabled != 0
                )
            })
        } catch {
            print("[BackendSync] pull failed: \(error.localizedDescription)")
            return empty
        }
    }

    @MainActor
    private func applyAspirations(_ remotes: [AspirationDTO], context: ModelContext) {
        let descriptor = FetchDescriptor<Aspiration>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = dedupeKeepingFirst(locals, key: { $0.id.canonical }) { context.delete($0) }
        guard !remotes.isEmpty else { return }
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id) else { continue }
            if let existing = byId[remote.id.lowercased()] {
                if remote.deleted_at != nil {
                    context.delete(existing)
                } else {
                    apply(remote, to: existing)
                }
            } else if remote.deleted_at == nil {
                let new = Aspiration(name: remote.name)
                new.id = uuid
                apply(remote, to: new)
                context.insert(new)
            }
        }
    }

    /// Build an id→model lookup that survives duplicate ids (which can happen
    /// after a fresh install + interrupted pull). Extras get soft-removed via
    /// the `dropDuplicate` callback so the next sync stops echoing them.
    @MainActor
    private func dedupeKeepingFirst<M, K: Hashable>(
        _ items: [M],
        key: (M) -> K,
        dropDuplicate: (M) -> Void
    ) -> [K: M] {
        var result: [K: M] = [:]
        for item in items {
            let k = key(item)
            if result[k] == nil {
                result[k] = item
            } else {
                dropDuplicate(item)
            }
        }
        return result
    }

    @MainActor
    private func apply(_ dto: AspirationDTO, to model: Aspiration) {
        // Each setter on a SwiftData @Model dirties the row and fires
        // @Observable notifications, which forces SwiftUI to re-render every
        // card. Realtime pulls run on every server event; without these
        // change-detection guards the dashboard rebuilds the full list on
        // every echo even when nothing actually changed.
        let startedAt = dto.started_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let lastCompletedAt = dto.last_completed_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let reminderTime = dto.reminder_time.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let defaultDose = dto.default_dose ?? 1
        if model.name != dto.name { model.name = dto.name }
        if model.emoji != dto.emoji { model.emoji = dto.emoji }
        if model.kindRaw != dto.kind { model.kindRaw = dto.kind }
        if model.hue != dto.hue { model.hue = dto.hue }
        if model.xp != dto.xp { model.xp = dto.xp }
        if model.durationMinutes != dto.duration_minutes { model.durationMinutes = dto.duration_minutes }
        if model.totalDays != dto.total_days { model.totalDays = dto.total_days }
        if model.startedAt != startedAt { model.startedAt = startedAt }
        if model.lastCompletedAt != lastCompletedAt { model.lastCompletedAt = lastCompletedAt }
        if let raw = dto.completions_log,
           let dates = try? Self.decoder.decode([Int64].self, from: Data(raw.utf8)) {
            let parsed = dates.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
            if model.completionsLog != parsed { model.completionsLog = parsed }
        }
        if model.notes != dto.notes { model.notes = dto.notes }
        if model.dosingMomentRaw != dto.dosing_moment { model.dosingMomentRaw = dto.dosing_moment }
        if model.reminderTime != reminderTime { model.reminderTime = reminderTime }
        if model.unit != dto.unit { model.unit = dto.unit }
        if model.defaultDose != defaultDose { model.defaultDose = defaultDose }
        if model.scheduleRaw != dto.schedule_raw { model.scheduleRaw = dto.schedule_raw }
        if model.sortOrder != dto.sort_order { model.sortOrder = dto.sort_order }
    }

    @MainActor
    private func applyTasks(_ remotes: [TaskDTO], context: ModelContext) {
        let descriptor = FetchDescriptor<LifeTask>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = dedupeKeepingFirst(locals, key: { $0.id.canonical }) { context.delete($0) }
        guard !remotes.isEmpty else { return }
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id) else { continue }
            if let existing = byId[remote.id.lowercased()] {
                if remote.deleted_at != nil {
                    context.delete(existing)
                } else {
                    apply(remote, to: existing)
                }
            } else if remote.deleted_at == nil {
                let new = LifeTask(title: remote.title)
                new.id = uuid
                apply(remote, to: new)
                context.insert(new)
            }
        }
    }

    @MainActor
    private func apply(_ dto: TaskDTO, to model: LifeTask) {
        let dueDate = dto.due_date.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let completedAt = dto.completed_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        let isDone = dto.is_done == 1
        if model.title != dto.title { model.title = dto.title }
        if model.notes != dto.notes { model.notes = dto.notes }
        if model.dueDate != dueDate { model.dueDate = dueDate }
        if model.isDone != isDone { model.isDone = isDone }
        if model.completedAt != completedAt { model.completedAt = completedAt }
        if model.sortOrder != dto.sort_order { model.sortOrder = dto.sort_order }
    }

    @MainActor
    private func applyActivityLog(_ remotes: [ActivityLogDTO], context: ModelContext) {
        guard !remotes.isEmpty else { return }
        let descriptor = FetchDescriptor<ActivityLog>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = dedupeKeepingFirst(locals, key: { $0.id.canonical }) { context.delete($0) }
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id),
                  let need = NeedType(rawValue: remote.need_type) else { continue }
            if remote.deleted_at != nil {
                if let existing = byId[remote.id.lowercased()] { context.delete(existing) }
                continue
            }
            if byId[remote.id.lowercased()] != nil { continue }   // already have it
            let log = ActivityLog(needType: need,
                                  actionName: remote.action_name,
                                  actionIcon: remote.action_icon,
                                  boostAmount: remote.boost_amount)
            log.id = uuid
            log.timestamp = Date(timeIntervalSince1970: TimeInterval(remote.timestamp) / 1000)
            log.notes = remote.notes
            context.insert(log)
        }
    }

    // MARK: Push (fire-and-forget)

    func pushAspiration(_ asp: Aspiration) async {
        let dto = AspirationDTO.from(asp)
        do { _ = try await request("/aspirations", method: "POST", body: dto) } catch {
            // If the row already exists upstream, fall back to PATCH.
            _ = try? await request("/aspirations/\(asp.id.canonical)", method: "PATCH", body: dto)
        }
    }

    func deleteAspiration(id: UUID) async {
        _ = try? await request("/aspirations/\(id.canonical)", method: "DELETE")
    }

    func pushTask(_ task: LifeTask) async {
        let dto = TaskDTO.from(task)
        do { _ = try await request("/tasks", method: "POST", body: dto) } catch {
            _ = try? await request("/tasks/\(task.id.canonical)", method: "PATCH", body: dto)
        }
    }

    func deleteTask(id: UUID) async {
        _ = try? await request("/tasks/\(id.canonical)", method: "DELETE")
    }

    func pushActivityLog(_ log: ActivityLog) async {
        let dto = ActivityLogDTO.from(log)
        _ = try? await request("/activity-log", method: "POST", body: dto)
    }

    func deleteActivityLog(id: UUID) async {
        _ = try? await request("/activity-log/\(id.canonical)", method: "DELETE")
    }

    func pushNeedState(_ need: NeedType, value: Double, lastUpdated: Date, enabled: Bool) async {
        let body = NeedStateDTO(need_type: nil,
                                value: value,
                                last_updated: Int64(lastUpdated.timeIntervalSince1970 * 1000),
                                enabled: enabled ? 1 : 0)
        _ = try? await request("/needs-state/\(need.rawValue)", method: "PUT", body: body)
    }
}

// MARK: - DTOs

/// Encodes Optionals as JSON `null` instead of omitting them. We need this
/// for PATCH requests so that clearing a field (e.g. unchecking an aspiration
/// → `last_completed_at = nil`) actually reaches the backend; the synthesized
/// Codable conformance uses `encodeIfPresent` and silently drops nils.
extension KeyedEncodingContainer {
    mutating func encodeOrNull<T: Encodable>(_ value: T?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

struct AspirationDTO: Codable {
    let id: String
    let name: String
    let emoji: String
    let kind: String
    let hue: Double
    let xp: Int
    let duration_minutes: Int?
    let total_days: Int?
    let started_at: Int64?
    let last_completed_at: Int64?
    let completions_log: String?
    let notes: String?
    let dosing_moment: String?
    let reminder_time: Int64?
    let unit: String?
    let default_dose: Int?
    let schedule_raw: String?
    let sort_order: Int
    let updated_at: Int64?
    let deleted_at: Int64?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, kind, hue, xp
        case duration_minutes, total_days, started_at, last_completed_at
        case completions_log, notes, dosing_moment, reminder_time
        case unit, default_dose, schedule_raw
        case sort_order, updated_at, deleted_at
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(kind, forKey: .kind)
        try c.encode(hue, forKey: .hue)
        try c.encode(xp, forKey: .xp)
        try c.encodeOrNull(duration_minutes, forKey: .duration_minutes)
        try c.encodeOrNull(total_days, forKey: .total_days)
        try c.encodeOrNull(started_at, forKey: .started_at)
        try c.encodeOrNull(last_completed_at, forKey: .last_completed_at)
        try c.encodeOrNull(completions_log, forKey: .completions_log)
        try c.encodeOrNull(notes, forKey: .notes)
        try c.encodeOrNull(dosing_moment, forKey: .dosing_moment)
        try c.encodeOrNull(reminder_time, forKey: .reminder_time)
        // Dose fields use encodeIfPresent (omitted when nil) so a stale local
        // model — e.g. one that hasn't yet pulled the server's `unit` — can't
        // clobber the backend by pushing nil. The trade-off: the user can't
        // clear `unit` from the editor; clearing requires an explicit server-side
        // edit. Acceptable since clearing is rare.
        try c.encodeIfPresent(unit, forKey: .unit)
        try c.encodeIfPresent(default_dose, forKey: .default_dose)
        try c.encodeIfPresent(schedule_raw, forKey: .schedule_raw)
        try c.encode(sort_order, forKey: .sort_order)
        // updated_at / deleted_at are server-managed; skip on write.
    }

    static func from(_ asp: Aspiration) -> AspirationDTO {
        let dates = asp.completionsLog.map { Int64($0.timeIntervalSince1970 * 1000) }
        // Dose fields are scoped to whether `unit` is set; nil-them-out
        // together so `encodeIfPresent` skips them and a stale local row
        // (pre-pull) can't clobber the server's posology.
        let hasUnit = asp.unit != nil
        return AspirationDTO(
            id: asp.id.canonical,
            name: asp.name,
            emoji: asp.emoji,
            kind: asp.kindRaw,
            hue: asp.hue,
            xp: asp.xp,
            duration_minutes: asp.durationMinutes,
            total_days: asp.totalDays,
            started_at: asp.startedAt.map { Int64($0.timeIntervalSince1970 * 1000) },
            last_completed_at: asp.lastCompletedAt.map { Int64($0.timeIntervalSince1970 * 1000) },
            completions_log: String(data: (try? BackendSync.encoder.encode(dates)) ?? Data("[]".utf8), encoding: .utf8),
            notes: asp.notes,
            dosing_moment: asp.dosingMomentRaw,
            reminder_time: asp.reminderTime.map { Int64($0.timeIntervalSince1970 * 1000) },
            unit: asp.unit,
            default_dose: hasUnit ? asp.defaultDose : nil,
            schedule_raw: hasUnit ? asp.scheduleRaw : nil,
            sort_order: asp.sortOrder,
            updated_at: nil,
            deleted_at: nil
        )
    }
}

struct TaskDTO: Codable {
    let id: String
    let title: String
    let notes: String?
    let due_date: Int64?
    let is_done: Int
    let completed_at: Int64?
    let sort_order: Int
    let updated_at: Int64?
    let deleted_at: Int64?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, due_date, is_done, completed_at, sort_order, updated_at, deleted_at
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encodeOrNull(notes, forKey: .notes)
        try c.encodeOrNull(due_date, forKey: .due_date)
        try c.encode(is_done, forKey: .is_done)
        try c.encodeOrNull(completed_at, forKey: .completed_at)
        try c.encode(sort_order, forKey: .sort_order)
    }

    static func from(_ task: LifeTask) -> TaskDTO {
        TaskDTO(
            id: task.id.canonical,
            title: task.title,
            notes: task.notes,
            due_date: task.dueDate.map { Int64($0.timeIntervalSince1970 * 1000) },
            is_done: task.isDone ? 1 : 0,
            completed_at: task.completedAt.map { Int64($0.timeIntervalSince1970 * 1000) },
            sort_order: task.sortOrder,
            updated_at: nil,
            deleted_at: nil
        )
    }
}

struct ActivityLogDTO: Codable {
    let id: String
    let need_type: String
    let action_name: String
    let action_icon: String
    let boost_amount: Double
    let notes: String?
    let timestamp: Int64
    let deleted_at: Int64?

    static func from(_ log: ActivityLog) -> ActivityLogDTO {
        ActivityLogDTO(
            id: log.id.canonical,
            need_type: log.needType,
            action_name: log.actionName,
            action_icon: log.actionIcon,
            boost_amount: log.boostAmount,
            notes: log.notes,
            timestamp: Int64(log.timestamp.timeIntervalSince1970 * 1000),
            deleted_at: nil
        )
    }
}

struct NeedStateDTO: Codable {
    /// Optional because PUT /needs-state/:need takes the type from the URL path
    /// while GET /needs-state and /sync include it inline.
    let need_type: String?
    let value: Double
    let last_updated: Int64
    /// SQLite stores booleans as INTEGER (0/1). Keep the wire-format Int and convert at use sites.
    let enabled: Int
}

// MARK: - Type-erased encoder helper

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
