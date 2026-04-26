import SwiftUI

// MARK: - Custom Overlay (replaces system sheet — works identically on iPhone & iPad)

struct QuickActionsOverlay: View {
    let need: NeedType
    let onDismiss: () -> Void

    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showContent = false

    private var isCompact: Bool { sizeClass == .compact }

    private let columns2 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let columns3 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var columns: [GridItem] { isCompact ? columns2 : columns3 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Backdrop
            Color.black.opacity(showContent ? 0.55 : 0)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            // Content card
            if showContent {
                cardContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                showContent = true
            }
        }
    }

    // MARK: - Card

    private var cardContent: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header
            needHeader
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Recent actions — with delete button to undo mistakes
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

            // Positive actions
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("ACCIONES")

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(need.positiveActions) { action in
                        ActionCard(action: action, negative: false) {
                            performAction(action)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)

            // Negative actions
            if !need.negativeActions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("REGISTRAR NEGATIVO")

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(need.negativeActions) { action in
                            ActionCard(action: action, negative: true) {
                                performAction(action)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            Spacer().frame(height: 24)
        }
        .frame(maxWidth: isCompact ? .infinity : 560)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                        .fill(SimsTheme.panelBackground.opacity(0.85))
                )
                .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
        )
        .ignoresSafeArea(.container, edges: .bottom)
    }

    // MARK: - Recent row (with delete)

    private func recentRow(_ rec: NeedStore.LastActionRecord, index: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: rec.icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(rec.actionName)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white)
                Text(rec.at.timeAgo(style: .long))
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            Text("\(rec.boost > 0 ? "+" : "")\(Int(rec.boost))%")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(rec.boost > 0 ? SimsTheme.accentGreen : SimsTheme.negativeTint)
                .monospacedDigit()
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    store.removeRecentAction(for: need, at: index)
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SimsTheme.negativeTint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(SimsTheme.negativeTint.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Header

    private var needHeader: some View {
        HStack(spacing: 12) {
            let val = store.needs[need] ?? 0

            ZStack {
                Circle()
                    .fill(SimsTheme.barColor(for: val).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: need.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(SimsTheme.barColor(for: val))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(need.displayName)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08))
                            Capsule()
                                .fill(SimsTheme.barGradient(for: val))
                                .frame(width: max(0, geo.size.width * val))
                        }
                    }
                    .frame(width: 100, height: 8)
                    .clipShape(Capsule())

                    Text("\(Int(val * 100))%")
                        .font(SimsTheme.valueFont)
                        .foregroundStyle(SimsTheme.barColor(for: val))
                }
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(10)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .foregroundStyle(text.contains("NEGATIVO") ? SimsTheme.negativeTint.opacity(0.6) : .white.opacity(0.3))
            .tracking(1)
    }

    private func performAction(_ action: QuickAction) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            store.logAction(action, for: need)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
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
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(negative ? SimsTheme.negativeTint : .white)
                    .frame(height: 26)

                Text(action.name)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(negative ? "\(Int(action.boost))%" : "+\(Int(action.boost))%")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(negative ? SimsTheme.negativeTint : SimsTheme.accentGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(negative ? SimsTheme.moodletBackground.opacity(0.5) : SimsTheme.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                negative ? SimsTheme.negativeTint.opacity(0.15) : Color.white.opacity(0.05),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(BounceButtonStyle())
    }
}

#Preview {
    ZStack {
        SimsTheme.background.ignoresSafeArea()
        QuickActionsOverlay(need: .nutrition, onDismiss: {})
            .environment(NeedStore())
    }
}
