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
                            .foregroundStyle(SimsTheme.textPrimary)
                        Spacer()
                        HStack(spacing: 3) {
                            Text("\(pct)")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .foregroundStyle(SimsTheme.valueColor(for: value))
                                .monospacedDigit()
                                .contentTransition(.numericText(value: value))
                            if critical {
                                Text("⚠")
                                    .font(.system(.caption, weight: .bold))
                                    .foregroundStyle(SimsTheme.valueColor(for: value))
                            }
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
                                Label("Eliminar \"\(rec.actionName)\"", systemImage: "arrow.uturn.backward")
                            }
                        }
                }
            }
            .padding(.top, 2)
        }
    }

    private func actionPill(_ rec: NeedStore.LastActionRecord, fresh: Bool) -> some View {
        let pillColor = Color(hue: hue/360, saturation: 0.40, brightness: 0.80)
        return HStack(spacing: 3) {
            Image(systemName: rec.icon)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(fresh ? pillColor : SimsTheme.textSecondary)
            Text(rec.actionName)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(fresh ? SimsTheme.textPrimary : SimsTheme.textSecondary)
            Text(rec.at.timeAgo(style: .short))
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(SimsTheme.textDim)
                .monospacedDigit()
        }
        .lineLimit(1)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(fresh
                    ? Color(hue: hue/360, saturation: 0.50, brightness: 0.20)
                    : Color.white.opacity(0.04))
        )
    }

    // MARK: - Tile (icon)

    private var tile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(SimsTheme.needTileGradient(hue: hue))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color(hue: hue/360, saturation: 0.7, brightness: 0.4).opacity(0.35), radius: 8, y: 3)
            Image(systemName: need.icon)
                .font(.system(size: tileSize * 0.42, weight: .bold))
                .foregroundStyle(Color(hue: hue/360, saturation: 0.45, brightness: 0.95))
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
        HStack(spacing: 3) {
            ForEach(0..<segments, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(i < filled ? AnyShapeStyle(fillBrush) : AnyShapeStyle(track))
                    .frame(height: pipHeight)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: filled)
    }
}

#Preview {
    ZStack {
        SimsTheme.mainBackground.ignoresSafeArea()
        VStack(spacing: 12) {
            NeedBarView(need: .energy,    value: 0.9)
            NeedBarView(need: .nutrition, value: 0.55)
            NeedBarView(need: .hydration, value: 0.18)
            NeedBarView(need: .social,    value: 0.31)
        }
        .padding()
    }
}
