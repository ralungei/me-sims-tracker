import SwiftUI

struct AlertCardView: View {
    let alert: NeedStore.SimAlert
    @State private var glowPhase: Bool = false

    private var accentColor: Color {
        switch alert.severity {
        case .positive: return Color(red: 0.20, green: 0.92, blue: 0.40)
        case .nudge:    return Color(red: 0.30, green: 0.75, blue: 0.95)
        case .warning:  return Color(red: 0.96, green: 0.72, blue: 0.10)
        case .urgent:   return Color(red: 0.95, green: 0.25, blue: 0.25)
        }
    }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor.opacity(0.12), accentColor.opacity(0.04)],
            startPoint: .leading, endPoint: .trailing
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 4)

            // Icon with glow
            ZStack {
                // Pulsing glow behind icon (urgent/warning only)
                if alert.severity == .urgent || alert.severity == .warning {
                    Circle()
                        .fill(accentColor.opacity(glowPhase ? 0.35 : 0.10))
                        .frame(width: 32, height: 32)
                        .blur(radius: 6)
                }

                Image(systemName: alert.icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(accentColor)
                    .frame(width: 22)
            }

            // Message
            Text(alert.message)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(bgGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accentColor.opacity(glowPhase ? 0.35 : 0.15), lineWidth: 1)
                )
                .shadow(color: accentColor.opacity(0.15), radius: 8, y: 2)
        )
        .onAppear {
            guard alert.severity == .urgent || alert.severity == .warning else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPhase = true
            }
        }
    }
}

// MARK: - Alerts Stack

struct AlertsStack: View {
    let alerts: [NeedStore.SimAlert]

    var body: some View {
        if !alerts.isEmpty {
            VStack(spacing: 8) {
                ForEach(Array(alerts.enumerated()), id: \.element.id) { index, alert in
                    AlertCardView(alert: alert)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color(red: 0.07, green: 0.07, blue: 0.075).ignoresSafeArea()
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
