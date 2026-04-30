import SwiftUI

struct AlertCardView: View {
    let alert: NeedStore.SimAlert
    var onDismiss: () -> Void = {}

    private var accentColor: Color {
        switch alert.severity {
        case .positive: return SimsTheme.simsGreen
        case .nudge:    return Color(red: 0.30, green: 0.55, blue: 0.95)
        case .warning:  return SimsTheme.simsOrange
        case .urgent:   return SimsTheme.simsRed
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Severity-tinted icon tile (Sims-style: gradient + navy frame +
            // outlined white-on-navy icon).
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [accentColor.opacity(0.85), accentColor.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SimsTheme.frame, lineWidth: 1.2))
                    .frame(width: 32, height: 32)
                Image(systemName: alert.icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(SimsTheme.frame)
                Image(systemName: alert.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            // Message
            Text(alert.message)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(SimsTheme.frame)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Cerrar aviso"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(SimsTheme.panelPeriwinkle)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        )
    }
}

// MARK: - Alerts Stack

struct AlertsStack: View {
    let alerts: [NeedStore.SimAlert]
    var onDismiss: (NeedStore.SimAlert) -> Void = { _ in }

    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(alerts) { alert in
                    AlertCardView(alert: alert) {
                        onDismiss(alert)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.92))
                    ))
                }
            }
        }
    }
}

// MARK: - Notifications sheet (triggered by the bell button next to the rombo)

/// Bottom sheet listing all visible alerts. Each card has a per-alert dismiss
/// X; the header carries a global Close button. Empty state shows a friendly
/// "todo bajo control" message so the sheet stays useful even when nothing
/// is firing.
struct NotificationsSheet: View {
    let alerts: [NeedStore.SimAlert]
    let onDismissAlert: (NeedStore.SimAlert) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if alerts.isEmpty {
                        emptyState
                    } else {
                        AlertsStack(alerts: alerts, onDismiss: onDismissAlert)
                    }
                }
                .padding(20)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Notificaciones")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .tracking(-0.5)
                .foregroundStyle(SimsTheme.textPrimary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(SimsTheme.frame)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Cerrar"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(SimsTheme.textSecondary)
            Text("Todo bajo control")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
            Text("Sin avisos pendientes ahora mismo.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .simsFieldStyle(cornerRadius: 18)
    }
}

#Preview {
    ZStack {
        SimsTheme.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 12) {
            AlertCardView(alert: .init(
                message: "¡Todo por encima del 60%! Gran momento",
                icon: "star.fill", severity: .positive))
            AlertCardView(alert: .init(
                message: "Un vaso de agua te vendría bien",
                icon: "drop.fill", severity: .nudge))
            AlertCardView(alert: .init(
                message: "Hora de comer — no saltes el almuerzo",
                icon: "fork.knife", severity: .warning))
            AlertCardView(alert: .init(
                message: "Es tarde — hora de dormir",
                icon: "moon.zzz.fill", severity: .urgent))
        }
        .padding()
    }
}
