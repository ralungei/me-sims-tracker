import Foundation
import UserNotifications

/// User-configurable notification preferences. Persisted in UserDefaults so
/// they survive launches without needing the SwiftData layer.
enum NotificationsPrefs {
    static let enabledKey       = "notif.enabled"
    static let thresholdKey     = "notif.threshold"
    static let cooldownKey      = "notif.cooldownHours"

    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
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
}

/// Local notifications (no APNs / no backend). Fires a banner when a need
/// crosses below `NotificationsPrefs.threshold`, with a per-need cooldown to
/// avoid spamming while the bar stays low.
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

    // MARK: - Threshold-cross detection

    /// Call this whenever a need's value changes. If the new value crossed
    /// below the threshold *for the first time since the cooldown ended*,
    /// schedules an immediate notification.
    func notifyIfLow(need: NeedType, currentValue: Double, previousValue: Double) {
        guard NotificationsPrefs.enabled else { return }
        let t = NotificationsPrefs.threshold
        // Fire on the downward crossing only — staying low without crossing
        // doesn't re-trigger; once the bar climbs back above and falls again
        // we'll fire after the cooldown.
        guard previousValue >= t && currentValue < t else { return }
        guard canFire(for: need) else { return }
        markFired(for: need)
        scheduleImmediate(need: need, value: currentValue)
    }

    func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Notificaciones activas")
        content.body  = String(localized: "Te avisaremos cuando una necesidad esté baja.")
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
