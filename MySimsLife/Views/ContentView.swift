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
            appearance.backgroundColor = UIColor(SimsTheme.panelBackground)
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
            #endif
        }
    }

    private var mainTabs: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Estado", systemImage: "heart.fill") }
                .tag(0)

            HistoryView()
                .tabItem { Label("Historial", systemImage: "clock.fill") }
                .tag(1)

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                .tag(2)
        }
        .tint(SimsTheme.accentGreen)
    }
}

#Preview {
    ContentView()
        .environment(NeedStore())
        .modelContainer(for: [ActivityLog.self, Aspiration.self, LifeTask.self], inMemory: true)
}
