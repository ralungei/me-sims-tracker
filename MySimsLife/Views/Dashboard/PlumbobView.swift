import SwiftUI
import SceneKit

// MARK: - Mood Plumbob — procedural 3D bipyramid via SceneKit

struct PlumbobView: View {
    let mood: Double
    var compact: Bool = false
    var size: CGFloat? = nil

    private var color: Color { SimsTheme.plumbobColor(for: mood) }
    private var orbSize: CGFloat { size ?? (compact ? 60 : 78) }

    var body: some View {
        // Halo entirely removed — was making the gem read as a glow
        // instead of a hard-faceted crystal. The plumbob needs sharp
        // edges on the periwinkle background to register as 3D.
        Plumbob3DScene(color: color)
            .frame(width: orbSize, height: orbSize * 1.15)
        // VITAL plumbob. Without a label VoiceOver just says "image" —
        // give it a name + the current mood description so blind users
        // also get the at-a-glance vibe the colour communicates visually.
        .accessibilityElement()
        .accessibilityLabel(Text("VITAL"))
        .accessibilityValue(Text(mood.accessibilityNeedValue))
    }
}

// MARK: - SceneKit bridge

#if os(macOS)
private typealias PlatformColor = NSColor
#else
private typealias PlatformColor = UIColor
#endif

struct Plumbob3DScene {
    let color: Color

    private static let plumbobNodeName = "plumbob"

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = PlatformColor.clear

        // Cel-shaded look: Lambert (no specular falloff) + a deeper,
        // more saturated diffuse so the gem reads against periwinkle.
        // Specular kept as a SMALL tight white highlight ONLY (low
        // shininess number → bigger spot, high → tiny spot) — too much
        // and the gem looks washed; none at all and it looks like felt.
        let outer = octahedron(h: 1.55, r: 0.78, segments: 8)
        let outerMat = SCNMaterial()
        outerMat.lightingModel = .lambert
        outerMat.diffuse.contents  = PlatformColor(deepened(color))
        outerMat.specular.contents = PlatformColor.white
        outerMat.shininess = 0.95           // tiny pinpoint highlight
        outerMat.emission.contents = PlatformColor.clear
        outer.firstMaterial = outerMat

        let node = SCNNode(geometry: outer)
        node.name = Self.plumbobNodeName
        scene.rootNode.addChildNode(node)

        // Slow Y-axis spin so the highlight sweeps around continuously.
        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = SCNVector4(0, 1, 0, 0)
        spin.toValue   = SCNVector4(0, 1, 0, Float.pi * 2)
        spin.duration  = 9
        spin.repeatCount = .infinity
        node.addAnimation(spin, forKey: "spin")

        // Gentle vertical bob — Sims-style "hovering" feel.
        let bob = CABasicAnimation(keyPath: "position.y")
        bob.fromValue = -0.08
        bob.toValue   = 0.08
        bob.duration  = 2.4
        bob.autoreverses = true
        bob.repeatCount = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.addAnimation(bob, forKey: "bob")

        let camera = SCNCamera()
        camera.fieldOfView = 32
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5.6)
        scene.rootNode.addChildNode(cameraNode)

        // Single strong key light — no fill, no ambient. Lambert + a
        // bare key gives the brutal light/shadow contrast Sims plumbobs
        // have: lit facets are saturated colour, shadow facets are
        // almost black. Any ambient kills it.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1100
        key.color = PlatformColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2, 3, 4)
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        // Very low ambient just so shadow facets aren't 100 % black —
        // 30 keeps the silhouette readable while preserving contrast.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 30
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    /// Hexagonal bipyramid: `segments` facets at the equator → 2×segments
    /// triangular faces. Equator near-circular so silhouette stays even
    /// while rotating. Elongated proportions (h ≫ r) match the Sims-2
    /// vertical-diamond plumbob silhouette.
    private func octahedron(h: Float, r: Float, segments: Int) -> SCNGeometry {
        let topApex = SCNVector3(0,  h, 0)
        let botApex = SCNVector3(0, -h, 0)

        var equator: [SCNVector3] = []
        for i in 0..<segments {
            let a = Float(i) * 2 * .pi / Float(segments)
            equator.append(SCNVector3(r * cos(a), 0, r * sin(a)))
        }

        var faces: [(SCNVector3, SCNVector3, SCNVector3)] = []
        for i in 0..<segments {
            let n = (i + 1) % segments
            faces.append((topApex, equator[i], equator[n]))
            faces.append((botApex, equator[n], equator[i]))
        }

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var idx: [Int32] = []
        for (a, b, c) in faces {
            let n = normalize(cross(b - a, c - a))
            let base = Int32(verts.count)
            verts.append(contentsOf: [a, b, c])
            norms.append(contentsOf: [n, n, n])
            idx.append(contentsOf: [base, base + 1, base + 2])
        }

        let vsrc = SCNGeometrySource(vertices: verts)
        let nsrc = SCNGeometrySource(normals: norms)
        let elem = SCNGeometryElement(indices: idx, primitiveType: .triangles)
        return SCNGeometry(sources: [vsrc, nsrc], elements: [elem])
    }
}

// MARK: - Platform conformance

#if os(macOS)
extension Plumbob3DScene: NSViewRepresentable {
    func makeNSView(context: Context) -> SCNView { configured(SCNView()) }
    func updateNSView(_ view: SCNView, context: Context) { applyColor(to: view) }
}
#else
extension Plumbob3DScene: UIViewRepresentable {
    func makeUIView(context: Context) -> SCNView { configured(SCNView()) }
    func updateUIView(_ view: SCNView, context: Context) { applyColor(to: view) }
}
#endif

private extension Plumbob3DScene {
    func configured(_ view: SCNView) -> SCNView {
        view.scene = makeScene()
        view.backgroundColor = PlatformColor.clear
        view.allowsCameraControl = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        return view
    }

    func applyColor(to view: SCNView) {
        guard let node = view.scene?.rootNode.childNode(withName: Self.plumbobNodeName, recursively: true),
              let material = node.geometry?.firstMaterial else { return }
        material.diffuse.contents = PlatformColor(deepened(color))
    }
}

// MARK: - Colour helpers

/// Pull the diffuse colour a bit darker + more saturated so the gem
/// reads against the periwinkle background. Sims plumbob greens are
/// significantly more vivid than the calibrated bar palette tones.
private func deepened(_ color: Color) -> Color {
    let ui = PlatformColor(color)
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    #if os(macOS)
    ui.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    ui.getRed(&r, green: &g, blue: &b, alpha: &a)
    #endif
    // Multiply each channel by 0.78 to darken the lit colour. The
    // single key light pushes lit facets back up close to the original
    // hue, while shadow facets go properly dim.
    return Color(red: r * 0.78, green: g * 0.78, blue: b * 0.78)
}

// MARK: - SCNVector3 math

private func -(a: SCNVector3, b: SCNVector3) -> SCNVector3 {
    SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z)
}

private func cross(_ a: SCNVector3, _ b: SCNVector3) -> SCNVector3 {
    SCNVector3(a.y * b.z - a.z * b.y,
               a.z * b.x - a.x * b.z,
               a.x * b.y - a.y * b.x)
}

private func normalize(_ v: SCNVector3) -> SCNVector3 {
    let len = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return len > 0 ? SCNVector3(v.x / len, v.y / len, v.z / len) : v
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
