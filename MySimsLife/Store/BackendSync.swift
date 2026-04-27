import Foundation
import SwiftData

// MARK: - Backend sync client

/// Local-first sync with the Cloudflare Worker backend.
/// Pull on launch + push on every mutation. Last-write-wins by `updated_at`.
actor BackendSync {

    // MARK: Config (read from gitignored BackendCredentials.swift)

    static var baseURL: URL { BackendCredentials.baseURL }
    static var apiKey:  String { BackendCredentials.apiKey }

    static let shared = BackendSync()
    private init() {}

    private var lastSync: Int64 {
        get { Int64(UserDefaults.standard.integer(forKey: "backendLastSyncMs")) }
        set { UserDefaults.standard.set(newValue, forKey: "backendLastSyncMs") }
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
        req.setValue(Self.apiKey, forHTTPHeaderField: "X-API-Key")
        if let body {
            req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
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

    /// Fetches everything modified since `lastSync` and applies it to the local SwiftData store.
    func pull(into context: ModelContext) async {
        do {
            let data = try await request("/sync?since=\(lastSync)")
            let decoded = try JSONDecoder().decode(SyncResponse.self, from: data)
            await MainActor.run {
                applyAspirations(decoded.aspirations, context: context)
                applyTasks(decoded.tasks, context: context)
                applyActivityLog(decoded.activity_log, context: context)
                try? context.save()
            }
            lastSync = decoded.server_time
        } catch {
            print("[BackendSync] pull failed: \(error.localizedDescription)")
        }
    }

    @MainActor
    private func applyAspirations(_ remotes: [AspirationDTO], context: ModelContext) {
        guard !remotes.isEmpty else { return }
        let descriptor = FetchDescriptor<Aspiration>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: locals.compactMap { ($0.id.uuidString, $0) })
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id) else { continue }
            if let existing = byId[remote.id] {
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

    @MainActor
    private func apply(_ dto: AspirationDTO, to model: Aspiration) {
        model.name = dto.name
        model.emoji = dto.emoji
        model.kindRaw = dto.kind
        model.hue = dto.hue
        model.xp = dto.xp
        model.durationMinutes = dto.duration_minutes
        model.totalDays = dto.total_days
        model.startedAt = dto.started_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        model.lastCompletedAt = dto.last_completed_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        if let raw = dto.completions_log,
           let dates = try? JSONDecoder().decode([Int64].self, from: Data(raw.utf8)) {
            model.completionsLog = dates.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        }
        model.sortOrder = dto.sort_order
    }

    @MainActor
    private func applyTasks(_ remotes: [TaskDTO], context: ModelContext) {
        guard !remotes.isEmpty else { return }
        let descriptor = FetchDescriptor<LifeTask>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: locals.compactMap { ($0.id.uuidString, $0) })
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id) else { continue }
            if let existing = byId[remote.id] {
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
        model.title = dto.title
        model.notes = dto.notes
        model.dueDate = dto.due_date.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        model.isDone = dto.is_done == 1
        model.completedAt = dto.completed_at.map { Date(timeIntervalSince1970: TimeInterval($0) / 1000) }
        model.sortOrder = dto.sort_order
    }

    @MainActor
    private func applyActivityLog(_ remotes: [ActivityLogDTO], context: ModelContext) {
        guard !remotes.isEmpty else { return }
        let descriptor = FetchDescriptor<ActivityLog>()
        let locals = (try? context.fetch(descriptor)) ?? []
        let byId = Dictionary(uniqueKeysWithValues: locals.map { ($0.id.uuidString, $0) })
        for remote in remotes {
            guard let uuid = UUID(uuidString: remote.id),
                  let need = NeedType(rawValue: remote.need_type) else { continue }
            if remote.deleted_at != nil {
                if let existing = byId[remote.id] { context.delete(existing) }
                continue
            }
            if byId[remote.id] != nil { continue }   // already have it
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
            _ = try? await request("/aspirations/\(asp.id.uuidString)", method: "PATCH", body: dto)
        }
    }

    func deleteAspiration(id: UUID) async {
        _ = try? await request("/aspirations/\(id.uuidString)", method: "DELETE")
    }

    func pushTask(_ task: LifeTask) async {
        let dto = TaskDTO.from(task)
        do { _ = try await request("/tasks", method: "POST", body: dto) } catch {
            _ = try? await request("/tasks/\(task.id.uuidString)", method: "PATCH", body: dto)
        }
    }

    func deleteTask(id: UUID) async {
        _ = try? await request("/tasks/\(id.uuidString)", method: "DELETE")
    }

    func pushActivityLog(_ log: ActivityLog) async {
        let dto = ActivityLogDTO.from(log)
        _ = try? await request("/activity-log", method: "POST", body: dto)
    }

    func deleteActivityLog(id: UUID) async {
        _ = try? await request("/activity-log/\(id.uuidString)", method: "DELETE")
    }

    func pushNeedState(_ need: NeedType, value: Double, lastUpdated: Date, enabled: Bool) async {
        let body = NeedStateDTO(value: value,
                                last_updated: Int64(lastUpdated.timeIntervalSince1970 * 1000),
                                enabled: enabled)
        _ = try? await request("/needs-state/\(need.rawValue)", method: "PUT", body: body)
    }
}

// MARK: - DTOs

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
    let sort_order: Int
    let updated_at: Int64?
    let deleted_at: Int64?

    static func from(_ asp: Aspiration) -> AspirationDTO {
        let dates = asp.completionsLog.map { Int64($0.timeIntervalSince1970 * 1000) }
        return AspirationDTO(
            id: asp.id.uuidString,
            name: asp.name,
            emoji: asp.emoji,
            kind: asp.kindRaw,
            hue: asp.hue,
            xp: asp.xp,
            duration_minutes: asp.durationMinutes,
            total_days: asp.totalDays,
            started_at: asp.startedAt.map { Int64($0.timeIntervalSince1970 * 1000) },
            last_completed_at: asp.lastCompletedAt.map { Int64($0.timeIntervalSince1970 * 1000) },
            completions_log: String(data: (try? JSONEncoder().encode(dates)) ?? Data("[]".utf8), encoding: .utf8),
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

    static func from(_ task: LifeTask) -> TaskDTO {
        TaskDTO(
            id: task.id.uuidString,
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
            id: log.id.uuidString,
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
    let value: Double
    let last_updated: Int64
    let enabled: Bool
}

// MARK: - Type-erased encoder helper

private struct AnyEncodable: Encodable {
    let value: Encodable
    init(_ value: Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}
