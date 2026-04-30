import SwiftUI

// MARK: - Need Bar (v2-playful: chunky segmented pips, per-need hue)

struct NeedBarView: View {
    let need: NeedType
    let value: Double
    var recentActions: [NeedStore.LastActionRecord] = []
    var compact: Bool = true
    var onTap: () -> Void = {}
    var onRemoveAction: (Int) -> Void = { _ in }

    private let segments = 12

    private var hue: Double { need.hue }
    private var pct: Int { Int((value * 100).rounded()) }
    private var filled: Int { Int((value * Double(segments)).rounded()) }
    private var critical: Bool { value < 0.25 }

    private var fill: Color { SimsTheme.needFill(hue: hue, value: value) }
    private var track: Color { SimsTheme.needTrack(hue: hue) }

    private var pipHeight: CGFloat { compact ? 10 : 12 }
    private var tileSize: CGFloat { compact ? 40 : 46 }
    private var nameFont: Font {
        .system(compact ? .subheadline : .body, design: .rounded, weight: .bold)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: compact ? 12 : 14) {
                tile
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(need.displayName)
                            .font(nameFont)
                            .tracking(0.6)
                            .foregroundStyle(SimsTheme.textPrimary)
                        Spacer()
                        if critical {
                            Text("⚠")
                                .font(.system(.caption, weight: .bold))
                                .foregroundStyle(SimsTheme.valueColor(for: value))
                        }
                    }
                    pips
                    lastActionLabel
                }
            }
            .padding(.vertical, compact ? 4 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var lastActionLabel: some View {
        if !recentActions.isEmpty {
            HStack(spacing: 5) {
                ForEach(Array(recentActions.prefix(3).enumerated()), id: \.offset) { index, rec in
                    actionPill(rec, fresh: index == 0)
                        .contextMenu {
                            Button(role: .destructive) {
                                onRemoveAction(index)
                            } label: {
                                Label("Eliminar \"\(rec.localizedName)\"", systemImage: "arrow.uturn.backward")
                            }
                        }
                }
            }
            .padding(.top, 2)
        }
    }

    private func actionPill(_ rec: NeedStore.LastActionRecord, fresh: Bool) -> some View {
        _ = fresh   // recent / older chips render identically — neutral grey
        return HStack(spacing: 3) {
            Image(systemName: rec.icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(SimsTheme.textPrimary)
            Text(rec.localizedName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(SimsTheme.textPrimary)
            Text(rec.at.timeAgo(style: .short))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(SimsTheme.textSecondary)
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.55))
                .overlay(Capsule().stroke(SimsTheme.frame.opacity(0.35), lineWidth: 0.8))
        )
    }

    // MARK: - Tile (icon)

    private var tile: some View {
        // Sims-style icon: white fill with a navy outline. SF Symbols don't
        // have a native stroke, so we layer a slightly larger navy version
        // behind a slightly thinner white version to fake the outline.
        let stateColor = SimsTheme.valueColor(for: value)
        let iconSize = tileSize * 0.42
        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(
                    colors: [stateColor.opacity(0.85), stateColor.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SimsTheme.frame, lineWidth: 1.5)
                )
            // Outline (slightly bigger + heavier weight, navy).
            Image(systemName: need.icon)
                .font(.system(size: iconSize + 2, weight: .black))
                .foregroundStyle(SimsTheme.frame)
            // Fill (white, regular weight).
            Image(systemName: need.icon)
                .font(.system(size: iconSize, weight: .bold))
                .foregroundStyle(Color.white)
        }
        .frame(width: tileSize, height: tileSize)
    }

    // MARK: - Segmented pips

    /// One LinearGradient instance per fill state, built once per render of the
    /// bar instead of one per pip (12 allocations per bar previously).
    private var fillBrush: LinearGradient {
        LinearGradient(
            colors: [fill.opacity(0.85), fill],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var pips: some View {
        // Deep navy (#0E135B) — used both for the outer frame and the gaps
        // between pips so the bar reads as a sectioned gauge.
        let frame = Color(red: 0.055, green: 0.075, blue: 0.357)
        return HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                // First pip: round only the LEFT corners (outer cap).
                // Last pip:  round only the RIGHT corners (outer cap).
                // Inner pips: square; the navy gaps + frame do the rest.
                let isFirst = i == 0
                let isLast  = i == segments - 1
                let shape = UnevenRoundedRectangle(
                    topLeadingRadius:     isFirst ? 6 : 1,
                    bottomLeadingRadius:  isFirst ? 6 : 1,
                    bottomTrailingRadius: isLast  ? 6 : 1,
                    topTrailingRadius:    isLast  ? 6 : 1
                )
                shape
                    .fill(i < filled ? AnyShapeStyle(fillBrush) : AnyShapeStyle(track))
                    .frame(height: pipHeight)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(frame)
        )
        .animation(.easeInOut(duration: 0.25), value: filled)
    }
}

#Preview {
    ZStack {
        SimsTheme.background.ignoresSafeArea()
        VStack(spacing: 12) {
            NeedBarView(need: .energy,    value: 0.9)
            NeedBarView(need: .nutrition, value: 0.55)
            NeedBarView(need: .hydration, value: 0.18)
            NeedBarView(need: .social,    value: 0.31)
        }
        .padding()
    }
}
