import Foundation

/// Mirrors a fixed allowlist of UserDefaults keys to **iCloud Key-Value
/// Store** (`NSUbiquitousKeyValueStore`) so the user's preferences follow
/// them across devices. Designed to be invisible to the rest of the app —
/// views keep using `@AppStorage` against UserDefaults, this layer
/// underneath syncs the values both ways.
///
/// What's mirrored:
/// - `userName`
/// - `enabledNeeds`
/// - all `NotificationsPrefs.*Key`
///
/// What's NOT mirrored:
/// - `needsState` (per-device bar values, mutated by decay every minute —
///   would burn the KVS rate limit and isn't really "settings")
/// - `notif.lastFired.<need>` (per-device cooldown tracking)
@MainActor
final class CloudPrefsMirror {
    static let shared = CloudPrefsMirror()

    /// Source-of-truth list. New prefs that should follow the user across
    /// devices belong here. Keep small — KVS is rate-limited (~1024 keys,
    /// ~1MB total per app).
    private let mirroredKeys: [String]

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    private var pushDebounce: DispatchWorkItem?
    private var observers: [NSObjectProtocol] = []
    private var started = false

    private init() {
        // `enabledNeeds` lives in `NeedAnchor.enabled` (CloudKit-synced via
        // SwiftData) — not mirrored here. Keep this list to true app-prefs.
        self.mirroredKeys = [
            UDKey.userName,
            NotificationsPrefs.masterEnabledKey,
            NotificationsPrefs.needsLowEnabledKey,
            NotificationsPrefs.tasksEnabledKey,
            NotificationsPrefs.treatmentsEnabledKey,
            NotificationsPrefs.thresholdKey,
            NotificationsPrefs.cooldownKey
        ]
    }

    func start() {
        guard !started else { return }
        started = true

        // Remote → local: iCloud pushed a change from another device.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handleRemoteChange(note) }
        })

        // Local → remote (debounced): user changed a UserDefaults value
        // (typed name, toggled a switch, picked a plan, …).
        observers.append(NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: defaults,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleCloudPush() }
        })

        // Force the KVS to fetch on launch — covers the "second device,
        // fresh install" case so the user's prefs land before the views
        // first render and onboarding is skipped.
        kvs.synchronize()
        applyRemoteToLocal(keys: mirroredKeys)
    }

    private func handleRemoteChange(_ note: Notification) {
        guard let changedKeys = note.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] else { return }
        let relevant = changedKeys.filter(mirroredKeys.contains)
        guard !relevant.isEmpty else { return }
        applyRemoteToLocal(keys: relevant)
    }

    private func scheduleCloudPush() {
        // Coalesce typing / rapid toggling into a single push 2 s later.
        pushDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.pushChangedToCloud() }
        }
        pushDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: work)
    }

    private func applyRemoteToLocal(keys: [String]) {
        for key in keys {
            if let remote = kvs.object(forKey: key) {
                defaults.set(remote, forKey: key)
            }
        }
    }

    /// Pushes only the keys whose local value differs from KVS, so the
    /// "remote→local→push back" feedback loop is naturally short-circuited
    /// (after applyRemoteToLocal the values are already equal).
    private func pushChangedToCloud() {
        for key in mirroredKeys {
            let local = defaults.object(forKey: key)
            let remote = kvs.object(forKey: key)
            guard !objectsEqual(local, remote), let local else { continue }
            kvs.set(local, forKey: key)
        }
        kvs.synchronize()
    }

    private func objectsEqual(_ a: Any?, _ b: Any?) -> Bool {
        let aObj = a as? NSObject
        let bObj = b as? NSObject
        if aObj == nil && bObj == nil { return true }
        return aObj?.isEqual(bObj) ?? false
    }
}
