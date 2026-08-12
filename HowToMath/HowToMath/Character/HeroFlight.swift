//
//  HeroFlight.swift
//  HowToMath
//

import SwiftUI

/// The creature flying left, seen from the side.
///
/// He barely moves. Speed is sold entirely by the world running past him —
/// anchor the character and move the scenery, and the eye reads flight. Slide
/// the character across the screen instead and it reads as an icon being
/// dragged, because there is nothing for him to be fast *relative to*.
///
/// In profile, which reversed an earlier decision here. The argument for
/// front-on was that the face is drawn to face forward and turning it sideways
/// throws that away — true, but it bought a pose no amount of background streak
/// could rescue: a body facing the camera has no direction, so nothing about it
/// says "going somewhere". Side-on, the silhouette does that work by itself and
/// the scenery is free to be scenery. See `docs/mascote.md`.
///
/// Momenti 1 and 2 of three: the wide shot, then a cut to the close-up.
///
/// **Two camera positions on one continuous take.** Nothing in the scene
/// changes when the shot changes — he does not turn, does not stop, does not
/// change face. The camera was beside him and is now in front of him, and the
/// join between the two is a hard cut, the way a film would do it.
///
/// This replaced a version that animated the change: he spun to face the camera
/// while the lens pushed in and the weather faded out. Every one of those is the
/// character reacting to the edit, which is backwards — the edit is supposed to
/// be invisible and he is supposed to be unaware of it. Cutting is also simply
/// what the reference does. See `docs/mascote.md`.
struct HeroFlight: View {

    var onDone: () -> Void = {}

    @State private var shot: Shot = .wide
    @State private var finished = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.tear, Theme.tearLight],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch shot {
            case .wide: wideScene
            case .close: closeScene
            }
        }
        .contentShape(.rect)
        .onTapGesture { finish() }
        .task { await roll() }
    }

    /// Play the scene: hold the wide shot, cut, hold the close-up, end.
    ///
    /// On `.task` rather than a timer, so it dies with the view. A cut that
    /// fires after the screen is gone lands on whatever replaced it.
    private func roll() async {
        try? await Task.sleep(for: .seconds(Timing.wide))
        guard !finished else { return }
        shot = .close

        try? await Task.sleep(for: .seconds(Timing.close))
        finish()
    }

    /// Called from both the tap and the end of the scene, and it must not run
    /// twice: `onDone` dismisses, and dismissing something already dismissed is
    /// how you get a screen that flashes back for a frame on its way out.
    private func finish() {
        guard !finished else { return }
        finished = true
        onDone()
    }

    /// Camera beside him: the world crosses the frame.
    @ViewBuilder private var wideScene: some View {
        // Far layer: small, pale, slow. Behind the creature.
        CloudSweep(depth: 0.45)
        SpeedLines(depth: 0.6)

        creature

        // Near layer, over the top of him. Cloud passing in front is the
        // single cheapest thing that turns a flat backdrop into depth —
        // without it he is pasted on a moving wallpaper rather than
        // inside the weather.
        CloudSweep(depth: 1.35)
        SpeedLines(depth: 1.5)
    }

    /// Camera in front of him: the world comes at the lens.
    ///
    /// Same weather, same speed, same direction of travel — but the camera
    /// turned ninety degrees, so what used to cross the frame sideways now
    /// arrives out of the distance and opens past the edges. Keeping the
    /// sideways drift here was the tell that gave the cut away: the shot said
    /// "you are in front of him" and the sky said "you are still beside him".
    /// No clouds in here, only rays.
    ///
    /// A cloud this close to the lens is the size of the screen, so it stops
    /// being scenery and becomes a white shape wiping across his face — and
    /// there is no framing that fixes that, because the problem is the range,
    /// not the placement. The reference holds its close-up on plain sky for the
    /// same reason. The rays carry the speed on their own.
    @ViewBuilder private var closeScene: some View {
        SpeedRays(depth: 0.7)

        creature

        SpeedRays(depth: 1.4)
    }

    /// Same creature, same flight, two lenses.
    ///
    /// He was `.idle` in the close-up until now, which meant he swapped his
    /// flight face for a grin at the exact moment of the cut — the one thing
    /// this edit is not allowed to contain. `.flyingFront` is the same pose from
    /// the front, so nothing about him changes across the join.
    @ViewBuilder private var creature: some View {
        switch shot {
        case .wide:
            Creature(size: 190, animation: .flying)

        case .close:
            Creature(size: 190, animation: .flyingFront)
                .scaleEffect(Framing.close, anchor: Framing.eyes)
        }
    }

    /// Momento 2. He turns to face us, the camera closes in, and it **stops**.
    ///
    private enum Shot {
        /// Momento 1: the camera beside him, whole creature in frame.
        case wide
        /// Momento 2: the camera in front of him, filling the frame with face.
        case close
    }

    private enum Framing {
        /// How much bigger he is in the close-up than in the wide shot.
        static let close: CGFloat = 2.15
        /// Where the camera is pointed, in his own coordinates.
        ///
        /// Above centre because his eyes are: framing on `.center` walks the
        /// face off the top of the screen and fills it with belly instead.
        static let eyes = UnitPoint(x: 0.5, y: 0.4)
    }

    /// How long each shot is held. No transition times, because there is no
    /// transition — the whole edit is the instant between these two numbers.
    private enum Timing {
        /// Long enough to establish where he is and that he is moving.
        static let wide: Double = 3
        /// Shorter, as a cut-in should be. The close-up has no new information
        /// in it after the first moment; what it has is emphasis, and emphasis
        /// held too long turns back into waiting.
        static let close: Double = 2
    }
}

