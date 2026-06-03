import SwiftUI

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NeedStore.self) private var store

    let existing: LifeTask?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasSpecificTime: Bool = false
    @State private var dueTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var notify: Bool = false

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        SimsEditorScaffold(
            title: existing == nil ? "Nueva tarea" : "Editar tarea",
            isValid: isValid,
            onSave: save
        ) {
            SimsSection("Tarea") { titleField }
            SimsSection("Cuándo") { whenFields }
            // Only offer the reminder toggle once there's a specific time —
            // `save()` ignores `notify` without one, so showing it earlier
            // would be a control that silently does nothing.
            if hasDueDate && hasSpecificTime {
                SimsSection("Notificación") { notifyField }
            }
            SimsSection("Notas") { notesField }
            if existing != nil {
                SimsDeleteButton(label: "Eliminar tarea") {
                    if let existing { store.deleteTask(existing) }
                    dismiss()
                }
                .padding(.top, 12)
            }
        }
        .onAppear { loadIfExisting() }
    }

    private var titleField: some View {
        TextField("",
                  text: $title,
                  prompt: Text("Ej: Llamar al dentista")
                            .foregroundStyle(SimsTheme.textSecondary))
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var whenFields: some View {
        VStack(spacing: 8) {
            Toggle(isOn: $hasDueDate.animation()) {
                Text("Fecha específica")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
            }
            .padding(12)
            .simsFieldStyle()

            if hasDueDate {
                DatePicker("Fecha", selection: $dueDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    // Forced dark colour scheme on the WindowGroup makes
                    // DatePicker's built-in label render system-white.
                    // Override to navy so it matches the rest of the
                    // editor's body copy.
                    .foregroundStyle(SimsTheme.textPrimary)
                    .tint(SimsTheme.frame)
                    .padding(12)
                    .simsFieldStyle()

                Toggle(isOn: $hasSpecificTime.animation()) {
                    Text("Hora específica")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textPrimary)
                }
                .padding(12)
                .simsFieldStyle()

                if hasSpecificTime {
                    DatePicker("Hora", selection: $dueTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.compact)
                        .foregroundStyle(SimsTheme.textPrimary)
                        .tint(SimsTheme.frame)
                        .padding(12)
                        .simsFieldStyle()
                }
            }
        }
    }

    private var notifyField: some View {
        Toggle(isOn: $notify) {
            Text("Recordármelo")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(SimsTheme.textPrimary)
        }
        .padding(12)
        .simsFieldStyle()
    }

    private var notesField: some View {
        TextField("",
                  text: $notes,
                  prompt: Text("Opcional")
                            .foregroundStyle(SimsTheme.textSecondary),
                  axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private func loadIfExisting() {
        guard let task = existing else { return }
        title = task.title
        notes = task.notes ?? ""
        if let due = task.dueDate {
            hasDueDate = true
            dueDate = due
            hasSpecificTime = task.hasSpecificTime
            dueTime = due
        }
        notify = task.notify
    }

    /// Combine `dueDate` (date) + `dueTime` (time) into a single Date if the
    /// user opted for both; otherwise the date alone (start-of-day).
    private func resolvedDueDate() -> Date? {
        guard hasDueDate else { return nil }
        let cal = Calendar.current
        let dateComps = cal.dateComponents([.year, .month, .day], from: dueDate)
        if hasSpecificTime {
            let timeComps = cal.dateComponents([.hour, .minute], from: dueTime)
            var combined = DateComponents()
            combined.year = dateComps.year
            combined.month = dateComps.month
            combined.day = dateComps.day
            combined.hour = timeComps.hour
            combined.minute = timeComps.minute
            return cal.date(from: combined) ?? dueDate
        }
        return cal.startOfDay(for: dueDate)
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let resolvedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
        let resolvedDue = resolvedDueDate()
        let shouldNotify = notify && resolvedDue != nil && hasSpecificTime

        if let existing {
            existing.title = trimmedTitle
            existing.notes = resolvedNotes
            existing.dueDate = resolvedDue
            existing.notify = shouldNotify
            store.updateTask(existing)
        } else {
            let task = LifeTask(title: trimmedTitle,
                                dueDate: resolvedDue,
                                notes: resolvedNotes,
                                notify: shouldNotify)
            store.addTask(task)
        }

        dismiss()
    }
}
