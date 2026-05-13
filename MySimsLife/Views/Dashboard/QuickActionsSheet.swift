import SwiftUI

// MARK: - Quick Actions Sheet — system bottom sheet (covers the tab bar)

/// Presented via `.sheet(item:)` from DashboardView. Using a system sheet
/// (rather than a custom in-line ZStack overlay) means it covers the system
/// tab bar, gets free drag-to-dismiss, native animations, and detents.
struct QuickActionsOverlay: View {
    let need: NeedType
    let onDismiss: () -> Void

    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var systemDismiss
    @State private var showCustom = false

    private var isCompact: Bool { sizeClass == .compact }

    private let columns2 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let columns3 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var columns: [GridItem] { isCompact ? columns2 : columns3 }

    var body: some View {
        ZStack {
            SimsTheme.backgroundGradient.ignoresSafeArea()
            cardContent
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Header (fixed at top — system sheet provides its own grabber).
            needHeader
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

            ScrollView(.vertical, showsIndicators: false) {
                bodyContent
            }
        }
        .frame(maxWidth: isCompact ? .infinity : 560, alignment: .top)
    }

    /// Inner body content (recents + positive actions + negative actions).
    /// Reused by both branches of the `ViewThatFits` above.
    private var bodyContent: some View {
        VStack(spacing: 0) {
            let recents = store.recentActions(for: need)
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("RECIENTES")
                    VStack(spacing: 6) {
                        ForEach(Array(recents.enumerated()), id: \.offset) { index, rec in
                            recentRow(rec, index: index)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("ACCIONES")
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(need.positiveActions) { action in
                        ActionCard(action: action, negative: false) {
                            performAction(action)
                        }
                    }
                    ForEach(need.negativeActions) { action in
                        ActionCard(action: action, negative: true) {
                            performAction(action)
                        }
                    }
                    addCustomCard
                }
            }
            .padding(.horizontal, 20)

            Spacer().frame(height: 24)
        }
    }

    // MARK: - Recent row (with delete)

    private func recentRow(_ rec: NeedStore.LastActionRecord, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rec.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(rec.localizedName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                Text(rec.at.timeAgo(style: .long))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            Spacer()
            Text("\(rec.boost > 0 ? "+" : "")\(Int(rec.boost))%")
                .font(.system(.caption, design: .rounded, weight: .heavy))
                .foregroundStyle(rec.boost > 0 ? SimsTheme.boostPositive : SimsTheme.boostNegative)
                .monospacedDigit()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.removeRecentAction(for: need, at: index)
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SimsTheme.frame)
                    .frame(width: 30, height: 30)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Circle().stroke(SimsTheme.frame.opacity(0.4), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Deshacer \(rec.localizedName)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .simsFieldStyle()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Header

    private var needHeader: some View {
        HStack(spacing: 12) {
            let val = store.needs[need] ?? 0
            let stateColor = SimsTheme.valueColor(for: val)

            // Sims-style tile: gradient state colour + navy frame, white-on-navy icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [stateColor.opacity(0.85), stateColor.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SimsTheme.frame, lineWidth: 1.5)
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: need.icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(SimsTheme.frame)
                Image(systemName: need.icon)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(need.displayName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(SimsTheme.textPrimary)

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(SimsTheme.frame.opacity(0.25))
                            Capsule()
                                .fill(SimsTheme.barGradient(for: val))
                                .frame(width: max(0, geo.size.width * val))
                        }
                    }
                    .frame(width: 100, height: 8)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(SimsTheme.frame, lineWidth: 1))

                    Text("\(Int(val * 100))%")
                        .font(SimsTheme.valueFont)
                        // Use the legible boost reds/greens (calibrated for
                        // periwinkle bg) instead of the bright moodlet
                        // palette which washes out at low values.
                        .foregroundStyle(val < 0.45
                                         ? SimsTheme.boostNegative
                                         : (val >= 0.6 ? SimsTheme.boostPositive : SimsTheme.frame))
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(SimsTheme.textSecondary)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Circle().stroke(SimsTheme.frame.opacity(0.5), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .heavy))
            .foregroundStyle(text.contains("NEGATIVO") ? SimsTheme.negativeTint : SimsTheme.textSecondary)
            .tracking(1.2)
    }

    private func performAction(_ action: QuickAction) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            store.logAction(action, for: need)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    /// Tile that opens the custom-action sheet. Mirrors `ActionCard`'s sizing
    /// (3-line VStack, same padding + corner radius) so it slots perfectly
    /// into the grid.
    private var addCustomCard: some View {
        Button { showCustom = true } label: {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .frame(height: 26)

                Text("Añadir personalizada")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SimsTheme.panelPeriwinkle.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SimsTheme.frame,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
        .sheet(isPresented: $showCustom) {
            CustomActionSheet(need: need) { custom in
                performAction(custom)
            }
            .environment(store)
        }
    }

    private func dismiss() {
        // System sheet handles the dismissal animation.
        systemDismiss()
        onDismiss()
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let action: QuickAction
    let negative: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .frame(height: 26)

                Text(action.localizedName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(negative ? "\(Int(action.boost))%" : "+\(Int(action.boost))%")
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .foregroundStyle(negative
                                     ? SimsTheme.boostNegative
                                     : SimsTheme.boostPositive)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SimsTheme.panelPeriwinkle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SimsTheme.frame, lineWidth: 1.2)
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
        // Fold the icon, name, and boost stack into one focusable item so
        // VoiceOver speaks "Coffee, plus 18 percent" instead of three pieces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(action.localizedName))
        .accessibilityValue(Text(negative
                                 ? "menos \(Int(abs(action.boost))) por ciento"
                                 : "más \(Int(action.boost)) por ciento"))
        .accessibilityHint(Text("Toca dos veces para registrar"))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    ZStack {
        SimsTheme.background.ignoresSafeArea()
        QuickActionsOverlay(need: .nutrition, onDismiss: {})
            .environment(NeedStore())
    }
}
