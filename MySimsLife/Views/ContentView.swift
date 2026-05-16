import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NeedStore.self) private var store
    @AppStorage("userName") private var userName: String = ""
    /// Defaults to Status (0). Screenshot script overrides via `-RootTab status|history|settings`.
    @State private var selectedTab: Int = {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-RootTab"), idx + 1 < args.count else { return 0 }
        switch args[idx + 1].lowercased() {
        case "history":  return 1
        case "settings": return 2
        default:         return 0
        }
    }()

    @State private var onboardingDone: Bool = false

    var body: some View {
        // TEMP DEBUG: -ForceOnboarding launch arg shows the onboarding
        // even if userName persists from iCloud KVS, so the flow can be
        // reviewed without nuking the simulator. `onboardingDone` lets
        // OnboardingView close itself even in that forced state.
        let forceOnboarding = ProcessInfo.processInfo.arguments.contains("-ForceOnboarding")
            && !onboardingDone
        Group {
            if userName.isEmpty || forceOnboarding {
                OnboardingView(onFinish: { onboardingDone = true })
                    .environment(store)
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .simsAnimation(.easeInOut(duration: 0.35), value: userName.isEmpty)
        .simsAnimation(.easeInOut(duration: 0.35), value: onboardingDone)
        .onAppear {
            store.configure(with: modelContext)
            #if os(iOS)
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            // Match the panel colour so there's no visible gap between the
            // panel's bottom rounded edge and the tab bar.
            appearance.backgroundColor = UIColor(SimsTheme.panelPeriwinkle)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            #endif
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Estado", systemImage: "suit.diamond.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("Historial", systemImage: "clock.fill") }
                .tag(1)

            SettingsView()
                .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .tint(SimsTheme.accentPrimary)
    }
}

#Preview {
    ContentView()
        .environment(NeedStore())
        .modelContainer(for: [ActivityLog.self, Aspiration.self, LifeTask.self, Treatment.self], inMemory: true)
}
