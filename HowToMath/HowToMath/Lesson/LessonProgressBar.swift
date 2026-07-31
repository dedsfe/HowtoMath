//
//  LessonProgressBar.swift
//  HowToMath
//

import SwiftUI

/// A bubble inside the fill. Positions are in points rather than fractions so a
/// bubble keeps its place on screen while the bar grows past it — the fill reads
/// as liquid rising through a column, not as a stretching image.
private struct Fizz {
    let x: Double
    let radius: Double
    let period: Double
    let phase: Double
    let wobble: Double

    static func pool(_ count: Int) -> [Fizz] {
        (0..<count).map { _ in
            Fizz(
                x: .random(in: 0...400),
                radius: .random(in: 0.9...2.2),
                period: .random(in: 1.1...2.4),
                phase: .random(in: 0...1),
                wobble: .random(in: 0.6...2.0)
            )
        }
    }
}

/// A bubble that escapes the bar on a correct answer.
private struct Rise {
    let dx: Double
    let radius: Double
    let lift: Double
    let wobble: Double
    let phase: Double

    static func batch(_ count: Int) -> [Rise] {
        (0..<count).map { _ in
            Rise(
                dx: .random(in: -14...14),
                radius: .random(in: 1.5...4.0),
                lift: .random(in: 26...58),
                wobble: .random(in: 2...7),
                phase: .random(in: 0...(2 * .pi))
            )
        }
    }
}

/// The lesson's progress bar: a fizzing green column that fills as the answers
/// land, with a puff of bubbles escaping the leading edge on each hit.
///
/// Both bubble layers run on `TimelineView(.animation)` so the motion is
/// per-frame rather than an interpolated snapshot. The escaping layer pauses
/// itself between bursts; the inner fizz only runs once there is fill to fizz in.
struct LessonProgressBar: View {

    let progress: Double
    let streak: Int
    let burstToken: Int
    let color: Color

    private let height: CGFloat = 10
    private let burstDuration = 1.0

    /// Fill is animated from empty on first appearance, so the bar introduces
    /// itself instead of arriving already committed to a value.
    @State private var shown: Double = 0

    @State private var fizz = Fizz.pool(16)
    @State private var risers: [Rise] = []
    @State private var burstStart = Date.distantPast
    @State private var isBursting = false

    /// Streak drives density, not colour — a hot streak is a busier liquid, and
    /// a cold bar is perfectly still. The fizz is earned, not decoration.
    private var fizzCount: Int { min(fizz.count, streak * 2) }
    private var riseCount: Int { min(18, 6 + streak * 2) }

    var body: some View {
        GeometryReader { geo in
            let full = geo.size.width
            let width = max(full * shown, shown > 0 ? height : 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.track)

                Capsule()
                    .fill(color)
                    .overlay { innerFizz }
                    // A lighter sliver along the top edge — the fill reads as a
                    // rounded bar catching light, not a flat block.
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(.white.opacity(0.35))
                            .frame(height: 3)
                            .padding(.horizontal, 4)
                            .padding(.top, 2)
                    }
                    .frame(width: width)
                    .clipShape(Capsule())
            }
            .frame(height: height)
            // An overlay rather than another stack layer: the escaping bubbles
            // need room above the bar to travel into, and must not drag the
            // bar's own height up with them.
            .overlay(alignment: .leading) {
                // Centred on the leading edge of the fill: the canvas emits from
                // its own middle, so no vertical offset — that would launch the
                // bubbles from empty space above the bar.
                escapingBubbles
                    .frame(width: 60, height: 70)
                    .offset(x: width - 30)
            }
        }
        .frame(height: height)
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(Theme.settle.delay(0.18)) { shown = progress }
        }
        .onChange(of: progress) { _, new in
            withAnimation(Theme.settle) { shown = new }
        }
        .onChange(of: burstToken) { _, new in
            guard new > 0 else { return }
            risers = Rise.batch(riseCount)
            burstStart = .now
            isBursting = true

            Task {
                try? await Task.sleep(for: .seconds(burstDuration))
                isBursting = false
            }
        }
    }

    /// White bubbles drifting up inside the fill, always on while there is fill.
    private var innerFizz: some View {
        TimelineView(.animation(paused: shown <= 0 || fizzCount == 0)) { timeline in
            Canvas { context, size in
                guard size.width > 1 else { return }
                let t = timeline.date.timeIntervalSinceReferenceDate

                for bubble in fizz.prefix(fizzCount) {
                    let life = ((t / bubble.period) + bubble.phase)
                        .truncatingRemainder(dividingBy: 1)

                    let travel = size.height + bubble.radius * 4
                    let y = travel * (1 - life) - bubble.radius * 2
                    let x = bubble.x.truncatingRemainder(dividingBy: size.width)
                        + sin(life * .pi * 3 + bubble.phase * 6) * bubble.wobble

                    // Fades in off the floor and out at the surface, so bubbles
                    // are never seen popping into or out of existence.
                    let alpha = sin(life * .pi) * 0.5

                    let dot = Path(ellipseIn: CGRect(
                        x: x - bubble.radius, y: y - bubble.radius,
                        width: bubble.radius * 2, height: bubble.radius * 2
                    ))
                    context.fill(dot, with: .color(.white.opacity(alpha)))
                }
            }
        }
    }

    /// Green bubbles breaking off the leading edge when an answer lands.
    private var escapingBubbles: some View {
        TimelineView(.animation(paused: !isBursting)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(burstStart)
                guard elapsed >= 0, elapsed <= burstDuration else { return }

                let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                let life = elapsed / burstDuration
                // Ease-out: they pop off the surface and slow as they climb.
                let travel = 1 - pow(1 - life, 2.0)

                for bubble in risers {
                    let x = origin.x + bubble.dx * travel
                          + sin(life * .pi * 2.5 + bubble.phase) * bubble.wobble
                    let y = origin.y - bubble.lift * travel

                    let radius = bubble.radius * (1 - life * 0.35)
                    guard radius > 0.2 else { continue }

                    let dot = Path(ellipseIn: CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    ))
                    context.fill(dot, with: .color(color.opacity((1 - life) * 0.9)))
                }
            }
        }
    }
}
