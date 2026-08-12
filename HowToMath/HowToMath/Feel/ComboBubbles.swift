//
//  ComboBubbles.swift
//  HowToMath
//
//  The combo marker: a wave of bubbles crossing the whole screen, floor to
//  ceiling. Same language as the fizz inside the progress bar, scaled up until
//  the bar's liquid looks like it boiled over into the room.
//

import SwiftUI

/// One bubble in a wave.
///
/// Everything about it is decided when the wave is built and never touched
/// again — the canvas only reads the clock. Nothing here is `@State`, so a
/// redraw mid-flight cannot reshuffle a bubble that is already halfway up.
private struct Bubble {

    /// Where it leaves the floor, as a fraction of the width.
    let x: Double

    /// 0 far away, 1 right up against the glass.
    ///
    /// Size, speed and opacity all come off this single number instead of being
    /// rolled separately. Rolled apart you get small bubbles that are opaque and
    /// fast, which is the one combination that cannot happen — a near thing is
    /// big, bright *and* quick, and a far one is small, faint and slow. Tying
    /// the three together is what buys depth from a flat canvas.
    let depth: Double

    /// Seconds after the wave starts before this one leaves the floor.
    let delay: Double

    /// How far it swings sideways on the way up, in points.
    let sway: Double

    /// Where in its own swing it starts, so no two bubbles lean the same way at
    /// the same moment.
    let phase: Double

    /// How many times it crosses its own path over a full climb.
    let turns: Double

    /// A wave of `count` bubbles, dealt out over `spread` seconds.
    ///
    /// Both the horizontal spot and the launch time are *stratified* rather than
    /// uniformly random: the width is cut into as many columns as there are
    /// bubbles and one bubble is jittered inside each. Pure randomness clumps —
    /// a couple of bubbles land almost on top of each other and leave a third of
    /// the screen empty, and with only two dozen of them that gap is the first
    /// thing the eye finds. Same trick on the clock, so the wave arrives as a
    /// stream instead of a volley.
    ///
    /// The two ladders are shuffled apart, and that is the part that matters.
    /// Walking both off the same index gives every bubble a launch time that
    /// agrees with its position — first one on the left, last one on the right —
    /// and the wave comes up as a diagonal sweeping across the screen. It is a
    /// wipe, not a boil. Cutting the correlation is the whole difference.
    static func wave(_ count: Int, spread: Double) -> [Bubble] {
        let column = 1.0 / Double(count)
        let step = spread / Double(count)
        let columns = (0..<count).shuffled()

        return (0..<count).map { i in
            let when = Double(i)
            let where_ = Double(columns[i])

            return Bubble(
                x: where_ * column + .random(in: 0...column),
                depth: .random(in: 0...1),
                delay: when * step + .random(in: 0...step),
                sway: .random(in: 6...22),
                phase: .random(in: 0...(2 * .pi)),
                turns: .random(in: 1.2...2.6)
            )
        }
    }
}

/// Bubbles rising across the whole screen, fired once per combo.
///
/// Meant to sit over everything and be ignored: it never takes a touch, and it
/// stops its own timeline the moment the last bubble leaves the top, so a screen
/// that is not celebrating costs nothing to keep on it.
struct ComboBubbles: View {

    /// Bumped to fire a wave. Anything else is ignored.
    var token: Int

    static let climbDefault: Double = 1.5
    static let spreadDefault: Double = 0.5

    /// How long a wave lasts at the default settings.
    ///
    /// Exposed because the end of a lesson has to wait one out: the last answer
    /// of a perfect run trips a combo and ends the lesson on the same frame, and
    /// cutting to the applause there would throw away the biggest wave of the
    /// run at the exact moment it was earned.
    static var span: Double { climbDefault * 1.25 + spreadDefault }

    var color: Color = Theme.gold

    /// How long one bubble takes to cross, floor to ceiling.
    var climb: Double = ComboBubbles.climbDefault

    /// Over how long the wave is dealt out.
    ///
    /// The whole point is that they do not launch together. A wave where every
    /// bubble starts on the same frame reads as a bar being wiped up the screen;
    /// staggered, it reads as something bubbling.
    var spread: Double = ComboBubbles.spreadDefault

    var count: Int = 26

    @State private var bubbles: [Bubble] = []
    @State private var startedAt = Date.distantPast
    @State private var rising = false

    /// Total length of a wave: the last bubble launches at `spread` and still
    /// needs its own climb after that.
    private var span: Double { climb * 1.25 + spread }

    var body: some View {
        TimelineView(.animation(paused: !rising)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(startedAt)
                guard elapsed >= 0, elapsed <= span else { return }

                for bubble in bubbles {
                    let age = elapsed - bubble.delay
                    guard age >= 0 else { continue }

                    // Near bubbles are quicker. A big bubble really does rise
                    // faster than a small one, and it is also what stops the
                    // wave from arriving at the ceiling as a flat line.
                    let life = climb * (1.25 - 0.45 * bubble.depth)
                    let p = age / life
                    guard p <= 1 else { continue }

                    let radius = 4 + 14 * bubble.depth

                    // Starts fully below the bottom edge and ends fully past the
                    // top, so a bubble is never seen appearing or vanishing —
                    // the screen is a window onto something taller.
                    let travel = size.height + radius * 4
                    let y = size.height + radius * 2 - travel * rise(p)

                    let x = bubble.x * size.width
                        + sin(p * .pi * bubble.turns + bubble.phase) * bubble.sway

                    // Fades in off the floor and out under the ceiling. The fade
                    // out is the longer of the two: something leaving should
                    // thin out, something arriving should already be there.
                    let fade = min(1, p / 0.12) * min(1, (1 - p) / 0.22)
                    let alpha = fade * (0.35 + 0.5 * bubble.depth)

                    let circle = Path(ellipseIn: CGRect(
                        x: x - radius, y: y - radius,
                        width: radius * 2, height: radius * 2
                    ))

                    // Hollow, not a dot: a soft wash inside and a firm rim.
                    // Filled solid at this size the same shape reads as confetti
                    // — it is the bright edge around a pale middle that says the
                    // thing is a skin holding air.
                    context.fill(circle, with: .color(color.opacity(alpha * 0.45)))
                    context.stroke(
                        circle,
                        with: .color(color.opacity(alpha)),
                        lineWidth: max(1, radius * 0.16)
                    )

                    // The catchlight, and only on the ones near enough to carry
                    // it. On a small bubble the dot is a pixel of noise sitting
                    // where the rim should be.
                    guard bubble.depth > 0.35 else { continue }

                    let spark = radius * 0.24
                    context.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius * 0.38 - spark,
                            y: y - radius * 0.38 - spark,
                            width: spark * 2, height: spark * 2
                        )),
                        with: .color(.white.opacity(alpha * 0.9))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: token) { _, new in
            guard new > 0 else { return }

            bubbles = Bubble.wave(count, spread: spread)
            startedAt = .now
            rising = true

            Task {
                try? await Task.sleep(for: .seconds(span))
                rising = false
            }
        }
    }

    /// How far up a bubble is at `p`, 0 to 1.
    ///
    /// Barely eased, and eased *in*: a bubble breaking away from a surface has
    /// to overcome the surface first, then climbs at a near-steady rate once it
    /// is free. The temptation is an ease-out, which is what a thrown object
    /// does — and a bubble that decelerates on the way up looks like it is
    /// hitting a lid.
    private func rise(_ p: Double) -> Double {
        pow(p, 1.15)
    }
}
