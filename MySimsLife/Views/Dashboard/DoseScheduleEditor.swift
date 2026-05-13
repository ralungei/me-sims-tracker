import SwiftUI

// MARK: - Dose schedule editor
//
// Edits a `[DoseStep]` (variable-dose-per-week course schedule) with a list
// of "from week → to week → count" rows + an "add tramo" button. Used by
// AspirationEditor (treatments) and TreatmentEditor — same UI in both
// places, so this is the single source of truth.

struct DoseScheduleEditor: View {
    @Binding var schedule: [DoseStep]
    let defaultDose: Int
    let unit: String
    /// Caller-provided pluralisation (different domain types own their own
    /// static pluralize fn — `Aspiration.pluralize` vs `Treatment.pluralize`).
    let pluralize: (String) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(schedule.indices, id: \.self) { i in
                row(index: i)
            }
            Button {
                let last = schedule.last
                let nextFrom = (last?.toWeek ?? 0) + 1
                schedule.append(DoseStep(fromWeek: nextFrom,
                                         toWeek: nextFrom + 1,
                                         count: defaultDose))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Añadir tramo")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                .foregroundStyle(SimsTheme.frame)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if !schedule.isEmpty {
                Text("Si una semana no está cubierta, se usa la cantidad por defecto.")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func row(index: Int) -> some View {
        let step = schedule[index]
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Sem")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                    Stepper(value: $schedule[index].fromWeek, in: 1...52) {
                        Text("\(step.fromWeek)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .monospacedDigit()
                    }
                    .labelsHidden()
                    Text("a")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(SimsTheme.textSecondary)
                    // Custom binding here keeps the invariant `toWeek >= fromWeek`.
                    Stepper(value: Binding(
                        get: { schedule[index].toWeek },
                        set: { schedule[index].toWeek = max(schedule[index].fromWeek, $0) }
                    ), in: 1...52) {
                        Text("\(step.toWeek)")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                            .monospacedDigit()
                    }
                    .labelsHidden()
                }
                Stepper(value: $schedule[index].count, in: 1...20) {
                    Text("\(step.count) \(step.count == 1 ? unit : pluralize(unit))")
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
            }
            Button { schedule.remove(at: index) } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .simsFieldStyle()
    }
}
