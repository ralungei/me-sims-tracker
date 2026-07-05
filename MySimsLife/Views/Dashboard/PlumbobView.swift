import SwiftUI

// MARK: - Mood Plumbob — procedural 3D bipyramid, software-projected
//
// This used to be a SceneKit scene. Two reasons it isn't anymore:
// SceneKit is deprecated as of iOS 26, and its simulator renderer produces
// blank/black frames on some runtime combinations (iOS 18.3 under Xcode 26).
// The gem is just 12 flat-shaded triangles — projecting them by hand into a
// SwiftUI Canvas is cheap, runs identically on iOS/macOS and every
// simulator, and keeps the exact geometry, spin/bob motion and light rig
// the SceneKit version had.

struct PlumbobView: View {
    let mood: Double
    var compact: Bool = false
    var size: CGFloat? = nil
    /// Height-to-width ratio of the drawing frame. Default 1.15 leaves
    /// breathing room above/below the gem for the dashboard layout; the
    /// onboarding passes a tighter value to crop the empty vertical space
    /// when the plumbob is the hero.
    var aspectRatio: CGFloat = 1.15

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color { SimsTheme.plumbobColor(for: mood) }
    private var orbSize: CGFloat { size ?? (compact ? 78 : 104) }

    var body: some View {
        // 30 fps cap for parity with the old SCNView's
        // preferredFramesPerSecond — the gem lives permanently on the
        // dashboard, so free-running at ProMotion's 120 Hz would quadruple
        // the (small) per-frame work for no visible gain. Under Reduce
        // Motion the timeline pauses and the gem holds a fixed, well-lit
        // pose instead of spinning.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0,
                                paused: reduceMotion)) { timeline in
            Canvas { ctx, canvasSize in
                PlumbobRenderer.draw(
                    in: ctx,
                    size: canvasSize,
                    base: PlumbobRenderer.rgb(of: color),
                    time: reduceMotion
                        ? 1.2   // static pose: mid-bob, facets angled to the key light
                        : timeline.date.timeIntervalSinceReferenceDate
                )
            }
        }
        .frame(width: orbSize, height: orbSize * aspectRatio)
        .accessibilityElement()
        .accessibilityLabel(Text("VITAL"))
        .accessibilityValue(Text(mood.accessibilityNeedValue))
    }
}

// MARK: - Renderer

enum PlumbobRenderer {

    typealias RGB = SIMD3<Double>

    // Geometry — same proportions as the old SCNGeometry bipyramid.
    private static let apexH = 1.55
    private static let radius = 0.78
    private static let segments = 6

    // Camera — matches the old SCNCamera (z = 5.6, vertical FOV 32°).
    private static let camZ = 5.6
    private static let fovDeg = 32.0

    // Motion — same periods as the old CABasicAnimations.
    private static let spinPeriod = 9.0
    private static let bobPeriod = 2.4
    private static let bobAmplitude = 0.08

    // Light rig — key + cool fill + ambient, plus the two slow directional
    // "sweeps" that travel highlights across the facets (these are what
    // make the gem feel alive rather than statically lit).
    private static let keyDir = normalize(SIMD3(0.45, 0.65, 0.62))
    private static let keyIntensity = 0.85
    private static let fillDir = normalize(SIMD3(-0.60, -0.20, 0.45))
    private static let fillIntensity = 0.18
    private static let fillColor = RGB(0.70, 0.78, 0.95)
    private static let ambient = 0.17
    private static let sweepYPeriod = 4.0
    private static let sweepYIntensity = 0.40
    private static let sweepXPeriod = 5.5
    private static let sweepXIntensity = 0.30

