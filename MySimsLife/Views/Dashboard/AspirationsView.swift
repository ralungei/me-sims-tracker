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
                    // Big dashed CTA only when the list is empty — once the
                    // user has at least one aspiration the "+" lives in the
                    // tab title's right side (see DashboardView.tabTitleAddButton).
                    if aspirations.isEmpty && upcoming.isEmpty {
                        AddAspirationCard(onTap: onAdd)
                    }
                    ForEach(aspirations) { asp in
                        AspirationCard(aspiration: asp) {
                            onTap(asp)
                        }
                        .simsCardMenu(onEdit: { onEdit(asp) },
                                      onDelete: { onDelete(asp) })
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
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(SimsTheme.textSecondary)
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
        SimsCreateCard(label: "Nueva\naspiración",
                       width: 144, height: 148,
                       onTap: onTap)
    }
}

// MARK: - Single Aspiration Card

struct AspirationCard: View {
    let aspiration: Aspiration
    let onTap: () -> Void

    @State private var pulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var hue: Double { aspiration.hue }
    private var done: Bool { aspiration.isDoneNow() }
    private var hueColor:  Color { SimsTheme.hueBody(hue) }
    private var color:     Color { done ? SimsTheme.frame : hueColor }
    /// Whitened periwinkle (active) or a Sims-plumbob green gradient (done).
    private var cardBG: AnyShapeStyle {
        if done {
            return AnyShapeStyle(LinearGradient(
                colors: [SimsTheme.simsGreenYellow,   // bright yellow-green at top
                         SimsTheme.simsGreen],        // saturated green at bottom
                startPoint: .top, endPoint: .bottom
            ))
        }
        return AnyShapeStyle(Color.white.opacity(0.45))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(aspiration.emoji)
                        .font(.system(size: 24))
                    Spacer(minLength: 0)
                    if done {
                        ZStack {
                            Circle()
                                .fill(SimsTheme.frame.opacity(0.18))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(SimsTheme.frame, lineWidth: 1))
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(SimsTheme.frame)
                        }
                    } else {
                        Text("+\(aspiration.xp)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.4), lineWidth: 0.8))
                            )
                    }
                }

                Text(aspiration.name)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .tracking(0.3)
                    .foregroundStyle(SimsTheme.textPrimary)
                    .lineLimit(1)

                detail

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(width: 144, height: 148, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(cardBG)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(SimsTheme.frame, lineWidth: 1.5)
                    )
            )
            .scaleEffect(pulse ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
        .onChange(of: aspiration.lastCompletedAt) { _, _ in
            // Celebratory pulse when the user marks the aspiration done.
            // Reduce Motion turns it off — bouncing scale is exactly the
            // kind of motion the system setting wants to suppress.
            guard !reduceMotion else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { pulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.3)) { pulse = false }
            }
        }
        // VoiceOver folds the emoji + name + XP/check + detail into one
        // element. Without this, the user hears "rocket emoji", "+25",
        // "Creatine 5g", "Daily" as 4 separate focusable items.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(aspiration.name))
        .accessibilityValue(Text(aspirationAccessibilityValue))
        .accessibilityHint(Text(done
                                ? "Toca dos veces para deshacer"
                                : "Toca dos veces para completar"))
        .accessibilityAddTraits(done ? [.isButton, .isSelected] : .isButton)
    }

    /// Spoken state: progress + reward. Keeps the emoji out of speech (lectores
    /// suelen describirlo literalmente como "símbolo de cohete") y resume el
    /// estado real ("hecho hoy", "media mañana", "10 XP", etc.).
    private var aspirationAccessibilityValue: String {
        var parts: [String] = []
        if done {
            parts.append(String(localized: "completado hoy"))
        } else {
            parts.append(String(localized: "+\(aspiration.xp) XP"))
        }
        if let dosing = dosingLabel {
            parts.append(dosing.text)
        }
        return parts.joined(separator: ", ")
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
        case .oneTime:
            label(String(localized: "Puntual"), systemImage: "checkmark.seal.fill")
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
