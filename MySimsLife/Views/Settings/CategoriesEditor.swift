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
                .toolbarBackground(SimsTheme.panelPeriwinkle, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
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
            VStack(spacing: 12) {
                planPicker
                VStack(spacing: 8) {
                    ForEach(NeedType.sorted) { need in
                        row(need)
                    }
                }
            }
            .padding(20)
        }
    }

    /// Four-chip preset selector. Tapping overwrites `enabledNeeds`; the
    /// chip whose set matches the current selection lights up (none if the
    /// user has a custom mix). Shared between onboarding and Ajustes.
    private var planPicker: some View {
        let active = NeedPlan.matching(store.enabledNeeds)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(NeedPlan.allCases) { plan in
                    planChip(plan, isActive: active == plan)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.horizontal, -20)
        .scrollClipDisabled()
    }

    private func planChip(_ plan: NeedPlan, isActive: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                store.applyPlan(plan)
            }
        } label: {
            VStack(spacing: 4) {
                SimsOutlinedIcon(systemName: plan.icon, size: 16)
                    .padding(.bottom, 2)

                Text(plan.label)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text("\(plan.count) cat.")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            .frame(width: 92)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .simsChipStyle(selected: isActive)
        }
        .buttonStyle(.plain)
    }

    private func row(_ need: NeedType) -> some View {
        let isOn = store.enabledNeeds.contains(need)
        let bind = Binding<Bool>(
            get: { store.enabledNeeds.contains(need) },
            set: { store.setEnabled($0, for: need) }
        )
        return HStack(spacing: 12) {
            ZStack {
                SimsTintedTile(tint: SimsTheme.valueColor(for: 0.85), cornerRadius: 12, lineWidth: 1.2)
                    .frame(width: 36, height: 36)
                SimsOutlinedIcon(systemName: need.icon, size: 14)
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
        .simsFieldStyle(cornerRadius: 10)
        .opacity(isOn ? 1.0 : 0.55)
    }

    private func subtitle(for need: NeedType) -> String {
        switch need {
        case .health:        return String(localized: "No baja sola, solo cuando lo registras")
        case .mentalHealth:  return String(localized: "Calma, ánimo, estrés")
        case .energy:        return String(localized: "Sueño, siestas, cansancio")
        case .nutrition:     return String(localized: "Comidas y snacks")
        case .hydration:     return String(localized: "Agua, té, café")
        case .bladder:       return String(localized: "Pis y caca")
        case .exercise:      return String(localized: "Movimiento del día")
        case .hygiene:       return String(localized: "Ducha, dientes, skincare")
        case .environment:   return String(localized: "Orden y limpieza del espacio")
        case .social:        return String(localized: "Tiempo con gente")
        case .leisure:       return String(localized: "Hobbies, descanso, diversión")
        }
    }
}
