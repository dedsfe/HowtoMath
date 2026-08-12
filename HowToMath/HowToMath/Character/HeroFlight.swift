//
//  HeroFlight.swift
//  HowToMath
//

import SwiftUI

/// The creature flying straight up, chest to camera.
///
/// The creature barely moves. Flight upward is sold entirely by the world
/// falling past — anchor the character and run the scenery, and the eye reads
/// speed. Move the character up the screen instead and it reads as an icon
/// sliding, because there is nothing for it to be fast *relative to*.
///
/// Front-on rather than in profile: every part of this face is drawn facing
/// forward, and turning it sideways would mean redrawing the one thing the
/// character is best at.
struct HeroFlight: View {

    var onDone: () -> Void = {}

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.tear, Theme.tearLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Far layer: small, pale, slow. Behind the creature.
            CloudFall(depth: 0.45)
            SpeedLines(depth: 0.6)

            Creature(size: 190, animation: .flying)

            // Near layer, over the top of him. Cloud passing in front is the
            // single cheapest thing that turns a flat backdrop into depth —
            // without it he is pasted on a moving wallpaper rather than inside
            // the weather.
            CloudFall(depth: 1.35)
            SpeedLines(depth: 1.5)
        }
        .contentShape(.rect)
        .onTapGesture { onDone() }
    }
}

/// Cloud banks falling past the camera.
///
/// One `Canvas` on a per-frame timeline, like the confetti: a few dozen shapes
/// as real views would each need identity and diffing every frame, and none of
/// them is ever interacted with.
struct CloudFall: View {

    /// Under 1 is further away — smaller, slower, paler.
    var depth: Double = 1

    /// Four, not nine.
    ///
    /// Nine filled the frame edge to edge, and a sky with no sky left in it has
    /// nothing for the clouds to move *against* — the screen just looked like a
    /// cloud texture. Gaps are what let you see anything pass.
    @State private var puffs = Puff.batch(4)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for puff in puffs {
                    draw(puff, at: t, in: size, context: context)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func draw(_ puff: Puff, at t: Double, in size: CGSize, context: GraphicsContext) {
        let span = size.width + 500
        // Modulo on absolute time, so a cloud leaving the right edge is the same
        // cloud arriving at the left — no spawning, no bookkeeping, no chance of
        // the field thinning out over a long run.
        //
        // Left to right, because he is flying left: scenery always runs against
        // the direction of travel. Clouds drifting the same way he is going
        // would read as him being carried along by them, not cutting through.
        let travelled = (t * puff.speed * depth + puff.phase * span)
            .truncatingRemainder(dividingBy: span)

        let x = travelled - 250
        let y = puff.y * size.height
        let scale = puff.scale * depth

        var layer = context
        layer.translateBy(x: x, y: y)
        // Smeared along the direction of travel — now sideways. Anything moving
        // this fast stretches, and a perfectly round cloud at speed reads as a
        // sticker being slid across the screen. The near layer smears harder,
        // because it is the one covering the most ground.
        layer.scaleBy(x: scale * (1 + 0.26 * depth), y: scale * (1 - 0.12 * depth))
        layer.opacity = min(1, depth) * 0.9

        // Three overlapping ellipses. All one colour, so the seams between them
        // never show and the silhouette is the only thing you read.
        for lump in Puff.lumps {
            layer.fill(
                Path(ellipseIn: CGRect(
                    x: lump.x - lump.w / 2,
                    y: lump.y - lump.h / 2,
                    width: lump.w,
                    height: lump.h
                )),
                with: .color(.white)
            )
        }
    }
}

/// One cloud. Randomness is fixed at birth, so its position is a pure function
/// of the clock from then on.
struct Puff {

    /// Height on screen, 0 to 1. The cycle owns the horizontal now.
    let y: Double
    /// Where it starts in the cycle, 0 to 1.
    let phase: Double
    let scale: Double
    /// Points per second, before depth.
    let speed: Double

    /// The three lumps every cloud is built from, in local points.
    static let lumps: [(x: Double, y: Double, w: Double, h: Double)] = [
        (-42, 6, 96, 58),
        (10, -14, 118, 78),
        (66, 8, 88, 54)
    ]

    static func batch(_ count: Int) -> [Puff] {
        (0..<count).map { _ in
            Puff(
                y: .random(in: -0.05...1.05),
                phase: .random(in: 0...1),
                scale: .random(in: 0.55...1.25),
                // Roughly tripled. At 240–420 a cloud took several seconds to
                // cross, which at that size reads as drifting, and drifting
                // cloud under fast streaks is what made the streaks look like
                // rain falling through still air.
                speed: .random(in: 780...1250)
            )
        }
    }
}

/// Thin streaks tearing downward — faster than the clouds, and thinner.
struct SpeedLines: View {

    var depth: Double = 1

    @State private var streaks = Streak.batch(26)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let span = size.width + 500

                for streak in streaks {
                    let travelled = (t * streak.speed * depth + streak.phase * span)
                        .truncatingRemainder(dividingBy: span)
                    let x = travelled - 450

                    let length = streak.length * depth
                    // Length is horizontal now, thickness vertical: the streak
                    // lies along the direction of travel, which is the only way
                    // a smear reads as a smear.
                    let rect = CGRect(
                        x: x,
                        y: streak.lane * size.height,
                        width: length,
                        height: streak.width * depth
                    )

                    context.fill(
                        Path(roundedRect: rect, cornerRadius: rect.height / 2),
                        with: .color(.white.opacity(streak.alpha * min(1, depth)))
                    )
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct Streak {

    /// Which horizontal lane it runs along, 0 to 1 down the screen.
    let lane: Double
    let phase: Double
    let speed: Double
    let length: Double
    let width: Double
    let alpha: Double

    static func batch(_ count: Int) -> [Streak] {
        (0..<count).map { _ in
            // Kept clear of the band the creature occupies. He sits mid-screen,
            // and a streak drawn straight across his face is not speed, it is a
            // scratch on the lens. The clearing is vertical now that the
            // streaks themselves run horizontally.
            let side: Double = Bool.random() ? 1 : -1
            let reach = 0.20 + pow(Double.random(in: 0...1), 0.7) * 0.30

            return Streak(
                lane: 0.5 + side * reach,
                phase: .random(in: 0...1),
                speed: .random(in: 1700...2900),
                // Three times longer than they were.
                //
                // Length *is* the blur: a streak is one bright thing smeared
                // across a whole exposure, and at 40–160pt they were still
                // short enough to read as separate falling objects. Long enough
                // and they stop being objects at all.
                length: .random(in: 140...420),
                width: .random(in: 2.5...5),
                alpha: .random(in: 0.22...0.55)
            )
        }
    }
}

#Preview {
    HeroFlight()
}
