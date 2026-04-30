import Foundation
import SwiftData

/// Persistent WebSocket to /events on the backend. Whenever the server
/// broadcasts a "*.changed" event, we trigger a `BackendSync.pull()` so the
/// local store catches up almost instantly.
@MainActor
final class RealtimeSync {
    static let shared = RealtimeSync()
    private init() {}

    private struct ServerEvent: Decodable {
        let type: String
        let from_client: String?
    }

    private var task: URLSessionWebSocketTask?
    private var isRunning = false
    private var modelContext: ModelContext?
    private var reconnectAttempts = 0
    private var pingTimer: Timer?

    var onEvent: ((String) -> Void)?

    func start(with context: ModelContext) {
        modelContext = context
        guard !isRunning else { return }
        isRunning = true
        connect()
    }

    func stop() {
        isRunning = false
        pingTimer?.invalidate()
        pingTimer = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    // MARK: - Connection

    private func connect() {
        guard isRunning else { return }
        let scheme = BackendCredentials.baseURL.scheme == "https" ? "wss" : "ws"
        let host = BackendCredentials.baseURL.host ?? ""
        let port = BackendCredentials.baseURL.port.map { ":\($0)" } ?? ""
        guard let url = URL(string: "\(scheme)://\(host)\(port)/events") else { return }

        var req = URLRequest(url: url)
        req.setValue(BackendCredentials.apiKey, forHTTPHeaderField: HTTPHeader.apiKey)
        req.setValue(BackendSync.clientID, forHTTPHeaderField: HTTPHeader.clientID)

        let task = URLSession.shared.webSocketTask(with: req)
        self.task = task
        task.resume()
        startReceiveLoop(on: task)
        schedulePing()
    }

    /// Single in-flight `receive()` per task — recursion via task continuation,
    /// not via spawning new Tasks per message (which races receive()).
    private func startReceiveLoop(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                guard self.task === task else { return }   // a newer connection took over
                switch result {
                case .success(let msg):
                    self.reconnectAttempts = 0
                    self.handle(msg)
                    self.startReceiveLoop(on: task)
                case .failure:
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handle(_ message: URLSessionWebSocketTask.Message) {
        guard case .string(let text) = message else { return }
        guard let data = text.data(using: .utf8),
              let event = try? JSONDecoder().decode(ServerEvent.self, from: data)
        else { return }
        let kind = SyncEventType(rawValue: event.type)
        if kind == .pong { return }
        // Skip echoes of our own writes — local state is already authoritative.
        if event.from_client == BackendSync.clientID { return }
        // Forward only to NeedStore's onEvent — a second pull here would race
        // it, advancing `lastSync` first and leaving NeedStore with an empty
        // needs_state delta.
        onEvent?(text)
    }

    private func schedulePing() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.task?.send(.string("{\"type\":\"ping\"}")) { _ in }
            }
        }
    }

    private func scheduleReconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        task = nil
        guard isRunning else { return }
        reconnectAttempts += 1
        let base = min(30.0, pow(1.6, Double(reconnectAttempts)))
        let jitter = Double.random(in: 0...1.5)
        let delay = base + jitter
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self.connect()
        }
    }
}
