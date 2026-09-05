import CoreGraphics
import Domain
import Foundation
import Model
import simd
import SwiftUI
import Testing
@testable import Presentation

/// The 3D board's math must agree with `CubeNet`: the same cell index lands
/// on the same face position, and every bent line the engine enforces is a
/// straight line over an edge of the rendered cube.
@Suite
@MainActor
struct CubeGeometryTests {
    private func approx(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Bool {
        simd_length(a - b) < 1e-4
    }

    @Test func everyCellSitsOnItsFaceAtUnitSpacing() {
        for index in 0 ..< CubeNet.cellCount {
            let position = CubeNet.facePosition(of: index)
            let frame = CubeGeometry.frame(position.face)
            let center = CubeGeometry.center(of: index)
            #expect(abs(simd_dot(center, frame.normal) - CubeGeometry.halfSide) < 1e-5)
            #expect(abs(simd_dot(center, frame.right) - Float(position.col - 1)) < 1e-5)
            #expect(abs(simd_dot(center, frame.down) - Float(position.row - 1)) < 1e-5)
        }
        // 54 distinct centers, none shared between faces.
        let centers = (0 ..< CubeNet.cellCount).map(CubeGeometry.center(of:))
        for (a, first) in centers.enumerated() {
            for second in centers.dropFirst(a + 1) {
                #expect(!approx(first, second))
            }
        }
    }

    @Test func faceFramesAreOrthonormalAndConsistentlyHanded() {
        for face in CubeNet.Face.allCases {
            let frame = CubeGeometry.frame(face)
            #expect(abs(simd_length(frame.normal) - 1) < 1e-6)
            #expect(abs(simd_dot(frame.normal, frame.right)) < 1e-6)
            #expect(abs(simd_dot(frame.normal, frame.down)) < 1e-6)
            #expect(abs(simd_dot(frame.right, frame.down)) < 1e-6)
            #expect(approx(simd_cross(frame.right, frame.down), -frame.normal))
        }
    }

    @Test func faceOrientationLaysThePlaneOntoTheFace() {
        for face in CubeNet.Face.allCases {
            let frame = CubeGeometry.frame(face)
            let orientation = CubeGeometry.faceOrientation(face)
            #expect(approx(orientation.act([1, 0, 0]), frame.right))
            #expect(approx(orientation.act([0, 1, 0]), -frame.down))
            #expect(approx(orientation.act([0, 0, 1]), frame.normal))
        }
    }

    @Test func everyBentLineIsStraightOnTheCube() {
        let topology = TopologyFactory.topology(for: .cube)
        for (offset, clique) in topology.cliques.enumerated() {
            let edge = CubeNet.edges[offset / 3]
            let normalA = CubeGeometry.frame(edge.faceA).normal
            let normalB = CubeGeometry.frame(edge.faceB).normal
            let axis = simd_cross(normalA, normalB)
            let centers = clique.map(CubeGeometry.center(of:))

            // All six cells share their coordinate along the edge.
            let along = centers.map { simd_dot($0, axis) }
            #expect(along.allSatisfy { abs($0 - along[0]) < 1e-5 })

            // On each face the cells step one unit toward the edge...
            let stepA = centers[1] - centers[0]
            let stepB = centers[4] - centers[3]
            #expect(approx(centers[2] - centers[1], stepA))
            #expect(approx(centers[5] - centers[4], stepB))
            #expect(approx(stepA, normalB))
            #expect(approx(stepB, -normalA))
            // ...and the two halves meet across the edge, half a cell each.
            let crossing = centers[3] - centers[2]
            #expect(approx(crossing, 0.5 * normalB - 0.5 * normalA))
        }
    }

    @Test func hitTestFindsTheFrontFaceCellsAtRest() {
        let identity = simd_quatf(angle: 0, axis: [0, 1, 0])
        let size = CGSize(width: 300, height: 300)
        // The front face spans about 57% of the view at rest; its cell
        // centers are at ±1 units, at depth 10.5 from the camera.
        let aspect: Float = 1
        let tanHalf = tan(CubeGeometry.verticalFieldOfView(aspect: aspect) * .pi / 360)
        let depth = CubeGeometry.cameraDistance - CubeGeometry.halfSide
        for row in 0 ..< 3 {
            for col in 0 ..< 3 {
                let x = Float(col - 1) / (depth * tanHalf)
                let y = Float(1 - row) / (depth * tanHalf)
                let point = CGPoint(
                    x: CGFloat((x + 1) / 2) * size.width,
                    y: CGFloat((1 - y) / 2) * size.height,
                )
                let hit = CubeGeometry.hitCell(at: point, in: size, orientation: identity, scale: 1)
                #expect(hit == CubeNet.index(face: .front, row: row, col: col))
            }
        }
        #expect(CubeGeometry.hitCell(at: .zero, in: size, orientation: identity, scale: 1) == nil)
        #expect(CubeGeometry.hitCell(at: CGPoint(x: 150, y: 150), in: size, orientation: identity, scale: 1)
            == CubeNet.index(face: .front, row: 1, col: 1))
    }