    static func draw(in ctx: GraphicsContext, size: CGSize, base: RGB, time t: Double) {
        guard size.width > 1, size.height > 1 else { return }

        let spin = t.truncatingRemainder(dividingBy: spinPeriod) / spinPeriod * 2 * .pi
        let bob = sin(t * 2 * .pi / bobPeriod) * bobAmplitude

        // World-space vertices: rotate the hexagonal bipyramid around Y,
        // then float it on Y.
        let cosS = cos(spin), sinS = sin(spin)
        func place(_ x: Double, _ y: Double, _ z: Double) -> SIMD3<Double> {
            SIMD3(x * cosS + z * sinS, y + bob, -x * sinS + z * cosS)
        }
        let top = place(0, apexH, 0)
        let bottom = place(0, -apexH, 0)
        let equator: [SIMD3<Double>] = (0..<segments).map { i in
            let a = Double(i) * 2 * .pi / Double(segments)
            return place(radius * cos(a), 0, radius * sin(a))
        }

        // Per-half facet materials, mirroring the two SCNMaterials: the top
        // half ran lighter with an emissive floor and strong specular, the
        // bottom darker, matte-r and quieter.
        let topBase = adjustLightness(base, by: +0.06)
        let bottomBase = adjustLightness(base, by: -0.10)
        let topEmission = adjustLightness(base, by: -0.30) * 0.35
        let zero = RGB(0, 0, 0)

        // Sweep light directions at this instant.
        let phiY = t * 2 * .pi / sweepYPeriod
        let sweepY = normalize(SIMD3(sin(phiY), -0.25, cos(phiY)))
        let phiX = t * 2 * .pi / sweepXPeriod
        let sweepX = normalize(SIMD3(-0.25, sin(phiX), cos(phiX)))

        // Projection: perspective from (0,0,camZ) looking down -z. The
        // vertical FOV is trimmed ~3% so the apex never kisses the frame
        // edge at the top of the bob.
        let focal = Double(size.height) / 2 / tan(fovDeg * .pi / 360) * 0.97
        let cx = Double(size.width) / 2
        let cy = Double(size.height) / 2
        func project(_ p: SIMD3<Double>) -> CGPoint {
            let d = camZ - p.z
            return CGPoint(x: cx + p.x * focal / d, y: cy - p.y * focal / d)
        }

        struct Face {
            let path: Path
            let fill: RGB
            let depth: Double
        }

        var faces: [Face] = []
        let camPos = SIMD3(0.0, 0.0, camZ)

        func appendFace(_ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>,
                        baseColor: RGB, emission: RGB, specIntensity: Double) {
            let n = normalize(cross(b - a, c - a))
            let centroid = (a + b + c) / 3
            let toCam = normalize(camPos - centroid)
            guard dot(n, toCam) > 0 else { return }   // backface cull

            // Lambert diffuse from the static rig + travelling sweeps.
            var light = ambient
            light += max(0, dot(n, keyDir)) * keyIntensity
            light += max(0, dot(n, sweepY)) * sweepYIntensity
            light += max(0, dot(n, sweepX)) * sweepXIntensity
            var shaded = baseColor * light
            shaded += fillColor * (max(0, dot(n, fillDir)) * fillIntensity)
            shaded += emission

            // Blinn specular for the key light + a kick from the Y sweep so
            // the travelling glint reads as a highlight, not just brightness.
            let hKey = normalize(keyDir + toCam)
            shaded += RGB(repeating: pow(max(0, dot(n, hKey)), 28) * specIntensity)
            let hSweep = normalize(sweepY + toCam)
            shaded += RGB(repeating: pow(max(0, dot(n, hSweep)), 24) * specIntensity * 0.45)

            var path = Path()
            path.move(to: project(a))
            path.addLine(to: project(b))
            path.addLine(to: project(c))
            path.closeSubpath()
            faces.append(Face(path: path,
                              fill: clamp(shaded),
                              depth: camZ - centroid.z))
        }

        for i in 0..<segments {
            let j = (i + 1) % segments
            // Same winding as the old octahedron() so normals face outward.
            appendFace(top, equator[i], equator[j],
                       baseColor: topBase, emission: topEmission, specIntensity: 0.55)
            appendFace(bottom, equator[j], equator[i],
                       baseColor: bottomBase, emission: zero, specIntensity: 0.15)
        }

        // Painter's algorithm: far faces first. Each face is also stroked in
        // its own colour to swallow the antialiasing seams between adjacent
        // triangles.
        for face in faces.sorted(by: { $0.depth > $1.depth }) {
            let c = Color(red: face.fill.x, green: face.fill.y, blue: face.fill.z)
            ctx.fill(face.path, with: .color(c))
            ctx.stroke(face.path, with: .color(c), lineWidth: 0.8)
        }
    }

    // MARK: - Colour helpers

    /// SwiftUI Color → linear RGB triple, resolved through the platform
    /// colour (the gem palette is plain sRGB values, so this is lossless).
    static func rgb(of color: Color) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if os(macOS)
        NSColor(color).usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return RGB(Double(r), Double(g), Double(b))
    }

    /// HSL lightness shift, same maths the SceneKit version used for its
    /// per-half diffuse/emission variants.
    static func adjustLightness(_ c: RGB, by delta: Double) -> RGB {
        let maxC = max(c.x, max(c.y, c.z))
        let minC = min(c.x, min(c.y, c.z))
        let l0 = (maxC + minC) / 2
        var h = 0.0
        var s = 0.0
        if maxC != minC {
            let d = maxC - minC
            s = l0 > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
            if maxC == c.x { h = (c.y - c.z) / d + (c.y < c.z ? 6 : 0) }
            else if maxC == c.y { h = (c.z - c.x) / d + 2 }
            else { h = (c.x - c.y) / d + 4 }
            h /= 6
        }
        let l = min(1, max(0, l0 + delta))
        guard s != 0 else { return RGB(repeating: l) }
        let q = l < 0.5 ? l * (1 + s) : l + s - l * s
        let p = 2 * l - q
        func hue(_ t0: Double) -> Double {
            var t = t0
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6 { return p + (q - p) * 6 * t }
            if t < 1.0 / 2 { return q }
            if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
            return p
        }
        return RGB(hue(h + 1.0 / 3), hue(h), hue(h - 1.0 / 3))
    }

    private static func clamp(_ c: RGB) -> RGB {
        RGB(min(1, max(0, c.x)), min(1, max(0, c.y)), min(1, max(0, c.z)))
    }
}

// MARK: - Vector helpers

private func normalize(_ v: SIMD3<Double>) -> SIMD3<Double> {
    let len = (v.x * v.x + v.y * v.y + v.z * v.z).squareRoot()
    return len > 0 ? v / len : v
}

private func cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
    SIMD3(a.y * b.z - a.z * b.y,
          a.z * b.x - a.x * b.z,
          a.x * b.y - a.y * b.x)
}

private func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    a.x * b.x + a.y * b.y + a.z * b.z
}

#Preview {
    ZStack {
        SimsTheme.background.ignoresSafeArea()
        HStack(spacing: 30) {
            PlumbobView(mood: 0.90)
            PlumbobView(mood: 0.55)
            PlumbobView(mood: 0.20)
        }
    }
}
