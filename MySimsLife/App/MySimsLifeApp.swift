import SwiftUI
import SwiftData

@main
struct MySimsLifeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = NeedStore()

    let modelContainer: ModelContainer = {
        let schema = Schema([ActivityLog.self, Aspiration.self])
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.mysims.life")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // Fallback to local store if CloudKit isn't available (e.g. no iCloud account in simulator)
            let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try! ModelContainer(for: schema, configurations: [localConfig])
        }
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
