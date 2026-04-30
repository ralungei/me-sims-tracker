import SwiftUI
import SceneKit

// MARK: - Mood Plumbob — procedural 3D octahedron via SceneKit

struct PlumbobView: View {
    let mood: Double
    var compact: Bool = false
    var size: CGFloat? = nil

    private var color: Color { SimsTheme.plumbobColor(for: mood) }
    private var orbSize: CGFloat { size ?? (compact ? 60 : 78) }

    var body: some View {
        Plumbob3DScene(color: color)
            .frame(width: orbSize, height: orbSize * 1.15)
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

        let geometry = octahedron()
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = PlatformColor(color)
        material.specular.contents = PlatformColor.white
        // Concentrated highlight + barely-there inner glow so the facets read
        // their own light/shadow gradient rather than washing out flat.
        material.shininess = 0.45
        material.emission.contents = PlatformColor(color).withAlphaComponent(0.06)
        geometry.firstMaterial = material

        let node = SCNNode(geometry: geometry)
        node.name = Self.plumbobNodeName
        scene.rootNode.addChildNode(node)

        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = SCNVector4(0, 1, 0, 0)
        spin.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        spin.duration = 12
        spin.repeatCount = .infinity
        node.addAnimation(spin, forKey: "spin")

        let camera = SCNCamera()
        camera.fieldOfView = 35
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(cameraNode)

        // Strong key light from upper-right hits one set of facets bright.
        let key = SCNLight()
        key.type = .directional
        key.intensity = 1200
        key.color = PlatformColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2, 3, 4)
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        // Cool blue rim light from the opposite side — gives the shadowed
        // facets a subtle blue tint instead of dead-flat dark.
        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 320
        fill.color = PlatformColor(red: 0.55, green: 0.65, blue: 0.95, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-3, -1, 2)
        fillNode.eulerAngles = SCNVector3(0.3, -0.6, 0)
        scene.rootNode.addChildNode(fillNode)

        // Ambient kept low so the light/shadow contrast survives.
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 70
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        return scene
    }

    /// Hexagonal bipyramid: 6 segments → 12 facets. Equator near-circular so silhouette
    /// stays even while rotating (4 segments looked like it shrank at 45°).
    private func octahedron() -> SCNGeometry {
        let h: Float = 1.55
        let r: Float = 0.78
        let segments = 8

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
        material.emission.contents = PlatformColor(color).withAlphaComponent(0.06)
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
