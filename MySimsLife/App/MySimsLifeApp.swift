import SwiftUI
import SwiftData

@main
struct MySimsLifeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = NeedStore()

    let modelContainer: ModelContainer = {
        let schema = Schema([ActivityLog.self, Aspiration.self])
        // Try CloudKit → on-disk local → in-memory. The last fallback guarantees the app boots.
        let configs: [ModelConfiguration] = [
            ModelConfiguration(schema: schema,
                               isStoredInMemoryOnly: false,
                               cloudKitDatabase: .private("iCloud.com.mysims.life")),
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: false),
            ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        ]
        for config in configs {
            if let container = try? ModelContainer(for: schema, configurations: [config]) {
                return container
            }
        }
        fatalError("Could not initialise any ModelContainer")
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
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
