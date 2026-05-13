import SwiftUI

// MARK: - Profile Editor (sheet)

/// Sheet for editing the user's profile. Single field today (`userName`);
/// the section/toolbar shape leaves room for avatar / cumple / pronouns
/// later without redesign.
struct ProfileEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("userName") private var savedName: String = ""

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        SimsEditorScaffold(
            title: "Perfil",
            isValid: !trimmedName.isEmpty,
            onSave: save
        ) {
            SimsSection("Nombre") { nameField }
        }
        .onAppear {
            name = savedName
            // Slight delay so the sheet animation finishes before the
            // keyboard pops — feels less jumpy.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                nameFocused = true
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("",
                      text: $name,
                      prompt: Text("Tu nombre").foregroundStyle(SimsTheme.textSecondary))
                .textFieldStyle(.plain)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .foregroundStyle(SimsTheme.textPrimary)
                .focused($nameFocused)
                .submitLabel(.done)
                .onSubmit { save() }
                .simsFieldStyle()

            Text("Aparece en el saludo cuando abres la app.")
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .padding(.leading, 4)
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        savedName = trimmedName
        dismiss()
    }
}

#Preview {
    ProfileEditor()
}
