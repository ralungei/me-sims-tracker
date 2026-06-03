import SwiftUI
import UserNotifications

/// Main Ajustes screen. Health/Settings.app pattern: a short list of
/// drill-down rows with at-a-glance summary values, instead of one long
/// page with every option inlined. Each detail screen lives in its own
/// view file.
struct SettingsView: View {
    @Environment(NeedStore.self) private var store

    @AppStorage(NotificationsPrefs.masterEnabledKey)     private var masterEnabled: Bool = false
    @AppStorage(NotificationsPrefs.needsLowEnabledKey)   private var needsLowEnabled: Bool = true
    @AppStorage(NotificationsPrefs.tasksEnabledKey)      private var tasksEnabled: Bool = true
    @AppStorage(NotificationsPrefs.treatmentsEnabledKey) private var treatmentsEnabled: Bool = true

    @State private var showingResetConfirm: Bool = false
    @State private var isResetting: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Ajustes")
                            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                            .tracking(-0.5)
                            .foregroundStyle(SimsTheme.textPrimary)

                        configRows
                        dangerZoneSection
                    }
                    .padding(20)
                }
            }
            .alert("¿Empezar de cero?",
                   isPresented: $showingResetConfirm) {
                Button("Cancelar", role: .cancel) {}
                Button("Sí, borrar todo", role: .destructive) {
                    Task {
                        isResetting = true
                        await store.resetEverything()
                        isResetting = false
                    }
                }
            } message: {
                Text("Borra aspiraciones, tareas, botiquín e historial — local y en la nube. Mantiene tu nombre y prefs. Esta acción no se puede deshacer.")
            }
        }
    }

    // MARK: - Drill-down rows

    private var configRows: some View {
        VStack(spacing: 0) {
            NavigationLink {
                NotificationsDetailView()
            } label: {
                drillRow(icon: "bell.fill",
                         title: "Notificaciones",
                         summary: notificationsSummary)
            }
            .buttonStyle(.plain)

            Divider().background(SimsTheme.frame.opacity(0.25))

            NavigationLink {
                AboutView()
            } label: {
                drillRow(icon: "info.circle.fill",
                         title: "Acerca de",
                         summary: appVersion)
            }
            .buttonStyle(.plain)
        }
        .simsPanelStyle()
    }

    /// One row of the iOS-style drill-down list. Icon on the left, title
    /// in the middle, summary value + chevron on the right.
    private func drillRow(icon: String,
                          title: LocalizedStringKey,
                          summary: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(SimsTheme.frame)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.45))
                        .overlay(Circle().stroke(SimsTheme.frame.opacity(0.35), lineWidth: 1))
                )

            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)

            Spacer()

            Text(summary)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(SimsTheme.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    // MARK: - Summaries (at-a-glance values shown on the right of each row)

    private var notificationsSummary: String {
        guard masterEnabled else {
            return String(localized: "Desactivadas")
        }
        let active = [needsLowEnabled, tasksEnabled, treatmentsEnabled].filter { $0 }.count
        return String(localized: "\(active)/3 activas")
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    // MARK: - Danger zone (stays inline at bottom — destructive, no drill)

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Zona peligrosa")
            SimsDeleteButton(label: isResetting ? "Borrando…" : "Empezar de cero") {
                showingResetConfirm = true
            }
            .disabled(isResetting)
            .opacity(isResetting ? 0.6 : 1)
            Text("Borra aspiraciones, tareas, botiquín y todo el historial. Mantiene tu nombre y prefs.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle()
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(SimsTheme.textDim)
    }
}

#Preview {
    SettingsView()
        .environment(NeedStore())
}
