import SwiftUI

/// Drill-down "Acerca de" — versión, créditos, dónde viven los datos,
/// nota de privacidad. Igual que la sección "Información" de la app
/// Salud de iOS: pantalla aparte para no abultar el listado principal.
struct AboutView: View {
    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    bigVersionCard
                    creditsPanel
                    privacyPanel
                }
                .padding(20)
            }
        }
        .navigationTitle("Acerca de")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(SimsTheme.panelPeriwinkle, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        #endif
    }

    // MARK: - Cards

    private var bigVersionCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(SimsTheme.frame)
                    .frame(width: 64, height: 64)
                Image(systemName: "suit.diamond.fill")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(Color.white)
            }
            Text("Me")
                .font(.system(.title, design: .rounded, weight: .heavy))
                .foregroundStyle(SimsTheme.textPrimary)
                .tracking(-0.5)
            Text("Versión \(appVersion)")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .simsPanelStyle()
    }

    private var creditsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Créditos")

            row(title: "Hecho por",
                value: "Razvan Mihai",
                caption: "Una app personal para llevar la rutina como en Los Sims.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle()
    }

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Privacidad")

            row(title: "Almacenamiento",
                value: "iCloud privado",
                caption: "Tus datos viven en tu cuenta iCloud, encriptados end-to-end. No hay servidor propio, no hay terceros.")

            Divider().background(SimsTheme.frame.opacity(0.25))

            row(title: "Compartir datos",
                value: "Nunca",
                caption: "La app no envía nada externamente. Ni analytics, ni crash reports. Lo que hagas se queda entre tú e iCloud.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .simsPanelStyle()
    }

    // MARK: - Helpers

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }

    private func row(title: LocalizedStringKey,
                     value: String,
                     caption: LocalizedStringKey? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .monospacedDigit()
            }
            if let caption {
                Text(caption)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
            }
        }
        .padding(.vertical, 6)
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
    NavigationStack {
        AboutView()
    }
}
