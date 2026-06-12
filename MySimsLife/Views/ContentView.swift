import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NeedStore.self) private var store
    /// Persists across launches so the onboarding only runs once. Mirrored
    /// to iCloud KVS (see `CloudPrefsMirror`) so a second device skips the
    /// flow once the first device has finished it — which also stops it from
    /// re-seeding duplicate aspirations / treatments.
    @AppStorage(UDKey.onboardingComplete) private var onboardingComplete: Bool = false
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

    @State private var onboardingDoneThisLaunch: Bool = false

    var body: some View {
        // -ForceOnboarding launch arg re-shows the onboarding even
        // after it's been marked complete, for review/debugging.
        let forceOnboarding = ProcessInfo.processInfo.arguments.contains("-ForceOnboarding")
            && !onboardingDoneThisLaunch
        let showOnboarding = (!onboardingComplete || forceOnboarding)
        Group {
            if showOnboarding {
                OnboardingView(onFinish: {
                    onboardingComplete = true
                    onboardingDoneThisLaunch = true
                })
                .environment(store)
                .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .simsAnimation(.easeInOut(duration: 0.35), value: onboardingComplete)
        .simsAnimation(.easeInOut(duration: 0.35), value: onboardingDoneThisLaunch)
        .onAppear {
            store.configure(with: modelContext)
            #if os(iOS)
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            // Match the panel colour so there's no visible gap between the
            // panel's bottom rounded edge and the tab bar.
            appearance.backgroundColor = UIColor(SimsTheme.panelPeriwinkle)
            // Unselected items default to the system grey, which reads dirty
            // on the periwinkle bar — use translucent navy like the rest of
            // the chrome.
            let items = UITabBarItemAppearance()
            items.normal.iconColor = UIColor(SimsTheme.frame).withAlphaComponent(0.45)
            items.normal.titleTextAttributes = [
                .foregroundColor: UIColor(SimsTheme.frame).withAlphaComponent(0.45)
            ]
            items.selected.iconColor = UIColor(SimsTheme.frame)
            items.selected.titleTextAttributes = [
                .foregroundColor: UIColor(SimsTheme.frame)
            ]
            appearance.stackedLayoutAppearance = items
            appearance.inlineLayoutAppearance = items
            appearance.compactInlineLayoutAppearance = items
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
