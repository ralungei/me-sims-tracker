import SwiftUI

// MARK: - Aspirations row (horizontally scrollable cards)

struct AspirationsRow: View {
    let aspirations: [Aspiration]
    var upcoming: [Aspiration] = []
    /// How far the scroll viewport extends past the parent (negative outer
    /// padding). Use this to escape parent paddings so the scroll bleeds to
    /// the panel / screen edge.
    var outerEscape: CGFloat = 32
    /// Distance from the scroll viewport's edge to the first / last card.
    /// This is the visible card margin when scrolled to the start / end.
    var cardInset: CGFloat = 16
    var onTap: (Aspiration) -> Void
    var onAdd: () -> Void = {}
    var onEdit: (Aspiration) -> Void = { _ in }
    var onDelete: (Aspiration) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    AddAspirationCard(onTap: onAdd)
                    ForEach(aspirations) { asp in
                        AspirationCard(aspiration: asp) {
                            onTap(asp)
                        }
                        .contextMenu {
                            Button { onEdit(asp) } label: {
                                Label("Editar", systemImage: "pencil")
                            }
                            Button(role: .destructive) { onDelete(asp) } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        } preview: {
                            AspirationCard(aspiration: asp) {}
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(.horizontal, cardInset)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -outerEscape)

            if !upcoming.isEmpty {
                upcomingRow
            }
        }
    }

    private var upcomingRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PRÓXIMAMENTE")
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(SimsTheme.textDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(upcoming) { asp in
                        Button {
                            onEdit(asp)
                        } label: {
                            HStack(spacing: 6) {
                                Text(asp.emoji).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(asp.name)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(SimsTheme.textPrimary)
                                        .lineLimit(1)
                                    if let started = asp.startedAt {
                                        Text("empieza \(started.relativeFutureLabel())")
                                            .font(.system(size: 9, weight: .medium, design: .rounded))
                                            .foregroundStyle(SimsTheme.textDim)
                                    }
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.45))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, cardInset)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -outerEscape)
        }
        .padding(.top, 4)
    }
}

// MARK: - Add card

struct AddAspirationCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .stroke(SimsTheme.frame.opacity(0.6),
                                style: StrokeStyle(lineWidth: 1.4, dash: [3, 3]))
                        .frame(width: 28, height: 28)
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
                Text("Nueva")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text("aspiración")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            .padding(10)
            .frame(width: 96, height: 100)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SimsTheme.panelPeriwinkle.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SimsTheme.frame,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Single Aspiration Card

struct AspirationCard: View {
    let aspiration: Aspiration
    let onTap: () -> Void

    @State private var pulse: Bool = false

    private var hue: Double { aspiration.hue }
    private var done: Bool { aspiration.isDoneNow() }
    private var hueColor:  Color { SimsTheme.hueBody(hue) }
    private var color:     Color { done ? SimsTheme.frame : hueColor }
    /// Periwinkle when active, soft Sims green when completed.
    private var cardBG: Color {
        done ? SimsTheme.simsGreen.opacity(0.65) : SimsTheme.panelPeriwinkle
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(aspiration.emoji)
                        .font(.system(size: 20))
                    Spacer()
                    if done {
                        ZStack {
                            Circle()
                                .fill(SimsTheme.frame.opacity(0.18))
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(SimsTheme.frame, lineWidth: 1))
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                                .foregroundStyle(SimsTheme.frame)
                        }
                    } else {
                        Text("+\(aspiration.xp)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.4), lineWidth: 0.8))
                            )
                    }
                }

                Text(aspiration.name)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(SimsTheme.textPrimary)
                    .lineLimit(1)

                detail
            }
            .padding(10)
            .frame(width: 132, height: 100, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(cardBG)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SimsTheme.frame, lineWidth: 1.5)
                    )
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

    /// Compact "moment · hour" line, e.g. "media mañana · 11:00".
    private var dosingLabel: (text: String, icon: String)? {
        let formatter: (Date) -> String = { d in
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: d)
        }
        if let moment = aspiration.dosingMoment, let time = aspiration.reminderTime {
            return ("\(moment.label.lowercased()) · \(formatter(time))", moment.icon)
        }
        if let moment = aspiration.dosingMoment {
            return (moment.label.lowercased(), moment.icon)
        }
        if let time = aspiration.reminderTime {
            return (formatter(time), "clock.fill")
        }
        return nil
    }

    @ViewBuilder
    private var detail: some View {
        let dose = aspiration.currentDoseLabel()
        if aspiration.kind == .treatment,
           let day = aspiration.treatmentDay(),
           let total = aspiration.totalDays {
            treatmentDetail(day: day, total: total, dose: dose)
        } else if let dose {
            label(dose, systemImage: "pills.fill")
        } else if let dosing = dosingLabel {
            label(dosing.text, systemImage: dosing.icon)
        } else {
            kindDetail
        }
    }

    @ViewBuilder
    private func treatmentDetail(day: Int, total: Int, dose: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: dose != nil ? "pills.fill" : "leaf.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(color)
                if let dose {
                    Text(dose)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(SimsTheme.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(day)/\(total)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(SimsTheme.textDim)
                } else {
                    Text("Día \(day) de \(total)")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
            }
            if let dosing = dosingLabel {
                HStack(spacing: 3) {
                    Image(systemName: dosing.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(SimsTheme.textDim)
                    Text(dosing.text)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SimsTheme.frame.opacity(0.18))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [SimsTheme.frame, SimsTheme.frame.opacity(0.6)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: max(4, geo.size.width * (Double(day) / Double(total))))
                }
                .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 0.8))
            }
            .frame(height: 5)
        }
    }

    @ViewBuilder
    private var kindDetail: some View {
        switch aspiration.kind {
        case .dailySimple:
            label(String(localized: "Diario"), systemImage: "sun.max.fill")
        case .dailyTimed:
            let mins = aspiration.durationMinutes ?? 0
            label(String(localized: "\(mins) min · diario"), systemImage: "timer")
        case .weekly:
            label(String(localized: "Esta semana"), systemImage: "calendar")
        case .treatment:
            EmptyView()
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
        SimsTheme.background.ignoresSafeArea()
        AspirationsRow(aspirations: []) { _ in }
            .padding()
    }
}
