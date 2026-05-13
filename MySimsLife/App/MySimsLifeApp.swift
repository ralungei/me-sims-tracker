import SwiftUI
import SwiftData

@main
struct MySimsLifeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = NeedStore()

    init() {
        NotificationsPrefs.registerDefaults()
        CloudPrefsMirror.shared.start()
    }

    let modelContainer: ModelContainer = {
        let schema = Schema([ActivityLog.self, Aspiration.self, LifeTask.self, Treatment.self, NeedAnchor.self])
        // SwiftData + CloudKit. The framework auto-creates the iCloud container
        // matching the bundle id (`iCloud.com.mysims.life`) when `cloudKitDatabase`
        // is `.automatic`. All synced models must have either default values or
        // optional types — they already do.
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(for: schema, configurations: [config]) {
            return container
        }
        // Fallback: in-memory only (avoids crash on simulator without iCloud
        // sign-in or CloudKit network outage).
        let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [fallback]) {
            return container
        }
        fatalError("Could not initialise any ModelContainer")
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
                // Cap Dynamic Type growth. Some views (the 144×148 cards,
                // the pip-readout numbers inside bars) have hard physical
                // constraints — letting iOS scale them to AX5 (310 %)
                // would clip text. AX1 gives ~133 %, enough headroom for
                // most low-vision users without breaking the Sims-2 grid.
                .dynamicTypeSize(.medium ... .accessibility1)
                // Tint at the WindowGroup level so system alerts /
                // confirmationDialogs / share sheets adopt the app's navy
                // instead of falling back to iOS's default bright blue.
                .tint(SimsTheme.accentPrimary)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:   store.onBecomeActive()
                    case .background: store.onEnterBackground()
                    default: break
                    }
                }
        }
        .modelContainer(modelContainer)

        #if os(macOS)
        Settings {
            Text("My Sims Life — Configuración")
                .padding(40)
        }
        #endif
    }
}