/// Cloud banks sweeping past the camera, against the direction of travel.
///
/// One `Canvas` on a per-frame timeline, like the confetti: a few dozen shapes
/// as real views would each need identity and diffing every frame, and none of
/// them is ever interacted with.
struct CloudSweep: View {

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

/// The same weather from in front: clouds falling away behind him, shrinking
/// toward the vanishing point.
///
/// **The camera is flying backwards.** It sits ahead of him, facing back the way
/// he came, and travels at his speed to hold the frame. So the world does what
/// it does through the rear window of a car: it starts big at the edges, slides
/// outward-in, and closes to a point in the distance.
///
/// The first version of this had it the other way round — clouds born at the
/// vanishing point and rushing out past the lens — which is the view *facing the
/// direction of travel*. It looks like flying into weather rather than away from
/// it, and it contradicted the shot: you cannot be looking at his face and at
/// where he is going at the same time.
///
/// Perspective is one division. A cloud carries a depth `z` running from nearly
/// 0 (at the lens) to 1 (far); size and off-centre distance are both constants
/// over `z`. That single term does all of it — near things are huge and move
/// fast, far things are small and barely move. Nothing is tracked between
/// frames; position stays a pure function of the clock, as in `CloudSweep`.
struct CloudApproach: View {

    /// Under 1 is further away — smaller, slower, paler.
    var depth: Double = 1

    /// Drop every cloud once it has receded past this point in its run.
    ///
    /// For the layer drawn *in front of* him this is not a tweak, it is the
    /// geometry: a cloud that far away is behind him by definition, so it has no
    /// business being painted over his face. Left at 1, the front layer shrank
    /// little puffs down onto his mouth and eye — the vanishing point is his
    /// face, and that is exactly where distant things end up.
    var recedesTo: Double = 1

