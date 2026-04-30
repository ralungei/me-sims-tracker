import SwiftUI

// MARK: - Custom action sheet

/// One-shot form to log an action that isn't in the preset list. Not
/// persisted for now — fire-and-forget. Returns the assembled `QuickAction`
/// to the caller via `onLog` so the host can run it through `NeedStore`.
struct CustomActionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let need: NeedType
    let onLog: (QuickAction) -> Void

    @State private var name: String = ""
    @State private var isPositive: Bool = true
    @State private var size: ActionSize = .medium
    @State private var icon: String = "star.fill"

    enum ActionSize: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small:  return String(localized: "Pequeña")
            case .medium: return String(localized: "Mediana")
            case .large:  return String(localized: "Grande")
            }
        }
        /// Magnitude of the boost in percentage points. Sign comes from the
        /// positive/negative toggle.
        var magnitude: Double {
            switch self {
            case .small:  return 5
            case .medium: return 15
            case .large:  return 30
            }
        }
    }

    /// Compact set of SF Symbols that read well at small sizes — covers most
    /// common life-tracking categories.
    private let iconChoices: [String] = [
        "star.fill", "fork.knife", "drop.fill", "figure.run",
        "bed.double.fill", "person.2.fill", "book.fill", "music.note",
        "leaf.fill", "heart.fill", "brain.head.profile", "pills.fill",
        "moon.zzz.fill", "sun.max.fill", "cup.and.saucer.fill",
        "shower.fill", "soccerball", "cross.case.fill",
        "bubbles.and.sparkles.fill", "phone.fill", "gamecontroller.fill",
        "tv.fill", "camera.fill", "paintpalette.fill"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                SimsTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        section("Nombre") { nameField }
                        section("Tipo")   { kindField }
                        section("Tamaño") { sizeField }
                        section("Icono")  { iconField }
                        previewRow
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nueva acción")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Registrar") { commit() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .bold()
                }
            }
        }
    }

    // MARK: - Sections

    private func section<Content: View>(_ title: LocalizedStringKey,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(SimsTheme.textSecondary)
            content()
        }
    }

    private var nameField: some View {
        TextField("Ej: yoga, cena con Pablo, helado…", text: $name)
            .textFieldStyle(.plain)
            .padding(12)
            .simsFieldStyle()
            .foregroundStyle(SimsTheme.textPrimary)
    }

    private var kindField: some View {
        HStack(spacing: 8) {
            kindChip(label: "Positiva", systemImage: "plus.circle.fill",
                     selected: isPositive, tint: SimsTheme.accentGreen) {
                isPositive = true
            }
            kindChip(label: "Negativa", systemImage: "minus.circle.fill",
                     selected: !isPositive, tint: SimsTheme.negativeTint) {
                isPositive = false
            }
        }
    }

    private func kindChip(label: LocalizedStringKey,
                          systemImage: String,
                          selected: Bool,
                          tint: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .simsFieldStyle(selected: selected)
        }
        .buttonStyle(.plain)
    }

    private var sizeField: some View {
        HStack(spacing: 8) {
            ForEach(ActionSize.allCases) { s in
                Button { size = s } label: {
                    VStack(spacing: 4) {
                        Text(s.label)
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(SimsTheme.textPrimary)
                        Text("\(isPositive ? "+" : "−")\(Int(s.magnitude))%")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(SimsTheme.textSecondary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .simsFieldStyle(selected: size == s)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var iconField: some View {
        let columns = [GridItem(.adaptive(minimum: 48), spacing: 8)]
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(iconChoices, id: \.self) { sym in
                Button { icon = sym } label: {
                    Image(systemName: sym)
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 48, height: 48)
                        .foregroundStyle(SimsTheme.textPrimary)
                        .simsFieldStyle(cornerRadius: 12, selected: icon == sym)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var previewRow: some View {
        HStack(spacing: 10) {
            // Sims-style tile: state colour gradient + navy frame, white-on-navy icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: isPositive
                            ? [SimsTheme.accentGreen.opacity(0.85), SimsTheme.accentGreen.opacity(0.55)]
                            : [SimsTheme.negativeTint.opacity(0.85), SimsTheme.negativeTint.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(SimsTheme.frame, lineWidth: 1.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(SimsTheme.frame)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? String(localized: "Tu acción") : name)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                let signed = "\(isPositive ? "+" : "−")\(Int(size.magnitude))%"
                Text("\(signed) en \(need.displayName.lowercased())")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .simsFieldStyle(cornerRadius: 14)
    }

    // MARK: - Commit

    private func commit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let signed = (isPositive ? 1 : -1) * size.magnitude
        let action = QuickAction(name: trimmed, icon: icon, boost: signed, needType: need)
        onLog(action)
        dismiss()
    }
}
