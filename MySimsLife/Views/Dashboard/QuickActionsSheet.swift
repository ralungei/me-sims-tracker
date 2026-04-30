import SwiftUI

// MARK: - Custom Overlay (replaces system sheet — works identically on iPhone & iPad)

struct QuickActionsOverlay: View {
    let need: NeedType
    let onDismiss: () -> Void

    @Environment(NeedStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showContent = false
    @State private var showCustom = false

    private var isCompact: Bool { sizeClass == .compact }

    private let columns2 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
    private let columns3 = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var columns: [GridItem] { isCompact ? columns2 : columns3 }

    /// Cap the sheet at ~75% of the screen height so it never grows past
    /// the greeting/header area. Inner ScrollView handles the overflow.
    #if os(iOS)
    private var maxSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.75
    }
    #else
    private var maxSheetHeight: CGFloat { 720 }
    #endif

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
            // Drag handle (fixed at top)
            Capsule()
                .fill(SimsTheme.frame.opacity(0.4))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header (fixed at top)
            needHeader
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

            // Body — scrollable when many actions (e.g. Salud has lots of
            // negative options). Capped to ~70% of the screen height so the
            // sheet stops at a reasonable point and the user can scroll
            // the remaining content into view.
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
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
                            addCustomCard
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
            }
        }
        .frame(maxWidth: isCompact ? .infinity : 560)
        .frame(maxHeight: maxSheetHeight, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .fill(SimsTheme.backgroundGradient)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
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
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.55))
                            .overlay(Circle().stroke(SimsTheme.negativeTint.opacity(0.4), lineWidth: 1))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .simsFieldStyle()
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
                        .foregroundStyle(SimsTheme.barColor(for: val))
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
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SimsTheme.textPrimary)
                    .frame(height: 26)

                Text("Añadir")
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)

                Text("personalizada")
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundStyle(SimsTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(SimsTheme.panelPeriwinkle.opacity(0.6))
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
        let negBG = SimsTheme.negativeTint.opacity(0.18)
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(negative ? SimsTheme.negativeTint : SimsTheme.textPrimary)
                    .frame(height: 26)

                Text(action.localizedName)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(SimsTheme.textPrimary)
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
                    .fill(negative ? negBG : SimsTheme.panelPeriwinkle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(SimsTheme.frame, lineWidth: 1.2)
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
