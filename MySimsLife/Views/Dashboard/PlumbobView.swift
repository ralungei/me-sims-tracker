import SwiftUI
import SceneKit

// MARK: - Mood Plumbob — procedural 3D bipyramid via SceneKit

struct PlumbobView: View {
    let mood: Double
    var compact: Bool = false
    var size: CGFloat? = nil
    /// Height-to-width ratio of the SCNView frame. Default 1.15 leaves
    /// breathing room above/below the gem for the dashboard layout; the
    /// onboarding passes a tighter value (~0.95) to crop the empty
    /// vertical space when the plumbob is the hero.
    var aspectRatio: CGFloat = 1.15

    private var color: Color { SimsTheme.plumbobColor(for: mood) }
    private var orbSize: CGFloat { size ?? (compact ? 78 : 104) }

    var body: some View {
        Plumbob3DScene(color: color)
            .frame(width: orbSize, height: orbSize * aspectRatio)
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

    private func makeFacetMaterial(color: Color, lightnessOffset: CGFloat, mirroredBeam: Bool) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = adjustLightness(PlatformColor(color), by: lightnessOffset)
        m.specular.contents = PlatformColor.white
        m.specular.intensity = mirroredBeam ? 0.15 : 0.55
        m.shininess = 0.95
        m.fresnelExponent = mirroredBeam ? 0.6 : 1.5
        m.emission.contents = mirroredBeam
            ? PlatformColor.clear
            : adjustLightness(PlatformColor(color), by: -0.30)
        m.shaderModifiers = [.surface: beamShaderModifier(mirrored: mirroredBeam)]
        return m
    }