    @State private var clouds = Oncoming.batch(7)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for cloud in clouds {
                    draw(cloud, at: t, in: size, context: context)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func draw(_ cloud: Oncoming, at t: Double, in size: CGSize, context: GraphicsContext) {
        let cycle = (t * cloud.speed * depth + cloud.phase)
            .truncatingRemainder(dividingBy: 1)
        guard cycle <= recedesTo else { return }

        // Runs 0 → 1: it starts at the lens and retreats. Floored well above
        // zero because at the limit the division runs away to infinity, and a
        // cloud a hundred screens wide costs real time to rasterise for a frame
        // nobody can read anyway.
        let z = max(0.09, cycle)
        let near = 1 / z

        // The vanishing point is his face, not the centre of the screen. He is
        // what the camera is pointed at, so he is what the world should be
        // streaming out from behind.
        let originX = size.width / 2
        let originY = size.height * 0.46

        var layer = context
        layer.translateBy(
            x: originX + cos(cloud.angle) * cloud.spread * size.width * near * 0.12,
            y: originY + sin(cloud.angle) * cloud.spread * size.height * near * 0.12
        )
        let scale = cloud.scale * near * 0.14 * depth
        layer.scaleBy(x: scale, y: scale)
        // Fades down into the haze over the last stretch of whatever run this
        // layer shows, so nothing winks out of existence at the vanishing point.
        layer.opacity = min(1, (recedesTo - cycle) * 3) * min(1, depth) * 0.9

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

/// One cloud coming at the lens.
struct Oncoming {

    /// Which way out from the vanishing point it travels, in radians.
    let angle: Double
    /// How far off-axis it is. Small values pass close to his face.
    let spread: Double
    let phase: Double
    let scale: Double
    /// Cycles per second: how often it makes the whole trip in.
    let speed: Double

    static func batch(_ count: Int) -> [Oncoming] {
        (0..<count).map { index in
            // Angles spread evenly with a wobble, rather than drawn at random.
            // Seven random angles clump, and a clump leaves a quadrant of the
            // screen with no weather in it at all.
            let slice = Double.pi * 2 / Double(count)

            return Oncoming(
                angle: slice * Double(index) + .random(in: -slice / 3...slice / 3),
                // Never zero: a cloud dead on the axis grows straight out of the
                // middle of his face without ever moving aside.
                spread: .random(in: 0.55...1.5),
                phase: .random(in: 0...1),
                scale: .random(in: 0.6...1.3),
                speed: .random(in: 0.22...0.38)
            )
        }
    }
}

/// The streaks, radial. Same idea as `SpeedLines`, turned to face the camera:
/// each lies along its own line through the vanishing point, because a smear
/// points the way the thing was travelling and everything here is falling away
/// inward, toward the point he came from.
struct SpeedRays: View {

    var depth: Double = 1

    @State private var rays = Ray.batch(16)

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                for ray in rays {
                    draw(ray, at: t, in: size, context: context)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func draw(_ ray: Ray, at t: Double, in size: CGSize, context: GraphicsContext) {
        let cycle = (t * ray.speed * depth + ray.phase)
            .truncatingRemainder(dividingBy: 1)
        let z = max(0.09, cycle)
        let near = 1 / z

        let reach = size.height * 0.9
        // Head and tail are the same ray one moment apart, which is what makes
        // it a smear instead of a dash: the gap between them closes on its own
        // as the thing recedes. The tail is the further one out, because that is
        // where this ray just was.
        let head = ray.spread * near * 0.1 * reach
        let tail = ray.spread * (1 / max(0.09, z - 0.085)) * 0.1 * reach

        var layer = context
        layer.translateBy(x: size.width / 2, y: size.height * 0.46)
        layer.rotate(by: .radians(ray.angle))
        layer.opacity = min(1, (1 - cycle) * 2.5) * min(1, depth)

        layer.stroke(
            Path {
                $0.move(to: CGPoint(x: tail, y: 0))
                $0.addLine(to: CGPoint(x: head, y: 0))
            },
            with: .color(.white.opacity(ray.alpha)),
            style: StrokeStyle(lineWidth: ray.width * near * 0.3, lineCap: .round)
        )
    }
}

struct Ray {

    let angle: Double
    let spread: Double
    let phase: Double
    let speed: Double
    let width: Double
    let alpha: Double

    static func batch(_ count: Int) -> [Ray] {
        (0..<count).map { index in
            let slice = Double.pi * 2 / Double(count)

            return Ray(
                angle: slice * Double(index) + .random(in: -slice / 2...slice / 2),
                // Held away from the vanishing point. A ray starting on top of
                // his face draws a line across it, which is a scratch on the
                // lens rather than speed — the same reason `Streak` keeps clear
                // of the band he occupies in the wide shot.
                spread: .random(in: 0.9...2.2),
                phase: .random(in: 0...1),
                speed: .random(in: 0.5...0.85),
                width: .random(in: 2.5...5),
                alpha: .random(in: 0.22...0.5)
            )
        }
    }
}

#Preview {
    HeroFlight()
}
