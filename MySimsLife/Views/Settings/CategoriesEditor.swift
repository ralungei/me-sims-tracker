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
                    SimsTheme.background.ignoresSafeArea()
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
                    .fill(LinearGradient(
                        colors: [SimsTheme.valueColor(for: 0.85).opacity(0.85),
                                 SimsTheme.valueColor(for: 0.85).opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SimsTheme.frame, lineWidth: 1.2)
                    )
                    .frame(width: 36, height: 36)
                // Sims-style: navy outline behind white fill (same trick as NeedBarView.tile)
                Image(systemName: need.icon)
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(SimsTheme.frame)
                Image(systemName: need.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(need.displayName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .tracking(0.4)
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(subtitle(for: need))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            Spacer()
            Toggle("", isOn: bind)
                .labelsHidden()
                .tint(SimsTheme.accentPrimary)
        }
        .padding(12)
        .simsFieldStyle(cornerRadius: 14)
        .opacity(isOn ? 1.0 : 0.55)
    }

    private func subtitle(for need: NeedType) -> String {
        switch need {
        case .health:      return String(localized: "No baja sola, solo cuando lo registras")
        case .energy:      return String(localized: "Sueño, siestas, cansancio")
        case .nutrition:   return String(localized: "Comidas y snacks")
        case .hydration:   return String(localized: "Agua, té, café")
        case .bladder:     return String(localized: "Idas al baño, control intestinal")
        case .exercise:    return String(localized: "Movimiento del día")
        case .hygiene:     return String(localized: "Ducha, dientes, skincare")
        case .environment: return String(localized: "Orden y limpieza del espacio")
        case .social:      return String(localized: "Tiempo con gente")
        case .leisure:     return String(localized: "Hobbies, ocio, descanso mental")
        }
    }
}
