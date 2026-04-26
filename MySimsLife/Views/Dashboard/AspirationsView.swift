import SwiftUI

// MARK: - Aspirations row (horizontally scrollable cards)

struct AspirationsRow: View {
    let aspirations: [Aspiration]
    var alwaysOn: Bool = false
    var horizontalInset: CGFloat = 32
    var onTap: (Aspiration) -> Void
    var onAdd: () -> Void = {}
    var onEdit: (Aspiration) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("✦")
                    .font(.system(.caption, weight: .bold))
                    .foregroundStyle(SimsTheme.accentWarm)
                Text("ASPIRACIONES")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(SimsTheme.textDim)
                Spacer()
                let donesToday = aspirations.filter { $0.isDoneNow() }.count
                if donesToday > 0 {
                    Text("\(donesToday)/\(aspirations.count) hoy")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.accentGreen)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AddAspirationCard(alwaysOn: alwaysOn, onTap: onAdd)
                    ForEach(aspirations) { asp in
                        AspirationCard(aspiration: asp, alwaysOn: alwaysOn) {
                            onTap(asp)
                        }
                        .contextMenu {
                            Button {
                                onEdit(asp)
                            } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalInset)
            }
            .padding(.horizontal, -horizontalInset)
        }
    }
}

// MARK: - Add card

struct AddAspirationCard: View {
    var alwaysOn: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(SimsTheme.textDim, style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
                Text("Nueva")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textSecondary)
                Text("aspiración")
                    .font(.system(.caption2, design: .rounded, weight: .medium))
                    .foregroundStyle(SimsTheme.textDim)
            }
            .frame(width: alwaysOn ? 140 : 120, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(SimsTheme.textDim.opacity(0.6),
                            style: StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Single Aspiration Card

struct AspirationCard: View {
    let aspiration: Aspiration
    var alwaysOn: Bool = false
    let onTap: () -> Void

    @State private var pulse: Bool = false

    private var hue: Double { aspiration.hue }
    private var done: Bool { aspiration.isDoneNow() }
    private var doneColor: Color { SimsTheme.valueColor(for: 1.0) }   // sage green
    private var hueColor:  Color { Color(hue: hue/360, saturation: 0.55, brightness: 0.55) }
    private var color:     Color { done ? doneColor : hueColor }
    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: done
                ? [doneColor.opacity(0.30), doneColor.opacity(0.18)]
                : [Color.white.opacity(0.07), Color.white.opacity(0.03)],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(aspiration.emoji)
                        .font(.system(size: 26))
                    Spacer()
                    if done {
                        ZStack {
                            Circle().fill(color.opacity(0.25)).frame(width: 22, height: 22)
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(color)
                        }
                    } else {
                        Text("+\(aspiration.xp)")
                            .font(.system(.caption2, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.accentWarm)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(SimsTheme.accentWarm.opacity(0.15)))
                    }
                }

                Text(aspiration.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .lineLimit(1)

                detail
            }
            .frame(width: alwaysOn ? 200 : 168, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(bgGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(done ? color.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: done ? color.opacity(0.25) : .clear, radius: 10, y: 3)
            )
            .scaleEffect(pulse ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onChange(of: aspiration.lastCompletedAt) { _, _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3)) { pulse = false }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch aspiration.kind {
        case .dailySimple:
            label("Diario", systemImage: "sun.max.fill")
        case .dailyTimed:
            label("\(aspiration.durationMinutes ?? 0) min · diario",
                  systemImage: "timer")
        case .weekly:
            label("Esta semana", systemImage: "calendar")
        case .treatment:
            if let day = aspiration.treatmentDay(), let total = aspiration.totalDays {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(color)
                        Text("Día \(day) de \(total)")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(SimsTheme.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [color, color.opacity(0.65)],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(4, geo.size.width * (Double(day) / Double(total))))
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
    }

    private func label(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textSecondary)
        }
    }
}

#Preview {
    ZStack {
        SimsTheme.mainBackground.ignoresSafeArea()
        AspirationsRow(aspirations: []) { _ in }
            .padding()
    }
}
