import Foundation

/// Shared string constants for the sync layer. The backend ships matching
/// values in TS — keeping them in one place per side avoids typos that would
/// silently break sync (a typed event name missing on the receiver = no-op).

enum HTTPHeader {
    static let apiKey   = "X-API-Key"
    static let clientID = "X-Client-ID"
}

enum SyncEventType: String {
    case hello                = "hello"
    case pong                 = "pong"
    case aspirationsChanged   = "aspirations.changed"
    case tasksChanged         = "tasks.changed"
    case activityLogChanged   = "activity_log.changed"
    case needsStateChanged    = "needs_state.changed"
}

enum UDKey {
    static let userName              = "userName"
    static let needsState            = "needsState"
    static let enabledNeeds          = "enabledNeeds"
    static let backendClientID       = "backendClientID"
    static let backendLastSyncMs     = "backendLastSyncMs"
}