    private func beamShaderModifier(mirrored: Bool) -> String {
        let ySign = mirrored ? "-1.0" : "1.0"
        let intensity = mirrored ? "0.02" : "0.12"
        return """
        #pragma body
        float t = scn_frame.time;
        float angle = 1.309 + sin(t * 0.4) * 0.10;
        float cosA = cos(angle);
        float sinA = sin(angle);
        float4 worldPos = scn_frame.inverseViewTransform * float4(_surface.position, 1.0);
        float yShifted = (worldPos.y * \(ySign)) - 0.70;
        float perp = worldPos.x * cosA + yShifted * sinA;
        float along = -worldPos.x * sinA + yShifted * cosA;
        float shift = sin(t * 0.7) * 0.18;
        float curvedPerp = perp + along * along * 0.45 + shift;
        float thickness = 6.0 + along * along * 55.0;
        float lengthFade = exp(-along * along * 0.65);
        float beam = exp(-curvedPerp * curvedPerp * thickness) * lengthFade;
        _surface.emission.rgb += float3(beam * \(intensity));
        """
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = PlatformColor.clear

        let outer = octahedron(h: 1.55, r: 0.78, segments: 6)
        outer.materials = [
            makeFacetMaterial(color: color, lightnessOffset: +0.06, mirroredBeam: false),
            makeFacetMaterial(color: color, lightnessOffset: -0.10, mirroredBeam: true)
        ]

        let node = SCNNode(geometry: outer)
        node.name = Self.plumbobNodeName
        scene.rootNode.addChildNode(node)

        let spin = CABasicAnimation(keyPath: "rotation")
        spin.fromValue = SCNVector4(0, 1, 0, 0)
        spin.toValue   = SCNVector4(0, 1, 0, Float.pi * 2)
        spin.duration  = 9
        spin.repeatCount = .infinity
        node.addAnimation(spin, forKey: "spin")

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

        let key = SCNLight()
        key.type = .directional
        key.intensity = 800
        key.color = PlatformColor.white
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(2, 3, 4)
        keyNode.eulerAngles = SCNVector3(-0.5, 0.4, 0)
        scene.rootNode.addChildNode(keyNode)

        let fill = SCNLight()
        fill.type = .directional
        fill.intensity = 165
        fill.color = PlatformColor(red: 0.70, green: 0.78, blue: 0.95, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fill
        fillNode.position = SCNVector3(-3, -1, 2)
        fillNode.eulerAngles = SCNVector3(0.3, -0.6, 0)
        scene.rootNode.addChildNode(fillNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 170
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sweepPivot = SCNNode()
        scene.rootNode.addChildNode(sweepPivot)

        let sweep = SCNLight()
        sweep.type = .directional
        sweep.intensity = 480
        sweep.color = PlatformColor.white
        let sweepNode = SCNNode()
        sweepNode.light = sweep
        sweepNode.eulerAngles = SCNVector3(-0.25, 0, 0)
        sweepPivot.addChildNode(sweepNode)

        let sweepSpin = CABasicAnimation(keyPath: "rotation")
        sweepSpin.fromValue = SCNVector4(0, 1, 0, 0)
        sweepSpin.toValue   = SCNVector4(0, 1, 0, -Float.pi * 2)
        sweepSpin.duration  = 4.0
        sweepSpin.repeatCount = .infinity
        sweepPivot.addAnimation(sweepSpin, forKey: "sweepSpin")

        let sweepPivotX = SCNNode()
        scene.rootNode.addChildNode(sweepPivotX)

        let sweepX = SCNLight()
        sweepX.type = .directional
        sweepX.intensity = 380
        sweepX.color = PlatformColor.white
        let sweepNodeX = SCNNode()
        sweepNodeX.light = sweepX
        sweepNodeX.eulerAngles = SCNVector3(0, -0.25, 0)
        sweepPivotX.addChildNode(sweepNodeX)

        let sweepSpinX = CABasicAnimation(keyPath: "rotation")
        sweepSpinX.fromValue = SCNVector4(1, 0, 0, 0)
        sweepSpinX.toValue   = SCNVector4(1, 0, 0, Float.pi * 2)
        sweepSpinX.duration  = 5.5
        sweepSpinX.repeatCount = .infinity
        sweepPivotX.addAnimation(sweepSpinX, forKey: "sweepSpinX")

        return scene
    }

    private func octahedron(h: Float, r: Float, segments: Int) -> SCNGeometry {
        let topApex = SCNVector3(0,  h, 0)
        let botApex = SCNVector3(0, -h, 0)

        var equator: [SCNVector3] = []
        for i in 0..<segments {
            let a = Float(i) * 2 * .pi / Float(segments)
            equator.append(SCNVector3(r * cos(a), 0, r * sin(a)))
        }

        var topFaces: [(SCNVector3, SCNVector3, SCNVector3)] = []
        var botFaces: [(SCNVector3, SCNVector3, SCNVector3)] = []
        for i in 0..<segments {
            let n = (i + 1) % segments
            topFaces.append((topApex, equator[i], equator[n]))
            botFaces.append((botApex, equator[n], equator[i]))
        }

        let apexUV  = CGPoint(x: 0.5, y: 0.0)
        let leftUV  = CGPoint(x: 0.0, y: 1.0)
        let rightUV = CGPoint(x: 1.0, y: 1.0)

        var verts: [SCNVector3] = []
        var norms: [SCNVector3] = []
        var uvs:   [CGPoint]    = []
        var topIdx: [Int32]     = []
        var botIdx: [Int32]     = []

        func append(face: (SCNVector3, SCNVector3, SCNVector3), into idx: inout [Int32]) {
            let (a, b, c) = face
            let n = normalize(cross(b - a, c - a))
            let base = Int32(verts.count)
            verts.append(contentsOf: [a, b, c])
            norms.append(contentsOf: [n, n, n])
            uvs.append(contentsOf: [apexUV, leftUV, rightUV])
            idx.append(contentsOf: [base, base + 1, base + 2])
        }

        for face in topFaces { append(face: face, into: &topIdx) }
        for face in botFaces { append(face: face, into: &botIdx) }

        let vsrc = SCNGeometrySource(vertices: verts)
        let nsrc = SCNGeometrySource(normals: norms)
        let usrc = SCNGeometrySource(textureCoordinates: uvs)
        let topElem = SCNGeometryElement(indices: topIdx, primitiveType: .triangles)
        let botElem = SCNGeometryElement(indices: botIdx, primitiveType: .triangles)
        return SCNGeometry(sources: [vsrc, nsrc, usrc], elements: [topElem, botElem])
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
              let materials = node.geometry?.materials,
              materials.count >= 2 else { return }
        materials[0].diffuse.contents = adjustLightness(PlatformColor(color), by: +0.06)
        materials[1].diffuse.contents = adjustLightness(PlatformColor(color), by: -0.10)
        materials[0].emission.contents = adjustLightness(PlatformColor(color), by: -0.30)
        materials[1].emission.contents = PlatformColor.clear
    }
}

// UIColor / NSColor back the per-facet material colours below.
#if os(iOS)
import UIKit
#else
import AppKit
#endif

private func adjustLightness(_ color: PlatformColor, by delta: CGFloat) -> PlatformColor {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    #if os(macOS)
    color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
    #else
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    #endif
    let maxC = max(r, max(g, b))
    let minC = min(r, min(g, b))
    let l0 = (maxC + minC) / 2
    var hh: CGFloat = 0
    var s: CGFloat = 0
    if maxC != minC {
        let d = maxC - minC
        s = l0 > 0.5 ? d / (2 - maxC - minC) : d / (maxC + minC)
        if maxC == r { hh = (g - b) / d + (g < b ? 6 : 0) }
        else if maxC == g { hh = (b - r) / d + 2 }
        else { hh = (r - g) / d + 4 }
        hh /= 6
    }
    let l = max(0, min(1, l0 + delta))
    let (nr, ng, nb) = hslToRGB(h: hh, s: s, l: l)
    return PlatformColor(red: nr, green: ng, blue: nb, alpha: 1)
}

private func hslToRGB(h: CGFloat, s: CGFloat, l: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
    guard s != 0 else { return (l, l, l) }
    let q = l < 0.5 ? l * (1 + s) : l + s - l * s
    let p = 2 * l - q
    func hueToRGB(_ p: CGFloat, _ q: CGFloat, _ t: CGFloat) -> CGFloat {
        var t = t
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0/6 { return p + (q - p) * 6 * t }
        if t < 1.0/2 { return q }
        if t < 2.0/3 { return p + (q - p) * (2.0/3 - t) * 6 }
        return p
    }
    return (hueToRGB(p, q, h + 1.0/3),
            hueToRGB(p, q, h),
            hueToRGB(p, q, h - 1.0/3))
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
