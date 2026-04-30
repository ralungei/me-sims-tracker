import SwiftUI

// MARK: - Dashboard tabs

enum DashboardTab: String, CaseIterable, Identifiable {
    case needs, aspirations, agenda

    var id: String { rawValue }

    var label: String {
        switch self {
        case .needs:        return String(localized: "Necesidades")
        case .aspirations:  return String(localized: "Aspiraciones")
        case .agenda:       return String(localized: "Agenda")
        }
    }

    var icon: String {
        switch self {
        case .needs:        return "brain.filled.head.profile"
        case .aspirations:  return "flag.pattern.checkered"
        case .agenda:       return "checklist"
        }
    }
}

// MARK: - Sims-style arc cluster

/// Three icon chips arranged on an arc that ascends from lower-right to
/// upper-left, with the chord bulging downward. Always pegs to the bottom-LEFT
/// corner of the plumbob — the host view aligns `chipCenter(at: 1)` to that
/// corner via `.offset`. Plumbob lives at the trailing edge of the header.
struct SimsTabBar: View {
    @Binding var selection: DashboardTab
    var compact: Bool = false

    /// Diameter of the active chip. Inactive chips render slightly smaller
    /// (`inactiveChipSize`) so the selection pops without changing the
    /// layout grid (centres remain spaced by `chipSize`).
    var chipSize: CGFloat   { compact ? 33 : 39 }
    private var inactiveChipSize: CGFloat { chipSize - 4 }
    private var iconSize: CGFloat   { compact ? 14 : 15 }
    private var radius: CGFloat     { compact ? 50 : 56 }
    private var stepDeg: Double     { 48 }
    /// 95° + step +48° traces an arc through the lower-left quadrant: chip 0
    /// at the lower-right (closest to the plumbob), chips ascending to the
    /// upper-left, chord bulging downward.
    private let startDeg: Double = 95
    private var step: Double { stepDeg }
    // Active colour now lives in `SimsTheme.tabActive`.

    /// Visual order around the arc, top → bottom in the cluster: Necesidades
    /// at the top, Aspiraciones in the middle, Agenda anchored at the bottom
    /// (closest to the plumbob).
    private var tabs: [DashboardTab] { DashboardTab.allCases.reversed() }

    private var layout: (positions: [CGPoint], size: CGSize) {
        let centres = tabs.indices.map { i -> CGPoint in
            let θ = (startDeg + step * Double(i)) * .pi / 180
            return CGPoint(x: CGFloat(cos(θ)) * radius,
                           y: CGFloat(sin(θ)) * radius)
        }
        let topLefts = centres.map {
            CGPoint(x: $0.x - chipSize / 2, y: $0.y - chipSize / 2)
        }
        let minX = topLefts.map(\.x).min() ?? 0
        let minY = topLefts.map(\.y).min() ?? 0
        // Reserve label space on the LEFT (label sits next to the active
        // chip, which is on the right side of the cluster).
        let leftPad: CGFloat = labelSpace
        let normalized = topLefts.map {
            CGPoint(x: $0.x - minX + leftPad, y: $0.y - minY)
        }
        let chipsMaxX = normalized.map(\.x).max() ?? 0
        let chipsMaxY = normalized.map(\.y).max() ?? 0
        return (normalized,
                CGSize(width: chipsMaxX + chipSize,
                       height: chipsMaxY + chipSize))
    }

    /// Top-left of chip `index` within the bar's frame.
    func chipTopLeft(at index: Int) -> CGPoint { layout.positions[index] }

    /// Centre of chip `index` within the bar's frame.
    func chipCenter(at index: Int) -> CGPoint {
        let p = layout.positions[index]
        return CGPoint(x: p.x + chipSize / 2, y: p.y + chipSize / 2)
    }

    /// Toggle to bring back the inline tab name to the left of the active
    /// chip. Currently false because the large `tabTitle` above the content
    /// already names the active section.
    private static let showInlineLabel: Bool = false
    /// When the inline label is hidden we don't need to reserve horizontal
    /// space for it; collapse to 0 so the cluster sits flush against the
    /// plumbob without an empty gutter on the left.
    private var labelSpace: CGFloat {
        guard Self.showInlineLabel else { return 0 }
        return compact ? 118 : 130
    }
    private var labelTracking: CGFloat { compact ? 1.0 : 1.4 }
    /// Approximate caption2 line height; used to bottom-align the label.
    private static let labelHeight: CGFloat = 14

    var totalSize: CGSize { layout.size }

    var body: some View {
        let l = layout
        let activePos = l.positions[activeIndex]
        ZStack(alignment: .topLeading) {
            ForEach(Array(tabs.enumerated()), id: \.element.id) { idx, tab in
                chip(tab)
                    .offset(x: l.positions[idx].x, y: l.positions[idx].y)
            }

            // Inline label hidden — the large `tabTitle` heading already names
            // the active section. Keeping the rendering path commented-in so
            // it can come back by flipping `showInlineLabel`.
            if Self.showInlineLabel {
                let labelY: CGFloat = activeIndex == 0
                    ? activePos.y + chipSize - Self.labelHeight
                    : activePos.y + (chipSize - Self.labelHeight) / 2
                let labelW: CGFloat = labelSpace - 6
                Text(selection.label.uppercased())
                    .font(.system(.caption2, design: .rounded, weight: .heavy))
                    .tracking(labelTracking)
                    .foregroundStyle(SimsTheme.tabActive)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: labelW, alignment: .trailing)
                    .offset(x: activePos.x - 6 - labelW, y: labelY)
                    .id(selection)
                    .transition(.opacity)
            }
        }
        .frame(width: l.size.width,
               height: l.size.height,
               alignment: .topLeading)
        .animation(.spring(response: 0.4, dampingFraction: 0.78), value: selection)
    }

    private var activeIndex: Int { tabs.firstIndex(of: selection) ?? 0 }

    private func chip(_ tab: DashboardTab) -> some View {
        let active = tab == selection
        let diameter = active ? chipSize : inactiveChipSize
        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                selection = tab
            }
        } label: {
            // Render at `diameter`; centre stays at the layout grid (`chipSize`)
            // so positions don't shift when selection changes.
            ZStack {
                Circle()
                    .fill(active
                          ? AnyShapeStyle(LinearGradient(
                              colors: [SimsTheme.tabActive,
                                       SimsTheme.tabActive.opacity(0.78)],
                              startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.06)))
                    .overlay(
                        Circle().stroke(
                            active ? Color.white.opacity(0.35) : Color.white.opacity(0.10),
                            lineWidth: 1
                        )
                    )
                    .frame(width: diameter, height: diameter)
                Image(systemName: tab.icon)
                    .font(.system(size: active ? iconSize : iconSize - 1, weight: .black))
                    .foregroundStyle(active ? Color.black.opacity(0.85)
                                            : SimsTheme.textSecondary.opacity(0.70))
            }
            .frame(width: chipSize, height: chipSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
    }
}

#Preview {
    @Previewable @State var sel: DashboardTab = .needs
    ZStack(alignment: .topLeading) {
        SimsTheme.background.ignoresSafeArea()
        Rectangle()
            .stroke(.red, lineWidth: 1)
            .frame(width: 78, height: 78)
            .padding(40)
        let bar = SimsTabBar(selection: $sel)
        bar
            .offset(x: 40 + 78 - bar.chipCenter(at: 1).x,
                    y: 40 + 78 - bar.chipCenter(at: 1).y)
    }
}
