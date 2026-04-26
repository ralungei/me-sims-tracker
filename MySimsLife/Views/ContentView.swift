import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(NeedStore.self) private var store
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Estado", systemImage: "heart.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("Historial", systemImage: "clock.fill")
                }
                .tag(1)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(2)
        }
        .tint(SimsTheme.accentGreen)
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
}

#Preview {
    ContentView()
        .environment(NeedStore())
        .modelContainer(for: ActivityLog.self, inMemory: true)
}
