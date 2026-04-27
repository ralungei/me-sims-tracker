import SwiftUI

// MARK: - Categories editor — toggles for each NeedType

/// Reusable list. Pass `embedded = true` cuando se usa dentro del onboarding (sin NavigationStack).
struct CategoriesEditor: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var embedded: Bool = false

    var body: some View {
        if embedded {
            scrollContent
        } else {
            NavigationStack {
                ZStack {
                    SimsTheme.mainBackground.ignoresSafeArea()
                    scrollContent
                }
                .navigationTitle("Categorías")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { dismiss() }.bold()
                    }
                }
            }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(NeedType.sorted) { need in
                    row(need)
                }
            }
            .padding(20)
        }
    }

    private func row(_ need: NeedType) -> some View {
        let isOn = store.enabledNeeds.contains(need)
        let bind = Binding<Bool>(
            get: { store.enabledNeeds.contains(need) },
            set: { store.setEnabled($0, for: need) }
        )
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(SimsTheme.needTileGradient(hue: need.hue))
                    .frame(width: 36, height: 36)
                Image(systemName: need.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(hue: need.hue/360, saturation: 0.45, brightness: 0.95))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(need.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(subtitle(for: need))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textDim)
            }
            Spacer()
            Toggle("", isOn: bind)
                .labelsHidden()
                .tint(SimsTheme.accentPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isOn ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
        )
    }

    private func subtitle(for need: NeedType) -> String {
        switch need {
        case .health:      return "No baja sola, solo cuando lo registras"
        case .energy:      return "Sueño, siestas, cansancio"
        case .nutrition:   return "Comidas y snacks"
        case .hydration:   return "Agua, té, café"
        case .bladder:     return "Idas al baño, control intestinal"
        case .exercise:    return "Movimiento del día"
        case .hygiene:     return "Ducha, dientes, skincare"
        case .environment: return "Orden y limpieza del espacio"
        case .social:      return "Tiempo con gente"
        case .leisure:     return "Hobbies, ocio, descanso mental"
        }
    }
}
