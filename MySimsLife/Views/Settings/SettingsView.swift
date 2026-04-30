import SwiftUI
import UserNotifications

struct SettingsView: View {
    @AppStorage(NotificationsPrefs.enabledKey)   private var enabled: Bool = false
    @AppStorage(NotificationsPrefs.thresholdKey) private var threshold: Double = 0.30
    @AppStorage(NotificationsPrefs.cooldownKey)  private var cooldownHours: Double = 6

    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Ajustes")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(SimsTheme.textPrimary)

                    notificationsSection

                    if permissionStatus == .denied {
                        permissionDeniedHint
                    }
                }
                .padding(20)
            }
        }
        .task { await refreshPermission() }
    }

    // MARK: - Sections

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Notificaciones")

            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Avisar cuando una necesidad esté baja")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Text("Banner local (no usa servidor).")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(SimsTheme.textDim)
                }
            }
            .tint(SimsTheme.accentPrimary)
            .onChange(of: enabled) { _, on in
                guard on else { return }
                Task {
                    let granted = await NotificationManager.shared.requestPermission()
                    if !granted { enabled = false }
                    await refreshPermission()
                }
            }

            if enabled {
                thresholdRow
                cooldownRow

                Button {
                    NotificationManager.shared.sendTest()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge")
                        Text("Probar notificación")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    }
                    .foregroundStyle(SimsTheme.accentPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(SimsTheme.accentPrimary.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: SimsTheme.cornerRadius)
                .fill(SimsTheme.panelPeriwinkle)
                .overlay(
                    RoundedRectangle(cornerRadius: SimsTheme.cornerRadius)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
                )
        )
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
            Text("Te avisamos cuando una barra cruza por debajo.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
        }
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
    SettingsView()
}
