import CoreGraphics
import Domain
import simd

/// Pure math for the 3D cube board: where each face and cell sits in the
/// cube's own space, how the camera frames it, and how screen gestures map
/// back onto cells and orientations. No RealityKit here, so all of it is
/// unit-testable against `CubeNet`'s edge table.
///
/// The cube is centered at the origin with side 3 (one unit per cell); the
/// virtual camera sits on +z looking at the origin.
enum CubeGeometry {
    static let halfSide: Float = 1.5
    static let cameraDistance: Float = 12
    static let minScale: Float = 0.75
    static let maxScale: Float = 1.6
    /// Half-extent of the widest silhouette (corner-on, a hexagon of
    /// circumradius side·√(2/3)); the camera fits this at scale 1 so the
    /// cube never leaves the viewport while it spins.
    static let silhouetteRadius: Float = 3 * (2.0 / 3.0).squareRoot()
    /// Radians of rotation per point of finger travel.
    static let radiansPerPoint: Float = 0.0105

    /// A face's local axes: `right` is the direction of increasing column,
    /// `down` of increasing row. `right × down = -normal` on every face.
    struct Frame {
        let normal: SIMD3<Float>
        let right: SIMD3<Float>
        let down: SIMD3<Float>
    }

    static func frame(_ face: CubeNet.Face) -> Frame {
        switch face {
        case .up: Frame(normal: [0, 1, 0], right: [1, 0, 0], down: [0, 0, 1])
        case .left: Frame(normal: [-1, 0, 0], right: [0, 0, 1], down: [0, -1, 0])
        case .front: Frame(normal: [0, 0, 1], right: [1, 0, 0], down: [0, -1, 0])
        case .right: Frame(normal: [1, 0, 0], right: [0, 0, -1], down: [0, -1, 0])
        case .back: Frame(normal: [0, 0, -1], right: [-1, 0, 0], down: [0, -1, 0])
        case .down: Frame(normal: [0, -1, 0], right: [1, 0, 0], down: [0, 0, -1])
        }
    }

    /// Cell center in cube space.
    static func center(of index: Int) -> SIMD3<Float> {
        let position = CubeNet.facePosition(of: index)
        let frame = frame(position.face)
        return frame.normal * halfSide
            + frame.right * Float(position.col - 1)
            + frame.down * Float(position.row - 1)
    }

    static func facePosition(_ face: CubeNet.Face) -> SIMD3<Float> {
        frame(face).normal * halfSide
    }

    /// Rotation that lays a +z-facing plane (x right, y up) onto the face.
    static func faceOrientation(_ face: CubeNet.Face) -> simd_quatf {
        let frame = frame(face)
        return simd_quatf(simd_float3x3(columns: (frame.right, -frame.down, frame.normal)))
    }

    /// Vertical field of view (degrees) that fits the full silhouette at
    /// scale 1 in the view's narrower dimension.
    static func verticalFieldOfView(aspect: Float) -> Float {
        let tanHalf = silhouetteRadius / (cameraDistance - silhouetteRadius) / min(1, aspect)
        return 2 * atan(tanHalf) * 180 / .pi
    }

    static func clampedScale(_ scale: Float) -> Float {
        min(max(scale, minScale), maxScale)
    }

    /// Free rotation for a finger drag: horizontal travel spins about the
    /// screen's vertical axis, vertical travel about its horizontal axis.
    static func rotation(forDrag translation: CGSize) -> simd_quatf {
        let yaw = simd_quatf(angle: Float(translation.width) * radiansPerPoint, axis: [0, 1, 0])
        let pitch = simd_quatf(angle: Float(translation.height) * radiansPerPoint, axis: [1, 0, 0])
        return yaw * pitch
    }

    /// Of the 24 orientations that show one face flat-on toward the camera
    /// with its rows level, the one closest to `orientation`.
    static func settledOrientation(near orientation: simd_quatf) -> simd_quatf {
        var best = orientation
        var bestDot: Float = -1
        for face in CubeNet.Face.allCases {
            let frame = frame(face)
            let local = simd_float3x3(columns: (frame.right, frame.down, frame.normal))
            for quarterTurn in 0 ..< 4 {
                let spin = simd_quatf(angle: Float(quarterTurn) * .pi / 2, axis: [0, 0, 1])
                let target = simd_float3x3(columns: (
                    spin.act([1, 0, 0]),
                    spin.act([0, -1, 0]),
                    SIMD3<Float>(0, 0, 1),
                ))
                let candidate = simd_quatf(target * local.transpose)
                let dot = abs(simd_dot(candidate, orientation))
                if dot > bestDot {
                    bestDot = dot
                    best = candidate
                }
            }
        }
        return best
    }

    /// The cell under a screen point, or nil when the tap misses the cube.
    /// Casts the camera ray into cube space and takes the nearest face hit.
    static func hitCell(
        at point: CGPoint,
        in viewSize: CGSize,
        orientation: simd_quatf,
        scale: Float,
    ) -> Int? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let aspect = Float(viewSize.width / viewSize.height)
        let tanHalf = tan(verticalFieldOfView(aspect: aspect) * .pi / 360)
        let ndcX = Float(2 * point.x / viewSize.width - 1)
        let ndcY = Float(1 - 2 * point.y / viewSize.height)
        let direction = SIMD3<Float>(ndcX * tanHalf * aspect, ndcY * tanHalf, -1)

        let inverse = orientation.inverse
        let origin = inverse.act([0, 0, cameraDistance]) / scale
        let ray = inverse.act(direction) / scale

        var nearest: (distance: Float, cell: Int)?
        for face in CubeNet.Face.allCases {
            let frame = frame(face)
            let along = simd_dot(frame.normal, ray)
            guard along < 0 else { continue } // back faces never face the camera
            let distance = (halfSide - simd_dot(frame.normal, origin)) / along
            guard distance > 0 else { continue }
            let hit = origin + ray * distance
            let across = simd_dot(hit, frame.right) + halfSide
            let downward = simd_dot(hit, frame.down) + halfSide
            guard across >= 0, across < 3, downward >= 0, downward < 3 else { continue }
            if nearest == nil || distance < (nearest?.distance ?? .infinity) {
                let cell = CubeNet.index(face: face, row: Int(downward), col: Int(across))
                nearest = (distance, cell)
            }
        }
        return nearest?.cell
    }
}
