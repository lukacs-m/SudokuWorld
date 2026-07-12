import SwiftUI

/// Celebration particles: ~120 pieces whose positions are pure functions of
/// time, rendered in a TimelineView-driven Canvas. No per-frame state, no
/// UIKit — compiles and runs everywhere SwiftUI does.
struct ConfettiView: View {
    private struct Particle {
        let originX: Double
        let hue: Double
        let fallSpeed: Double
        let drift: Double
        let spin: Double
        let size: Double
        let delay: Double
    }

    private let particles: [Particle]
    private let startDate = Date()

    init(seed: UInt64 = 0x5EED_C0DE) {
        // A tiny inline LCG keeps this view dependency-free and deterministic.
        var state = seed == 0 ? 0x5EED_C0DE : seed
        func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        particles = (0 ..< 120).map { _ in
            Particle(
                originX: next(),
                hue: next(),
                fallSpeed: 0.25 + next() * 0.35,
                drift: (next() - 0.5) * 0.3,
                spin: (next() - 0.5) * 12,
                size: 6 + next() * 8,
                delay: next() * 1.5,
            )
        }
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for particle in particles {
                    let time = elapsed - particle.delay
                    guard time > 0 else { continue }
                    let progress = time * particle.fallSpeed
                    guard progress < 1.4 else { continue }

                    let x = (particle.originX + particle.drift * time) * size.width
                    let y = progress * (size.height + 40) - 20
                    let rotation = Angle(radians: particle.spin * time)

                    var piece = context
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: rotation)
                    piece.opacity = max(0, 1.2 - progress)
                    piece.fill(
                        Path(CGRect(
                            x: -particle.size / 2,
                            y: -particle.size / 4,
                            width: particle.size,
                            height: particle.size / 2,
                        )),
                        with: .color(Color(
                            hue: particle.hue,
                            saturation: 0.75,
                            brightness: 0.95,
                        )),
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
