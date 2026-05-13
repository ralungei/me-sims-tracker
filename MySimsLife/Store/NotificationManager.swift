import Foundation
import UserNotifications

/// User-configurable notification preferences. Persisted in UserDefaults so
/// they survive launches without needing the SwiftData layer.
///
/// The model is one master switch (handles permission) and three sub-toggles,
/// one per category. A reminder of any kind only fires when both the master
/// and its category are on.
enum NotificationsPrefs {
    /// Master toggle. When OFF, nothing fires regardless of sub-toggles.
    static let masterEnabledKey     = "notif.enabled"
    static let needsLowEnabledKey   = "notif.needsLow.enabled"
    static let tasksEnabledKey      = "notif.tasks.enabled"
    static let treatmentsEnabledKey = "notif.treatments.enabled"

    static let thresholdKey         = "notif.threshold"
    static let cooldownKey          = "notif.cooldownHours"

    /// Master switch — also controls the permission prompt. The key name
    /// (`notif.enabled`) is retained from older builds for backwards compat.
    static var masterEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: masterEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: masterEnabledKey) }
    }

    /// Sub-toggles. Default to `true` so opting in via the master switch
    /// turns every category on without forcing the user to flip three more.
    /// `register(defaults:)` runs at app launch (`registerDefaults()` below).
    static var needsLowEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: needsLowEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: needsLowEnabledKey) }
    }

    static var tasksEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: tasksEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: tasksEnabledKey) }
    }

    static var treatmentsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: treatmentsEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: treatmentsEnabledKey) }
    }

    /// Fraction (0…1). Below this, a notification fires once per need (with
    /// cooldown). Default 30 %.
    static var threshold: Double {
        get {
            let v = UserDefaults.standard.double(forKey: thresholdKey)
            return v <= 0 ? 0.30 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: thresholdKey) }
    }

    /// Hours between consecutive notifications for the same need while it
    /// stays below the threshold.
    static var cooldownHours: Double {
        get {
            let v = UserDefaults.standard.double(forKey: cooldownKey)
            return v <= 0 ? 6 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: cooldownKey) }
    }

    /// Call once at app launch so the sub-toggles read `true` until the user
    /// explicitly flips them off. `@AppStorage(...)` in views also passes a
    /// `default: true`, so this is belt-and-braces against direct
    /// `UserDefaults.bool(forKey:)` callers (the static accessors above).
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            needsLowEnabledKey:   true,
            tasksEnabledKey:      true,
            treatmentsEnabledKey: true
        ])
    }
}

/// Local notifications (no APNs / no backend). Three categories:
/// - **needs low** — fires when a bar crosses below `threshold`.
/// - **tasks** — one-shot reminders for agenda items.
/// - **treatments** — one-shot reminders for items in the botiquín.
///
/// Each category has its own sub-toggle in `NotificationsPrefs`. The master
/// toggle gates everything and is what triggers the system permission prompt.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
        // Without a delegate, iOS silently swallows notifications while the
        // app is in the foreground. This makes the test button feel broken.
        center.delegate = self
    }

    private let center = UNUserNotificationCenter.current()

    private static let taskPrefix      = "task."
    private static let treatmentPrefix = "treatment."

    private static func taskID(_ uuid: UUID) -> String { "\(taskPrefix)\(uuid.uuidString)" }
    private static func treatmentID(_ uuid: UUID) -> String { "\(treatmentPrefix)\(uuid.uuidString)" }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Threshold-cross detection (needs low)

    /// Call this whenever a need's value changes. If the new value crossed
    /// below the threshold *for the first time since the cooldown ended*,
    /// schedules an immediate notification.
    func notifyIfLow(need: NeedType, currentValue: Double, previousValue: Double) {
        guard NotificationsPrefs.masterEnabled,
              NotificationsPrefs.needsLowEnabled else { return }
        let t = NotificationsPrefs.threshold
        // Fire on the downward crossing only — staying low without crossing
        // doesn't re-trigger; once the bar climbs back above and falls again
        // we'll fire after the cooldown.
        guard previousValue >= t && currentValue < t else { return }
        guard canFire(for: need) else { return }
        markFired(for: need)
        scheduleImmediate(need: need, value: currentValue)
    }

    // MARK: - Task reminders

    /// Schedule a one-shot local notification for a task at the given date.
    /// If a previous reminder was scheduled for the same task ID, it's
    /// replaced. Pass a date in the past and nothing is scheduled.
    /// No-op if the master or tasks sub-toggle is off.
    func scheduleTaskReminder(taskID: UUID, title: String, at date: Date) {
        cancelTaskReminder(taskID: taskID)
        guard NotificationsPrefs.masterEnabled,
              NotificationsPrefs.tasksEnabled else { return }
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Tarea pendiente")
        content.body  = title
        content.sound = .default
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: Self.taskID(taskID),
            content: content,
            trigger: trigger
        )
        center.add(req, withCompletionHandler: nil)
    }

    func cancelTaskReminder(taskID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.taskID(taskID)]
        )
    }

    // MARK: - Treatment reminders

    /// Schedule a one-shot reminder for a treatment dose. Same semantics as
    /// `scheduleTaskReminder` but lives in its own identifier namespace so it
    /// can be cancelled independently when the user toggles the botiquín
    /// sub-category off.
    func scheduleTreatmentReminder(treatmentID: UUID, title: String, at date: Date) {
        cancelTreatmentReminder(treatmentID: treatmentID)
        guard NotificationsPrefs.masterEnabled,
              NotificationsPrefs.treatmentsEnabled else { return }
        guard date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Botiquín")
        content.body  = title
        content.sound = .default
        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let req = UNNotificationRequest(
            identifier: Self.treatmentID(treatmentID),
            content: content,
            trigger: trigger
        )
        center.add(req, withCompletionHandler: nil)
    }

    func cancelTreatmentReminder(treatmentID: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.treatmentID(treatmentID)]
        )
    }

    // MARK: - Bulk cancellation (when a sub-category is turned off)

    func cancelAllPending(withPrefix prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        guard !ids.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    func cancelAllTaskReminders() async {
        await cancelAllPending(withPrefix: Self.taskPrefix)
    }

    func cancelAllTreatmentReminders() async {
        await cancelAllPending(withPrefix: Self.treatmentPrefix)
    }

    // MARK: - Test

    func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Notificaciones activas")
        content.body  = String(localized: "Esto es una prueba.")
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "notif.test.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(req, withCompletionHandler: nil)
    }

    // MARK: - Internals

    private func cooldownKey(_ need: NeedType) -> String { "notif.lastFired.\(need.rawValue)" }

    private func canFire(for need: NeedType) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: cooldownKey(need)) as? Date else { return true }
        return Date().timeIntervalSince(last) >= NotificationsPrefs.cooldownHours * 3600
    }

    private func markFired(for need: NeedType) {
        UserDefaults.standard.set(Date(), forKey: cooldownKey(need))
    }

    private func scheduleImmediate(need: NeedType, value: Double) {
        let content = UNMutableNotificationContent()
        content.title = need.displayName
        let pct = Int((value * 100).rounded())
        content.body  = String(localized: "Está al \(pct)%. Hora de cuidarlo.")
        content.sound = .default
        let req = UNNotificationRequest(
            identifier: "notif.low.\(need.rawValue)",
            content: content,
            // 1s delay — banners with `nil` trigger occasionally get suppressed.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        center.add(req, withCompletionHandler: nil)
    }
}
