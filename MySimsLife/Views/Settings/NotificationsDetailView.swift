import SwiftUI
import UserNotifications

/// Drill-down detail screen for everything notification-related: master
/// switch, per-category sub-toggles, threshold + cooldown for needs-low
/// alerts, and a "Probar" row. Lives in its own pantalla (push from the
/// main Ajustes list) so the main screen stays a clean overview — same
/// pattern as iOS Health / Settings.app.
struct NotificationsDetailView: View {
    @AppStorage(NotificationsPrefs.masterEnabledKey)     private var masterEnabled: Bool = false
    @AppStorage(NotificationsPrefs.needsLowEnabledKey)   private var needsLowEnabled: Bool = true
    @AppStorage(NotificationsPrefs.tasksEnabledKey)      private var tasksEnabled: Bool = true
    @AppStorage(NotificationsPrefs.treatmentsEnabledKey) private var treatmentsEnabled: Bool = true
    @AppStorage(NotificationsPrefs.thresholdKey)         private var threshold: Double = 0.30
    @AppStorage(NotificationsPrefs.cooldownKey)          private var cooldownHours: Double = 6

    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    masterPanel

                    if masterEnabled {
                        subTogglesPanel
                    }

                    if permissionStatus == .denied {
                        permissionDeniedHint
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Notificaciones")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SimsTheme.panelPeriwinkle, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
        .task { await refreshPermission() }
    }

    // MARK: - Master

    private var masterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $masterEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activar notificaciones")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Text("Recibirás avisos según las categorías que actives debajo.")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
            }
            .tint(SimsTheme.accentPrimary)
            .onChange(of: masterEnabled) { _, on in
                if on {
                    Task {
                        let granted = await NotificationManager.shared.requestPermission()
                        if !granted { masterEnabled = false }
                        await refreshPermission()
                    }
                } else {
                    Task {
                        await NotificationManager.shared.cancelAllTaskReminders()
                        await NotificationManager.shared.cancelAllTreatmentReminders()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle()
    }

    // MARK: - Sub-toggles

    private var subTogglesPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Tipos de aviso")

            subSection(
                title: "Necesidades bajas",
                subtitle: "Cuando una barra cae por debajo del umbral.",
                isOn: $needsLowEnabled
            )

            if needsLowEnabled {
                thresholdRow
                cooldownRow
            }

            Divider().background(SimsTheme.frame.opacity(0.25))

            subSection(
                title: "Tareas",
                subtitle: "Recordatorios de la agenda con hora específica.",
                isOn: $tasksEnabled
            )
            .onChange(of: tasksEnabled) { _, on in
                if !on {
                    Task { await NotificationManager.shared.cancelAllTaskReminders() }
                }
            }

            Divider().background(SimsTheme.frame.opacity(0.25))

            subSection(
                title: "Botiquín",
                subtitle: "Recordatorios de tratamientos y suplementos.",
                isOn: $treatmentsEnabled
            )
            .onChange(of: treatmentsEnabled) { _, on in
                if !on {
                    Task { await NotificationManager.shared.cancelAllTreatmentReminders() }
                }
            }

            Divider().background(SimsTheme.frame.opacity(0.25))

            Button {
                NotificationManager.shared.sendTest()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(SimsTheme.frame)
                        .frame(width: 22)
                    Text("Probar notificación")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Spacer()
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle()
    }

    private func subSection(title: LocalizedStringKey,
                            subtitle: LocalizedStringKey,
                            isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(subtitle)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
        }
        .tint(SimsTheme.accentPrimary)
    }

    private var thresholdRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Umbral")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Spacer()
                Text("\(Int((threshold * 100).rounded()))%")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.frame)
                    .monospacedDigit()
            }
            Slider(value: $threshold, in: 0.10...0.50, step: 0.05)
                .tint(SimsTheme.frame)
        }
        .padding(.leading, 8)
    }

    private var cooldownRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Repetir cada")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text("Mínimo entre avisos para la misma necesidad.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            Spacer()
            Stepper(value: $cooldownHours, in: 1...24, step: 1) {
                Text("\(Int(cooldownHours)) h")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.frame)
                    .monospacedDigit()
                    .frame(minWidth: 36, alignment: .trailing)
            }
        }
        .padding(.leading, 8)
    }

    private var permissionDeniedHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(SimsTheme.negativeTint)
            VStack(alignment: .leading, spacing: 4) {
                Text("Permiso denegado")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text("Tienes las notificaciones desactivadas para esta app en Ajustes del sistema. Actívalas allí para que funcionen.")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SimsTheme.negativeTint.opacity(0.08))
        )
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(SimsTheme.textDim)
    }

    @MainActor
    private func refreshPermission() async {
        permissionStatus = await NotificationManager.shared.currentAuthorizationStatus()
    }
}

#Preview {
    NavigationStack {
        NotificationsDetailView()
    }
}
