import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NeedStore.self) private var store
    @AppStorage("userName") private var userName: String = ""
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if userName.isEmpty {
                OnboardingView(onFinish: {})
                    .environment(store)
                    .transition(.opacity)
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: userName.isEmpty)
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
        .modelContainer(for: [ActivityLog.self, Aspiration.self, LifeTask.self], inMemory: true)
}
