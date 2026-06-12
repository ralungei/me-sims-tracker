import SwiftUI

// MARK: - Treatments row (Botiquín tab — pills, supplements, vitamins)

struct TreatmentsRow: View {
    let treatments: [Treatment]
    /// Tratamientos cuyo `startedAt` es futuro. Se muestran como capsules en
    /// una fila secundaria "PRÓXIMAMENTE" — tap abre el editor para cambiar
    /// la fecha si quieres adelantarlo.
    var upcoming: [Treatment] = []
    var outerEscape: CGFloat = 32
    var cardInset: CGFloat = 16
    var onTap: (Treatment) -> Void
    var onAdd: () -> Void = {}
    var onEdit: (Treatment) -> Void = { _ in }
    var onDelete: (Treatment) -> Void = { _ in }
    var onMove: (UUID, UUID) -> Void = { _, _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // Empty-state CTA. The "+" in the tab title takes over
                    // once there's at least one tratamiento (active o upcoming).
                    if treatments.isEmpty && upcoming.isEmpty {
                        AddTreatmentCard(onTap: onAdd)
                    }
                    ForEach(treatments) { t in
                        TreatmentCard(treatment: t) { onTap(t) }
                            .simsCardMenu(onEdit: { onEdit(t) },
                                          onDelete: { onDelete(t) })
                            // Long-press drag to reorder, same gesture as TasksRow.
                            .draggable(t.id.uuidString) {
                                TreatmentCard(treatment: t) {}
                                    .opacity(0.85)
                            }
                            .dropDestination(for: String.self) { droppedIds, _ in
                                guard let droppedRaw = droppedIds.first,
                                      let dragged = UUID(uuidString: droppedRaw),
                                      dragged != t.id else { return false }
                                onMove(dragged, t.id)
                                return true
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
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(SimsTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(upcoming) { t in
                        Button {
                            onEdit(t)
                        } label: {
                            HStack(spacing: 6) {
                                Text(t.emoji).font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(t.name)
                                        .font(.system(.caption, design: .rounded, weight: .bold))
                                        .foregroundStyle(SimsTheme.textPrimary)
                                        .lineLimit(1)
                                    if let started = t.startedAt {
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

struct AddTreatmentCard: View {
    let onTap: () -> Void
    var body: some View {
        SimsCreateCard(label: "Nuevo\ntratamiento",
                       width: 144, height: 148,
                       onTap: onTap)
    }
}

// MARK: - Single treatment card

struct TreatmentCard: View {
    let treatment: Treatment
    let onTap: () -> Void

    private var taken: Bool { treatment.isTakenToday() }

    /// Whitened periwinkle (pendiente) or vivid green gradient (tomado hoy).
    private var cardBG: AnyShapeStyle {
        if taken {
            return AnyShapeStyle(LinearGradient(
                colors: [SimsTheme.simsGreenYellow,
                         SimsTheme.simsGreen],
                startPoint: .top, endPoint: .bottom
            ))
        }
        return AnyShapeStyle(Color.white.opacity(0.45))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(treatment.emoji)
                        .font(.system(size: 24))
                    Spacer(minLength: 0)
                    if taken {
                        ZStack {
                            Circle()
                                .fill(SimsTheme.frame.opacity(0.18))
                                .frame(width: 22, height: 22)
                                .overlay(Circle().stroke(SimsTheme.frame, lineWidth: 1))
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .black))
                                .foregroundStyle(SimsTheme.frame)
                        }
                    } else if let day = treatment.currentDay(),
                              let total = treatment.totalDays {
                        // Day N/M for finite courses.
                        Text("\(day)/\(total)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.55))
                                    .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.4), lineWidth: 0.8))
                            )
                            .monospacedDigit()
                    }
                }

                Text(treatment.name)
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
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(treatment.name))
        .accessibilityValue(Text(treatmentAccessibilityValue))
        .accessibilityHint(Text(taken
                                ? "Toca dos veces para deshacer la dosis"
                                : "Toca dos veces para tomar la dosis"))
        .accessibilityAddTraits(taken ? [.isButton, .isSelected] : .isButton)
    }

    private var treatmentAccessibilityValue: String {
        var parts: [String] = []
        parts.append(taken
                     ? String(localized: "tomado hoy")
                     : String(localized: "pendiente"))
        if let day = treatment.currentDay(), let total = treatment.totalDays {
            parts.append(String(localized: "día \(day) de \(total)"))
        }
        if let dose = treatment.currentDoseLabel() {
            parts.append(dose)
        }
        if let dosing = dosingLine {
            parts.append(dosing.text)
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private var detail: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let dose = treatment.currentDoseLabel() {
                Text(dose)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .lineLimit(1)
            }
            if let dosing = dosingLine {
                HStack(spacing: 4) {
                    Image(systemName: dosing.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(SimsTheme.textSecondary)
                    Text(dosing.text)
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        // Reserves a column on the right where `.simsCardMenu` sits.
        .padding(.trailing, 30)
    }

    /// Renders ONE thing — either the precise time (when set) or the moment
    /// label as a fallback. Concatenating both would overflow at 144pt; the
    /// moment's icon already conveys time-of-day, so the time alone reads.
    private var dosingLine: (text: String, icon: String)? {
        let timeText: String? = treatment.reminderTime.map { d in
            let f = DateFormatter()
            f.dateFormat = "HH:mm"
            return f.string(from: d)
        }
        // When both exist, time wins — it's the actionable bit. Keep the
        // moment's icon so users still see "media mañana" visually.
        if let time = timeText {
            return (time, treatment.dosingMoment?.icon ?? "clock.fill")
        }
        if let moment = treatment.dosingMoment {
            return (moment.label.lowercased(), moment.icon)
        }
        return nil
    }
}

#Preview {
    ZStack {
        SimsTheme.panelPeriwinkle.ignoresSafeArea()
        TreatmentsRow(treatments: []) { _ in }
            .padding()
    }
}
