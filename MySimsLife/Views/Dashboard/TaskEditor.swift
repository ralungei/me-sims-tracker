import SwiftUI

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(NeedStore.self) private var store

    let existing: LifeTask?

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Tarea") {
                            TextField("Ej: Llamar al dentista", text: $title)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .simsFieldStyle()
                                .foregroundStyle(SimsTheme.textPrimary)
                        }

                        section("Cuándo") {
                            Toggle(isOn: $hasDueDate.animation()) {
                                Text("Hora específica")
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .foregroundStyle(SimsTheme.textPrimary)
                            }
                            .padding(12)
                            .simsFieldStyle()

                            if hasDueDate {
                                DatePicker("Fecha y hora", selection: $dueDate)
                                    .datePickerStyle(.compact)
                                    .padding(12)
                                    .simsFieldStyle()
                            }
                        }

                        section("Notas") {
                            TextField("Opcional", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .simsFieldStyle()
                                .foregroundStyle(SimsTheme.textPrimary)
                        }

                        if existing != nil {
                            Button(role: .destructive) {
                                if let existing { store.deleteTask(existing) }
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Eliminar tarea")
                                }
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .foregroundStyle(SimsTheme.negativeTint)
                                .background(RoundedRectangle(cornerRadius: 12).fill(SimsTheme.negativeTint.opacity(0.10)))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 12)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(existing == nil
                             ? Text("Nueva tarea")
                             : Text("Editar tarea"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
        .onAppear { loadIfExisting() }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(SimsTheme.textSecondary)
            content()
        }
    }

    private func loadIfExisting() {
        guard let task = existing else { return }
        title = task.title
        notes = task.notes ?? ""
        if let due = task.dueDate {
            hasDueDate = true
            dueDate = due
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let resolvedNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
        let resolvedDue: Date? = hasDueDate ? dueDate : nil

        if let task = existing {
            task.title = trimmedTitle
            task.notes = resolvedNotes
            task.dueDate = resolvedDue
            store.updateTask(task)
        } else {
            let task = LifeTask(title: trimmedTitle, dueDate: resolvedDue, notes: resolvedNotes)
            store.addTask(task)
        }
        dismiss()
    }
}
