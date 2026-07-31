//
//  ParticleBurst.swift
//  HowToMath
//

import SwiftUI

private struct Particle {
    let angle: Double
    let speed: Double
    let size: Double
    let drift: Double

    static func batch(_ count: Int) -> [Particle] {
        (0..<count).map { _ in
            Particle(
                angle: .random(in: 0...(2 * .pi)),
                speed: .random(in: 90...260),
                size: .random(in: 2.5...6.5),
                drift: .random(in: -40...40)
            )
        }
    }
}

/// A short radial spray of dots, fired by bumping `token`.
///
/// Runs on `TimelineView(.animation)` so the motion is genuinely per-frame
/// rather than an interpolated snapshot, and pauses itself between bursts.
struct ParticleBurst: View {

    let token: Int
    let color: Color

    private let duration = 0.85
    private let gravity = 620.0

    @State private var particles: [Particle] = []
    @State private var start = Date.distantPast
    @State private var isRunning = false

    var body: some View {
        TimelineView(.animation(paused: !isRunning)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed >= 0, elapsed <= duration else { return }

                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                let life = elapsed / duration
                // Ease-out so they explode fast and coast to a stop.
                let travel = 1 - pow(1 - life, 2.4)

                for particle in particles {
                    let x = origin.x + cos(particle.angle) * particle.speed * travel + particle.drift * life
                    let y = origin.y + sin(particle.angle) * particle.speed * travel
                          + 0.5 * gravity * elapsed * elapsed

                    let radius = particle.size * (1 - life * 0.7)
                    guard radius > 0.2 else { continue }

                    let dot = Path(ellipseIn: CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    ))
                    context.fill(dot, with: .color(color.opacity(1 - life)))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: token) { _, newValue in
            guard newValue > 0 else { return }
            particles = Particle.batch(20)
            start = .now
            isRunning = true

            Task {
                try? await Task.sleep(for: .seconds(duration))
                isRunning = false
            }
        }
    }
}
