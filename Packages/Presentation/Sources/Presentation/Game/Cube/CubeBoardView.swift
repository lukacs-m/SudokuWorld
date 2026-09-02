import Common
import CoreGraphics
import Domain
import Model
import RealityKit
import simd
import SwiftUI

/// The cube variant's playing surface: a real RealityKit cube whose six
/// faces are textured quads redrawn from the game state. One finger spins
/// it (and it settles with the nearest face square-on), a pinch zooms, and
/// a tap ray-casts into the scene to select a cell. Everything after the
/// tap is the ordinary `GameViewModel` path — the cube only replaces the
/// flat board's rendering and gestures.
struct CubeBoardView: View {
    let viewModel: GameViewModel

    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var scene = CubeScene()
    @State private var orientation = Self.initialOrientation
    @State private var scale: Float = 1
    @GestureState private var dragTranslation: CGSize?
    @GestureState private var pinch: CGFloat?

    var body: some View {
        if let session = viewModel.session, let topology = viewModel.topology {
            let theme = themeStore.theme(for: colorScheme)
            GeometryReader { proxy in
                let size = proxy.size
                let state = sceneState(session: session, theme: theme, size: size)
                // Not a button: the accessibility overlay carries the
                // per-cell button semantics; this tap is plain hit testing.
                // swiftlint:disable:next accessibility_trait_for_button
                ZStack {
                    RealityView { content in
                        scene.build(into: &content, state: state)
                    } update: { _ in
                        scene.apply(state)
                    }
                    .accessibilityHidden(true)
                    CubeAccessibilityOverlay(
                        viewModel: viewModel,
                        session: session,
                        topology: topology,
                        size: size,
                    )
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(rotate.simultaneously(with: magnify))
                .onTapGesture { location in
                    // While the settle animation plays the cube is not yet at
                    // `orientation`, so a ray cast would pick the wrong cell.
                    guard !scene.isSettling else { return }
                    guard let cell = CubeGeometry.hitCell(
                        at: location,
                        in: size,
                        orientation: orientation,
                        scale: scale,
                    ) else { return }
                    viewModel.tapCell(cell)
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
    }

    /// At rest, front face flat-on — unless a debug launch hook asks for a
    /// turned cube (screenshots of the mid-rotation state).
    private static var initialOrientation: simd_quatf {
        guard let pose = LaunchHooks.cubePose else { return simd_quatf(angle: 0, axis: [0, 1, 0]) }
        let yaw = simd_quatf(angle: Float(pose.yaw) * .pi / 180, axis: [0, 1, 0])
        let pitch = simd_quatf(angle: Float(pose.pitch) * .pi / 180, axis: [1, 0, 0])
        return pitch * yaw
    }

    /// Committed pose plus any in-flight drag or pinch, run through the
    /// same math the gesture commits use.
    private func sceneState(session: GameSession, theme: Theme, size: CGSize) -> CubeSceneState {
        let hintCells = Set(viewModel.presentedHint?.cells ?? [])
        let snapshots = CubeNet.Face.allCases.map { face in
            CubeFaceSnapshot.make(
                face: face,
                session: session,
                selected: viewModel.selectedCell,
                related: viewModel.relatedCells,
                sameDigit: viewModel.sameDigitCells,
                conflicts: viewModel.conflicts,
                hintCells: hintCells,
                settings: viewModel.settings,
                theme: theme,
            )
        }
        return CubeSceneState(
            snapshots: snapshots,
            orientation: liveOrientation,
            scale: liveScale,
            interacting: dragTranslation != nil || pinch != nil,
            aspect: Float(size.width / max(size.height, 1)),
            hidden: viewModel.phase == .paused,
        )
    }

    /// The pose the cube is showing right now: the committed one plus
    /// whichever gesture is still in flight. The two gestures run
    /// simultaneously, so either one ending must settle to *both* gestures'
    /// current values or it would drag the other one backwards.
    private var liveOrientation: simd_quatf {
        dragTranslation.map { CubeGeometry.rotation(forDrag: $0) * orientation } ?? orientation
    }

    private var liveScale: Float {
        pinch.map { CubeGeometry.clampedScale(scale * Float($0)) } ?? scale
    }

    private var rotate: some Gesture {
        DragGesture(minimumDistance: 8)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                let free = CubeGeometry.rotation(forDrag: value.translation) * orientation
                orientation = CubeGeometry.settledOrientation(near: free)
                scene.settle(orientation: orientation, scale: liveScale)
            }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                scale = CubeGeometry.clampedScale(scale * Float(value.magnification))
                scene.settle(orientation: liveOrientation, scale: scale)
            }
    }
}

/// One frame's worth of inputs for the scene, as plain values so the
/// RealityView closures capture nothing observable.
struct CubeSceneState: Sendable {
    let snapshots: [CubeFaceSnapshot]
    let orientation: simd_quatf
    let scale: Float
    let interacting: Bool
    let aspect: Float
    let hidden: Bool
}

/// Owns the RealityKit entities for the lifetime of the view. Face textures
/// regenerate only for faces whose snapshot changed; the pose is written
/// directly while a gesture is live and animated into place on release.
@MainActor
final class CubeScene {
    private let root = Entity()
    private let camera = PerspectiveCamera()
    private var faces: [ModelEntity] = []
    private var lastSnapshots: [CubeFaceSnapshot?] = Array(repeating: nil, count: 6)
    private var isLit = false
    private var settling: AnimationPlaybackController?

    /// True while the release animation still drives `root.transform`, so
    /// the cube is somewhere between the released pose and the settled one.
    var isSettling: Bool {
        settling?.isPlaying ?? false
    }

    func build(into content: inout RealityViewCameraContent, state: CubeSceneState) {
        content.camera = .virtual
        camera.camera.fieldOfViewOrientation = .vertical
        camera.position = [0, 0, CubeGeometry.cameraDistance]
        content.add(camera)

        let key = DirectionalLight()
        key.light.intensity = 1800
        key.look(at: .zero, from: [3, 5, 8], relativeTo: nil)
        content.add(key)
        let fill = DirectionalLight()
        fill.light.intensity = 700
        fill.look(at: .zero, from: [-5, -2, 6], relativeTo: nil)
        content.add(fill)

        // A uniform environment gives every face a base level of light so
        // the back-lit faces stay readable while the key light shades them.
        if let environment = Self.ambientEnvironment() {
            let ambient = Entity()
            ambient.components.set(ImageBasedLightComponent(source: .single(environment)))
            content.add(ambient)
            root.components.set(ImageBasedLightReceiverComponent(imageBasedLight: ambient))
            isLit = true
        }

        // Quads overlap the edges by a hair so no seam shows between faces.
        let mesh = MeshResource.generatePlane(width: 3.01, height: 3.01)
        for face in CubeNet.Face.allCases {
            let quad = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: .white)])
            quad.position = CubeGeometry.facePosition(face)
            quad.orientation = CubeGeometry.faceOrientation(face)
            root.addChild(quad)
            faces.append(quad)
        }
        root.transform = Self.transform(orientation: state.orientation, scale: state.scale)
        content.add(root)
        apply(state)
    }

    func apply(_ state: CubeSceneState) {
        camera.camera.fieldOfViewInDegrees = CubeGeometry.verticalFieldOfView(aspect: state.aspect)
        root.isEnabled = !state.hidden
        if state.interacting {
            // RealityKit's animation writes `root.transform` every frame, so
            // it has to be stopped or it would overwrite the live gesture.
            settling?.stop()
            settling = nil
            root.transform = Self.transform(orientation: state.orientation, scale: state.scale)
        }
        for (face, snapshot) in state.snapshots.enumerated() where lastSnapshots[face] != snapshot {
            guard let image = CubeFaceRenderer.render(snapshot),
                  let texture = try? TextureResource(
                      image: image,
                      withName: nil,
                      options: .init(semantic: .color),
                  )
            else { continue }
            faces[face].model?.materials = [material(for: texture)]
            lastSnapshots[face] = snapshot
        }
    }

    func settle(orientation: simd_quatf, scale: Float) {
        settling?.stop()
        settling = root.move(
            to: Self.transform(orientation: orientation, scale: scale),
            relativeTo: nil,
            duration: 0.35,
            timingFunction: .easeOut,
        )
    }

    private func material(for texture: TextureResource) -> any RealityKit.Material {
        guard isLit else { return UnlitMaterial(texture: texture) }
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(texture: .init(texture))
        material.roughness = .init(floatLiteral: 0.9)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    private static func transform(orientation: simd_quatf, scale: Float) -> Transform {
        Transform(scale: SIMD3<Float>(repeating: scale), rotation: orientation, translation: .zero)
    }

    /// A flat light-grey equirectangular environment.
    private static func ambientEnvironment() -> EnvironmentResource? {
        guard let context = CGContext(
            data: nil,
            width: 64,
            height: 32,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return nil }
        context.setFillColor(CGColor(red: 0.82, green: 0.82, blue: 0.82, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
        guard let image = context.makeImage() else { return nil }
        return try? EnvironmentResource(equirectangular: image, withName: "cube-ambient")
    }
}

/// VoiceOver's view of the cube: the six faces laid out as the net, each a
/// container of nine cells carrying exactly the flat board's labels and
/// actions. Invisible and untouchable; the 3D view stays hidden from
/// accessibility because RealityKit entities on iOS cannot activate cells.
private struct CubeAccessibilityOverlay: View {
    let viewModel: GameViewModel
    let session: GameSession
    let topology: GridTopology
    let size: CGSize

    var body: some View {
        let cell = min(
            size.width / CGFloat(CubeNet.netCols),
            size.height / CGFloat(CubeNet.netRows),
        )
        let origin = CGPoint(
            x: (size.width - cell * CGFloat(CubeNet.netCols)) / 2,
            y: (size.height - cell * CGFloat(CubeNet.netRows)) / 2,
        )
        ZStack(alignment: .topLeading) {
            ForEach(CubeNet.Face.allCases, id: \.rawValue) { face in
                let corner = CubeNet.netPosition(of: CubeNet.index(face: face, row: 0, col: 0))
                faceCells(face, cell: cell)
                    .frame(width: cell * 3, height: cell * 3, alignment: .topLeading)
                    .offset(
                        x: origin.x + CGFloat(corner.col) * cell,
                        y: origin.y + CGFloat(corner.row) * cell,
                    )
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(Text(verbatim: moduleString("cube.face.\(face.slug)")))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func faceCells(_ face: CubeNet.Face, cell: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0 ..< CubeNet.cellsPerFace, id: \.self) { offset in
                let index = CubeNet.index(face: face, row: offset / 3, col: offset % 3)
                Color.clear
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(offset % 3) * cell, y: CGFloat(offset / 3) * cell)
                    .accessibilityAction { viewModel.tapCell(index) }
                    .accessibilityLabel(GameAccessibility.cellLabel(
                        index: index,
                        board: session.board,
                        puzzle: session.puzzle,
                        topology: topology,
                    ))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(viewModel.selectedCell == index ? .isSelected : [])
            }
        }
    }
}