    @Test func hitTestFollowsTheRotation() {
        let size = CGSize(width: 300, height: 300)
        let center = CGPoint(x: 150, y: 150)
        // A quarter turn about the vertical axis brings the left face to the camera.
        let showLeft = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])
        #expect(CubeGeometry.hitCell(at: center, in: size, orientation: showLeft, scale: 1)
            == CubeNet.index(face: .left, row: 1, col: 1))
        // Tilting the top toward the camera shows the up face.
        let showUp = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        #expect(CubeGeometry.hitCell(at: center, in: size, orientation: showUp, scale: 1)
            == CubeNet.index(face: .up, row: 1, col: 1))
    }

    @Test func settlingSquaresUpTheNearestFace() {
        // A small nudge settles back to rest.
        let nudged = CubeGeometry.rotation(forDrag: CGSize(width: 12, height: -9))
        let settled = CubeGeometry.settledOrientation(near: nudged)
        #expect(approx(settled.act([0, 0, 1]), [0, 0, 1]))
        #expect(approx(settled.act([1, 0, 0]), [1, 0, 0]))

        // Past 45° the neighbouring face wins and ends exactly flat-on.
        let swung = simd_quatf(angle: 1.2, axis: [0, 1, 0])
        let flat = CubeGeometry.settledOrientation(near: swung)
        let leftNormal = CubeGeometry.frame(.left).normal
        #expect(approx(flat.act(leftNormal), [0, 0, 1]))
        #expect(abs(simd_length(flat.vector) - 1) < 1e-5)
    }

    @Test func zoomIsClamped() {
        #expect(CubeGeometry.clampedScale(0.1) == CubeGeometry.minScale)
        #expect(CubeGeometry.clampedScale(9) == CubeGeometry.maxScale)
        #expect(CubeGeometry.clampedScale(1.2) == 1.2)
        // A flat-on face at maximum zoom still fits the narrow dimension.
        let tanHalf = tan(CubeGeometry.verticalFieldOfView(aspect: 1) * .pi / 360)
        let projected = CubeGeometry.halfSide * CubeGeometry.maxScale
            / (CubeGeometry.cameraDistance - CubeGeometry.halfSide * CubeGeometry.maxScale)
        #expect(projected <= tanHalf)
    }

    @Test func faceSnapshotMirrorsTheBoard() {
        let puzzle = PuzzleGenerator().generateNow(variant: .cube, difficulty: .easy, seed: 3)
        var session = GameSession(puzzle: puzzle, mode: .normal, context: .regular, startedAt: .now)
        let target = (0 ..< CubeNet.cellCount).first { puzzle.givens[$0] == nil } ?? 0
        _ = session.place(puzzle.solution[target] % 9 + 1, at: target, autoCleanNotes: false)
        let theme = ThemePalettes.palette(for: .warmPaper, scheme: .light)
        let face = CubeNet.facePosition(of: target).face
        let snapshot = CubeFaceSnapshot.make(
            face: face,
            session: session,
            selected: target,
            related: [target],
            sameDigit: [],
            conflicts: [],
            hintCells: [],
            settings: .standard,
            palette: CubeFaceSnapshot.Palette(theme: theme),
        )
        let cell = snapshot.cells[target % CubeNet.cellsPerFace]
        #expect(cell.isSelected)
        #expect(cell.isRelated)
        #expect(!cell.isGiven)
        #expect(cell.isWrong == GameSettings.standard.mistakeHighlighting)
        let givenCount = snapshot.cells.count(where: \.isGiven)
        let expectedGivens = (0 ..< 9).count { puzzle.givens[face.rawValue * 9 + $0] != nil }
        #expect(givenCount == expectedGivens)
    }
}
