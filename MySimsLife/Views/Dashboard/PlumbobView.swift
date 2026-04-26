import SwiftUI

// MARK: - Mood Disc — flat disc + thin VITAL ring, sims-style indicative color

struct PlumbobView: View {
    let mood: Double
    var compact: Bool = false
    var size: CGFloat? = nil

    private var color: Color { SimsTheme.plumbobColor(for: mood) }
    private var colorSoft: Color { color.opacity(0.65) }
    private var colorTop:  Color { color.opacity(1.0) }

    private var orbSize: CGFloat { size ?? (compact ? 84 : 110) }
    private var ringWidth: CGFloat { max(2, orbSize * 0.045) }

    var body: some View {
        ZStack {
            // VITAL ring — track
            Circle()
                .stroke(Color.white.opacity(0.07), lineWidth: ringWidth)
                .frame(width: orbSize * 1.05, height: orbSize * 1.05)

            // VITAL ring — fill (mood %)
            Circle()
                .trim(from: 0, to: max(0.02, mood))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: orbSize * 1.05, height: orbSize * 1.05)
                .animation(.spring(response: 0.7, dampingFraction: 0.8), value: mood)

            // Solid disc
            Circle()
                .fill(LinearGradient(colors: [colorTop, colorSoft],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: orbSize * 0.78, height: orbSize * 0.78)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5)
                )
        }
        .frame(width: orbSize * 1.2, height: orbSize * 1.2)
    }
}

#Preview {
    ZStack {
        SimsTheme.mainBackground.ignoresSafeArea()
        HStack(spacing: 30) {
            PlumbobView(mood: 0.90)
            PlumbobView(mood: 0.55)
            PlumbobView(mood: 0.30)
            PlumbobView(mood: 0.10)
        }
    }
}
