import SwiftUI

// MARK: - Treatment Editor (Botiquín — pills, supplements, vitamins)

struct TreatmentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let existing: Treatment?

    @State private var name: String = ""
    @State private var emoji: String = "💊"
    @State private var hue: Double = 195
    @State private var unit: String = ""
    @State private var defaultDose: Int = 1
    @State private var schedule: [DoseStep] = []
    @State private var hasFiniteCourse: Bool = false
    @State private var totalDays: Int = 30
    @State private var startDate: Date = Date()
    @State private var dosingMoment: DosingMoment? = nil
    @State private var hasReminder: Bool = false
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notify: Bool = false
    @State private var notes: String = ""

    private let suggestedEmojis = ["💊","💉","🧴","🌿","🍯","🥄","💧","🌱","🦠","🍵"]
    private let suggestedUnits = ["sobre", "cápsula", "comprimido", "pastilla", "gota", "ml", "g", "scoop"]
    private let huePresets: [Double] = [22, 38, 158, 195, 220, 258, 295, 335]

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        SimsEditorScaffold(
            title: existing == nil ? "Nuevo tratamiento" : "Editar",
            isValid: isValid,
            onSave: save
        ) {
            SimsSection("Nombre") { nameField }
            SimsSection("Emoji") { emojiField }
            SimsSection("Color") { hueField }
            SimsSection("Unidad") { unitField }
            if !unit.isEmpty {
                SimsSection("Cantidad por toma") { defaultDoseField }
            }
            SimsSection("Curso finito") { courseField }
            if hasFiniteCourse && !unit.isEmpty {
                SimsSection("Variación por semanas (opcional)") {
                    DoseScheduleEditor(schedule: $schedule,
                                       defaultDose: defaultDose,
                                       unit: unit,
                                       pluralize: Treatment.pluralize)
                }
            }
            SimsSection("Cuándo tomarla (opcional)") { dosingField }
            SimsSection("Recordatorio") { reminderSection }
            SimsSection("Notas (opcional)") { notesField }
            if existing != nil {
                SimsDeleteButton(label: "Eliminar tratamiento") {
                    if let existing {
                        NotificationManager.shared.cancelTreatmentReminder(treatmentID: existing.id)
                        modelContext.delete(existing)
                        try? modelContext.save()
                    }
                    dismiss()
                }
                .padding(.top, 12)
            }
        }
        .onAppear { loadIfExisting() }
    }

    // MARK: - Fields

    private var nameField: some View {
        TextField("",
                  text: $name,
                  prompt: Text("Ej: paracetamol, omega 3, vitamina D…")
                            .foregroundStyle(SimsTheme.textSecondary))
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var emojiField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("",
                      text: $emoji,
                      prompt: Text("💊").foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .font(.system(size: 28))
                .frame(width: 70, height: 56)
                .multilineTextAlignment(.center)
                .simsFieldStyle()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedEmojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Text(e)
                                .font(.system(size: 22))
                                .frame(width: 40, height: 40)
                                .simsFieldStyle(cornerRadius: 10, selected: emoji == e)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
    }

    private var hueField: some View {
        HStack(spacing: 10) {
            ForEach(huePresets, id: \.self) { h in
                Button { hue = h } label: {
                    Circle()
                        .fill(SimsTheme.hueSwatch(h))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(SimsTheme.frame, lineWidth: abs(hue - h) < 1 ? 2.5 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var unitField: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("",
                      text: $unit,
                      prompt: Text("sobre, cápsula, ml...")
                                .foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .padding(12)
                .simsFieldStyle()
                .foregroundStyle(SimsTheme.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestedUnits, id: \.self) { u in
                        Button { unit = (unit == u ? "" : u) } label: {
                            Text(u)
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .foregroundStyle(SimsTheme.textPrimary)
                                .simsChipStyle(selected: unit == u)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollClipDisabled()
            .padding(.horizontal, -20)
        }
    }

    private var defaultDoseField: some View {
        Stepper(value: $defaultDose, in: 1...20) {
            Text("\(defaultDose) \(defaultDose == 1 ? unit : Treatment.pluralize(unit))")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .simsFieldStyle()
    }

    private var courseField: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $hasFiniteCourse.animation()) {
                Text("Tiene un fin (X días)")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
            }
            .padding(12)
            .simsFieldStyle()

            if hasFiniteCourse {
                Stepper(value: $totalDays, in: 3...365, step: 1) {
                    Text("\(totalDays) días")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
                .padding(12)
                .simsFieldStyle()

                DatePicker("Empieza el", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tint(SimsTheme.frame)
                    .padding(12)
                    .simsFieldStyle()
            }
        }
    }

    private var dosingField: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SimsSelectableChip(label: String(localized: "ninguno"),
                                   icon: "minus",
                                   isSelected: dosingMoment == nil) {
                    dosingMoment = nil
                }
                ForEach(DosingMoment.allCases, id: \.self) { m in
                    SimsSelectableChip(label: m.label,
                                       icon: m.icon,
                                       isSelected: dosingMoment == m) {
                        dosingMoment = m
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -20)
    }

    private var reminderSection: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $hasReminder.animation()) {
                Text("Hora exacta")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
            }
            .padding(12)
            .simsFieldStyle()

            if hasReminder {
                DatePicker("Hora", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tint(SimsTheme.frame)
                    .padding(12)
                    .simsFieldStyle()

                Toggle(isOn: $notify) {
                    Text("Recordármelo")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
                .padding(12)
                .simsFieldStyle()
            }
        }
    }

    private var notesField: some View {
        TextField("",
                  text: $notes,
                  prompt: Text("Posología, marca, instrucciones...")
                            .foregroundStyle(SimsTheme.textSecondary),
                  axis: .vertical)
            .lineLimit(3...8)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    // MARK: - Helpers

    private func loadIfExisting() {
        guard let t = existing else { return }
        name = t.name
        emoji = t.emoji
        hue = t.hue
        unit = t.unit
        defaultDose = t.defaultDose
        schedule = t.schedule
        if let total = t.totalDays {
            hasFiniteCourse = true
            totalDays = total
            startDate = t.startedAt ?? Date()
        }
        dosingMoment = t.dosingMoment
        if let r = t.reminderTime {
            hasReminder = true
            reminderTime = r
        }
        notify = t.notify
        notes = t.notes ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let safeEmoji = emoji.isEmpty ? "💊" : emoji
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
        let trimmedUnit = unit.trimmingCharacters(in: .whitespaces)
        let resolvedSchedule = (trimmedUnit.isEmpty || !hasFiniteCourse) ? [] : schedule
        let resolvedReminder: Date? = hasReminder ? reminderTime : nil
        let resolvedNotify = notify && hasReminder

        let treatment: Treatment
        if let existing {
            existing.name = trimmedName
            existing.emoji = safeEmoji
            existing.hue = hue
            existing.unit = trimmedUnit
            existing.defaultDose = defaultDose
            existing.schedule = resolvedSchedule
            existing.totalDays = hasFiniteCourse ? totalDays : nil
            existing.startedAt = hasFiniteCourse ? startDate : nil
            existing.dosingMoment = dosingMoment
            existing.reminderTime = resolvedReminder
            existing.notify = resolvedNotify
            existing.notes = resolvedNotes
            treatment = existing
        } else {
            treatment = Treatment(name: trimmedName,
                                  emoji: safeEmoji,
                                  hue: hue,
                                  unit: trimmedUnit,
                                  defaultDose: defaultDose,
                                  schedule: resolvedSchedule,
                                  totalDays: hasFiniteCourse ? totalDays : nil,
                                  startedAt: hasFiniteCourse ? startDate : nil,
                                  dosingMoment: dosingMoment,
                                  reminderTime: resolvedReminder,
                                  notify: resolvedNotify,
                                  notes: resolvedNotes)
            modelContext.insert(treatment)
        }
        try? modelContext.save()

        if resolvedNotify, let r = resolvedReminder {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: r)
            if let hour = comps.hour, let minute = comps.minute {
                let today = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? r
                NotificationManager.shared.scheduleTreatmentReminder(
                    treatmentID: treatment.id,
                    title: trimmedName,
                    at: today)
            }
        } else {
            NotificationManager.shared.cancelTreatmentReminder(treatmentID: treatment.id)
        }

        dismiss()
    }
}
