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
        ZStack {
            // Soft halo behind the gem — radial gradient blob that ties
            // the plumbob to its mood colour without competing with the
            // facets. Sized larger than the gem so it leaks out around it.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.45), color.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: orbSize * 0.7
                    )
                )
                .frame(width: orbSize * 1.6, height: orbSize * 1.6)
                .blur(radius: 6)

            Plumbob3DScene(color: color)
                .frame(width: orbSize, height: orbSize * 1.4)
        }
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
    private static let coreNodeName    = "plumbobCore"

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = PlatformColor.clear

        // Outer gem — coloured, glossy crystal.
        let outer = octahedron(h: 2.2, r: 0.68, segments: 8)
        let outerMat = SCNMaterial()
        outerMat.lightingModel = .blinn
        outerMat.diffuse.contents = PlatformColor(color)
        outerMat.specular.contents = PlatformColor.white
        outerMat.shininess = 0.85           // tighter, more crystal-like highlight
        outerMat.emission.contents = PlatformColor(color).withAlphaComponent(0.10)
        outer.firstMaterial = outerMat

        let node = SCNNode(geometry: outer)
        node.name = Self.plumbobNodeName
        scene.rootNode.addChildNode(node)

        // Inner "core" — slightly smaller, near-white gem with strong
        // emission. Visible through the slight translucency of the outer
        // facets as a bright vertical sliver — the characteristic plumbob
        // highlight strip without needing a textured face.
        let core = octahedron(h: 1.95, r: 0.18, segments: 6)
        let coreMat = SCNMaterial()
        coreMat.lightingModel = .blinn
        coreMat.diffuse.contents = PlatformColor.white
        coreMat.emission.contents = PlatformColor(color).withAlphaComponent(0.85)
        core.firstMaterial = coreMat
        let coreNode = SCNNode(geometry: core)
        coreNode.name = Self.coreNodeName
        node.addChildNode(coreNode)

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

        // Strong key light from upper-right.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1400
        key.color = PlatformColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2, 3, 4)
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        // Cool blue rim light from the opposite side.
        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 320
        fill.color = PlatformColor(red: 0.55, green: 0.65, blue: 0.95, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-3, -1, 2)
        fillNode.eulerAngles = SCNVector3(0.3, -0.6, 0)
        scene.rootNode.addChildNode(fillNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 60
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
        material.diffuse.contents = PlatformColor(color)
        material.emission.contents = PlatformColor(color).withAlphaComponent(0.10)
        // Keep the inner core tinted with the mood colour too.
        if let core = view.scene?.rootNode.childNode(withName: Self.coreNodeName, recursively: true),
           let coreMat = core.geometry?.firstMaterial {
            coreMat.emission.contents = PlatformColor(color).withAlphaComponent(0.85)
        }
    }
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
