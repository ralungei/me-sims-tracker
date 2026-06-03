import SwiftUI

// MARK: - Categories editor — toggles for each NeedType

/// Reusable list. Pass `embedded = true` cuando se usa dentro del onboarding (sin NavigationStack).
struct CategoriesEditor: View {
    @Environment(NeedStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var embedded: Bool = false

    /// How far the user has scrolled down inside the list, in points.
    /// Drives the top fade overlay (which only appears once there's
    /// content above the visible region).
    @State private var listScrollOffset: CGFloat = 0

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
        // Plan chips stay pinned at the top; only the per-need list
        // scrolls. The list mask fades BOTH ends so the row currently
        // crossing either edge doesn't get a hard chop on the periwinkle
        // background. Clear gap between the chip block and the list so
        // the two sections read as separate.
        VStack(spacing: 24) {
            planPicker
                .padding(.horizontal, 20)
                .padding(.top, 20)

            ScrollView {
                // Sentinel as the first child writes its position into a
                // preference, so SwiftUI gets a reliable per-frame scroll
                // signal — `background(GeometryReader)` on the VStack
                // missed updates when only the offset moved.
                VStack(spacing: 8) {
                    Color.clear
                        .frame(height: 0)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: ScrollOffsetKey.self,
                                        value: -proxy.frame(in: .named("needList")).minY
                                    )
                            }
                        )
                    ForEach(NeedType.sorted) { need in
                        row(need)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            .coordinateSpace(name: "needList")
            .onPreferenceChange(ScrollOffsetKey.self) { listScrollOffset = $0 }
            // Transparent mask — fades pixel alpha, doesn't add colour,
            // so the result blends with whatever gradient is behind it.
            // Top stop interpolates with scroll: clear at offset 0,
            // solid black by offset 12 → first row fades in gradually.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(min(1.0, max(0, listScrollOffset) / 12.0)),
                              location: 0.0),
                        .init(color: .black, location: 0.06),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    /// 2×2 grid of preset chips instead of horizontal scroll so all four
    /// tiers (Esencial / Equilibrado / Detallado / Completo) are visible
    /// at once without swiping.
    private var planPicker: some View {
        let active = NeedPlan.matching(store.enabledNeeds)
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10),
                      GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(NeedPlan.allCases) { plan in
                planChip(plan, isActive: active == plan)
            }
        }
    }

    private func planChip(_ plan: NeedPlan, isActive: Bool) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                store.applyPlan(plan)
            }
        } label: {
            HStack(spacing: 8) {
                SimsOutlinedIcon(systemName: plan.icon, size: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(plan.label)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(SimsTheme.textPrimary)
                    Text("\(plan.count) cat.")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(SimsTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
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

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
