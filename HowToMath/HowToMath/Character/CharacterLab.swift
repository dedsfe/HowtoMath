//
//  CharacterLab.swift
//  HowToMath
//

import SwiftUI

/// The mascot: an oval body, two feet, two big eyes and a small mouth.
///
/// Everything is geometry — ellipses and two curves — so it stays sharp at any
/// size and ships without a single asset. The proportions are what carry it: a
/// body wider than it is tall, eyes low and far apart, and a mouth small enough
/// that the eyes do the talking.
struct Creature: View {

    var size: CGFloat = 220
    var animation: CreatureAnimation = .none

    /// When the current arrival started, on the same clock the eyes read.
    @State private var arrivedAt: Double = 0

    /// Set every frame by the timeline that wraps the whole creature.
    ///
    /// The previous attempt hid the timeline in a `.background` with a
    /// `Color.clear` inside it and pushed the value out through `onChange`.
    /// Nothing observed that view, so it was never evaluated and the clock never
    /// advanced — the eye sat at fully open for the entire run.
    @State private var clock: Double = 0

    @State private var breathing = false
    /// Bumped once per jump.
    @State private var jumpToken = 0
    /// Bumped once per flinch.
    @State private var sadToken = 0
    /// Bumped once per arrival.
    @State private var arriveToken = 0

    var body: some View {
        TimelineView(.animation(paused: !isLive && animation != .arrive)) { timeline in
            creature
                .onChange(of: timeline.date) { _, date in
                    clock = date.timeIntervalSinceReferenceDate
                }
        }
    }

    private var creature: some View {
        ZStack {
            feet
                // The feet lag a couple of frames behind the body, which is what
                // sells soft mass: a rigid thing moves all at once.
                .keyframeAnimator(initialValue: 0.0, trigger: jumpToken) { view, lift in
                    view.offset(y: -lift * size * 0.22)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(0, duration: 0.10)
                        SpringKeyframe(1, duration: 0.24, spring: .snappy)
                        SpringKeyframe(0, duration: 0.34, spring: .bouncy)
                    }
                }
                // On landing the feet splay outward for a beat — the give of
                // something soft hitting the ground.
                .keyframeAnimator(initialValue: 1.0, trigger: arriveToken) { view, spread in
                    view.scaleEffect(x: spread, y: 2 - spread, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(1.0, duration: 0.31)
                        CubicKeyframe(1.30, duration: 0.10)
                        SpringKeyframe(1.0, duration: 0.40, spring: .bouncy)
                    }
                }

            ZStack {
                body_
                face
            }
            // Squash before the jump, stretch in the air, squash again on
            // landing. Volume is faked by trading height for width — that swap
            // is the whole reason it reads as something soft rather than an
            // image being moved up and down.
            .keyframeAnimator(initialValue: JumpPose(), trigger: jumpToken) { view, pose in
                view
                    .scaleEffect(x: pose.width, y: pose.height, anchor: .bottom)
                    .offset(y: pose.lift)
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    CubicKeyframe(1.14, duration: 0.12)
                    CubicKeyframe(0.90, duration: 0.20)
                    CubicKeyframe(1.10, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
                }
                KeyframeTrack(\.height) {
                    CubicKeyframe(0.84, duration: 0.12)
                    CubicKeyframe(1.16, duration: 0.20)
                    CubicKeyframe(0.88, duration: 0.16)
                    SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(6, duration: 0.12)
                    CubicKeyframe(-52, duration: 0.20)
                    CubicKeyframe(0, duration: 0.16)
                    CubicKeyframe(0, duration: 0.30)
                }
            }
            // Anchored at the bottom so it swells upward off its feet. Scaling
            // from the centre would make it hover, which reads as floating
            // rather than breathing.
            //
            // A `phaseAnimator` rather than `.animation(repeatForever)`: an
            // animation modifier captures every view change beneath it, so the
            // eye swapping shape was being cross-faded over 2.1 seconds — which
            // is why a ghost of the open eye hung around during a blink. This
            // one drives its own loop and leaves the children alone.
            // No `trigger:` here on purpose: with one, the phase advances only
            // when the trigger changes, so breathing took a single breath and
            // stopped. Without it, the animator cycles on its own forever.
            .phaseAnimator([false, true]) { view, inhale in
                view.scaleEffect(breathIn && inhale ? 1.035 : 1.0, anchor: .bottom)
            } animation: { _ in .easeInOut(duration: 2.1) }
        }
        .frame(width: size, height: size * 0.95)
        // Applied to the whole creature, feet included.
        //
        // While this sat on the body alone, a miss sank the body slowly while
        // the feet stayed put — the two came apart for half a second. Anything
        // that moves the creature as an object has to wrap the object.
        // The flinch: it sinks, sags sideways and comes back up slowly.
            // Slow is the point — recovering fast would read as shrugging the
            // mistake off, and this one should look a little sorry.
            .keyframeAnimator(initialValue: JumpPose(), trigger: sadToken) { view, pose in
                view
                    .scaleEffect(x: pose.width, y: pose.height, anchor: .bottom)
                    .rotationEffect(.degrees(pose.lift), anchor: .bottom)
            } keyframes: { _ in
                KeyframeTrack(\.width) {
                    CubicKeyframe(1.07, duration: 0.18)
                    CubicKeyframe(1.07, duration: 0.42)
                    CubicKeyframe(1.0, duration: 0.55)
                }
                KeyframeTrack(\.height) {
                    CubicKeyframe(0.90, duration: 0.18)
                    CubicKeyframe(0.90, duration: 0.42)
                    CubicKeyframe(1.0, duration: 0.55)
                }
                KeyframeTrack(\.lift) {
                    CubicKeyframe(-4, duration: 0.20)
                    CubicKeyframe(3, duration: 0.22)
                    CubicKeyframe(-1.5, duration: 0.22)
                    CubicKeyframe(0, duration: 0.40)
                }
            }
        // The arrival.
        //
        // It overshoots the resting spot, lands hard enough to squash, and
        // settles in two smaller bounces. Overshoot is the whole trick — coming
        // to a stop exactly on target reads as a window opening, not as a
        // creature arriving somewhere.
        .keyframeAnimator(initialValue: JumpPose(), trigger: arriveToken) { view, pose in
            view
                // Around the vertical axis, so it turns like something on a
                // turntable instead of cartwheeling. Perspective is kept low —
                // too much and the far side balloons on the way past.
                .rotation3DEffect(
                    .degrees(pose.spin),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.35
                )
                .scaleEffect(x: pose.width, y: pose.height, anchor: .bottom)
                .offset(y: pose.lift)
        } keyframes: { _ in
            // Two full turns on the way up, slowing as it falls, and a small
            // wobble past centre before it settles. The overshoot at the end is
            // what makes the spin read as momentum being spent rather than as a
            // rotation that simply stopped.
            KeyframeTrack(\.spin) {
                LinearKeyframe(0, duration: 0.01)
                CubicKeyframe(-540, duration: 0.30)
                CubicKeyframe(-720, duration: 0.10)
                SpringKeyframe(-712, duration: 0.22, spring: .bouncy)
                SpringKeyframe(-720, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.width) {
                LinearKeyframe(0.82, duration: 0.01)
                CubicKeyframe(0.86, duration: 0.30)
                CubicKeyframe(1.22, duration: 0.10)
                SpringKeyframe(0.97, duration: 0.22, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.height) {
                LinearKeyframe(1.20, duration: 0.01)
                CubicKeyframe(1.16, duration: 0.30)
                CubicKeyframe(0.78, duration: 0.10)
                SpringKeyframe(1.04, duration: 0.22, spring: .bouncy)
                SpringKeyframe(1.0, duration: 0.34, spring: .bouncy)
            }
            KeyframeTrack(\.lift) {
                LinearKeyframe(320, duration: 0.01)
                CubicKeyframe(-26, duration: 0.30)
                CubicKeyframe(0, duration: 0.10)
                SpringKeyframe(-14, duration: 0.22, spring: .bouncy)
                SpringKeyframe(0, duration: 0.34, spring: .bouncy)
            }
        }
        .onAppear { breathing = true }
        .task(id: animation) {
            if animation == .celebrate {
                while !Task.isCancelled {
                    jumpToken += 1
                    try? await Task.sleep(for: .seconds(1.6))
                }
            }

            if animation == .arrive {
                // Once. An arrival that loops is a screensaver; the caller
                // switches to `.idle` when the landing is done.
                arrivedAt = Date.timeIntervalSinceReferenceDate
                arriveToken += 1
            }

            if animation == .sad {
                while !Task.isCancelled {
                    sadToken += 1
                    try? await Task.sleep(for: .seconds(2.2))
                }
            }

        }
    }

    private var breathIn: Bool { isLive && breathing }

    /// Standing there being alive: breathing, blinking, glancing about. `gloomy`
    /// is `idle` wearing a different lid, so every one of those has to keep
    /// running — a sad creature that stops breathing reads as a frozen screen.
    private var isLive: Bool { animation == .idle || animation == .gloomy }

    /// How far the upper lid hangs over the eye, 0 to 1.
    ///
    /// Sadness is drawn by dropping the *outer* corner: the lid comes down at an
    /// angle so the two eyes tilt away from each other. Level lids just make it
    /// look sleepy, and lids low on the inner corners make it look cross.
    private var hood: CGFloat { animation == .gloomy ? 1 : 0 }

    // MARK: - Body

    private var body_: some View {
        Ellipse()
            .fill(
                // Lit from above: the top edge is where a rounded, soft thing
                // catches light, and it is most of what makes this read as a
                // volume rather than a flat blob.
                LinearGradient(
                    colors: [Theme.green.opacity(0.92), Theme.greenEdge],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(Ellipse().strokeBorder(Theme.green.opacity(0.85), lineWidth: size * 0.022))
            .frame(width: size, height: size * 0.84)
    }

    // MARK: - Face

    private var face: some View {
        VStack(spacing: size * 0.045) {
            HStack(spacing: size * 0.10) {
                eye(side: -1)
                eye(side: 1)
            }
            mouth
        }
        .offset(y: size * 0.02)
    }

    /// Big enough to take up most of the face, with a fat pupil and a catchlight.
    ///
    /// Three things do the work here and none of them is the size alone: the eye
    /// is nearly a third of the body, the pupil is big and sits slightly low, and
    /// there is a white dot in it. The dot is the difference between an eye and a
    /// button — it is what makes something look like it is looking back.
    private func eye(side: CGFloat) -> some View {
        // Height, not scale.
        //
        // Three attempts at closing this eye with a transform failed: the
        // breathing animation swallowed the first, a cubic keyframe never
        // reached the target on the second, and scaling to zero still left
        // something on screen on the third. Layout is not animated by anything
        // upstream, so an ellipse whose height is driven directly always lands
        // exactly where it is told.
        ZStack {
            if lid > 0.2 {
                Ellipse()
                    .fill(.white)
                    .overlay(Ellipse().strokeBorder(Theme.greenEdge.opacity(0.35), lineWidth: size * 0.010))
                    .overlay {
                        pupil
                            .offset(
                                x: size * (dizzy(side: side).x + gaze),
                                y: size * pupilDrop + size * dizzy(side: side).y
                            )
                    }
                    // Water sits over the pupil, not under it — the pupil is
                    // meant to look submerged. Drawn before the clip so the
                    // eye's own outline does the shaping and the pool never
                    // needs to know what shape it is filling.
                    .overlay {
                        if welling {
                            Waterline(level: waterLevel(side: side), phase: waterPhase(side: side))
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.tearLight, Theme.tear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                    // Clipped so the pupil disappears behind the lid as it comes
                    // down, instead of poking out of a squashed eye.
                    .clipShape(Ellipse())
                    .frame(width: size * eyeSpan, height: size * eyeSpan * lid)
                    // A mask rather than a green shape laid on top: the body is
                    // a gradient, so anything painted over the eye would have to
                    // guess at the colour underneath and would be visibly off at
                    // one end. Cutting the eye away lets the real body show
                    // through, whatever shade it happens to be there.
                    .mask(Hood(droop: hood, side: side))
            } else if animation == .celebrate {
                // Closed and curved upward: the same shut eye, smiling.
                Smile()
                    .stroke(Theme.text, style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round))
                    .rotationEffect(.degrees(180))
                    .frame(width: size * 0.24, height: size * 0.075)
            } else {
                // Shut: cartoons draw a closed eye as a line, and a line is also
                // the one thing that cannot be mistaken for a nearly-open eye.
                Capsule()
                    .fill(Theme.text)
                    .frame(width: size * 0.26, height: size * 0.024)
            }
        }
        .frame(width: size * eyeSpan, height: size * eyeSpan)
        // Outside the frame's bounds on purpose, and nothing between here and
        // the body clips, so the drop is free to run down the cheek.
        .overlay(alignment: .bottom) { tear(side: side) }
        // Eyes drift out of line with each other while dizzy — a face whose two
        // halves disagree is most of the read, more than the spinning itself.
        .offset(y: size * dizzy(side: side).y * 0.5)
        // Nothing about the eye is ever animated by SwiftUI.
        //
        // The lid is already a per-frame value, so any inherited animation just
        // interpolates between frames — which is what turned a blink into the
        // eye fading out green and back instead of closing. `transaction` clears
        // whatever the ancestors published for this subtree.
        .transaction { $0.animation = nil }
    }

    /// The pupil, and the catchlights that keep it from reading as a hole.
    ///
    /// Two of them when it is sad, not one. A single dot is enough to make an
    /// eye look alive, but the pleading look — the emoji, a cartoon dog, Duo on
    /// the way out of a lesson — is built on a pupil that swallows most of the
    /// eye with a big highlight high on one side and a small one low on the
    /// other. The pair is what makes the eye read as wet.
    private var pupil: some View {
        Circle()
            .fill(Theme.text)
            .frame(width: size * pupilSpan)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white)
                    .frame(width: size * (welling ? 0.088 : 0.048))
                    .padding(size * (welling ? 0.020 : 0.014))
            }
            .overlay(alignment: .bottomTrailing) {
                // Only on the sad eye: on the everyday one it turns a clean
                // cartoon eye into a glassy sphere.
                Circle()
                    .fill(.white)
                    .frame(width: size * (welling ? 0.046 : 0))
                    .padding(size * 0.026)
            }
    }

    /// Whether the eye is doing the big wet-pupil act.
    private var welling: Bool { animation == .gloomy }

    /// How much of the eye the water fills, bottom up.
    ///
    /// Just under half. Lower and it reads as a blue smudge along the lid;
    /// higher and the pupil drowns, which loses the one part of the eye that
    /// was doing the pleading.
    ///
    /// The whole pool breathes a little around that mark. The ripples alone
    /// only wobble the surface; nudging the level too is what makes it look
    /// like there is weight sloshing about behind them.
    private func waterLevel(side: CGFloat) -> CGFloat {
        guard clock > 0 else { return 0.44 }

        let slosh = sin(CGFloat(clock) * 1.9) * 0.013

        // Only the eye that actually cried loses any water. Draining both would
        // put the give-away symmetry straight back in: the tear alternates, but
        // the two pools would still rise and fall as one.
        let refill = 1.5
        guard let age = weepAge(side: side), age < refill else { return 0.44 + slosh }
        let recovered = CGFloat(age / refill)

        return 0.44 + slosh - 0.15 * (1 - recovered * recovered)
    }

    /// How long a tear takes to clear the face.
    private var fallSpan: Double { 0.95 }

    /// The tear rolling down the cheek, if one is out right now.
    ///
    /// A sibling of the eye rather than part of it: the eye clips everything to
    /// an ellipse, which is exactly what makes the pool work, and exactly what
    /// would swallow a drop trying to leave. It falls with gravity — distance
    /// on the square of time — because a drop travelling at a constant speed
    /// looks like it is being dragged down on a string.
    @ViewBuilder
    private func tear(side: CGFloat) -> some View {
        if let age = weepAge(side: side), age < fallSpan {
            let t = CGFloat(age / fallSpan)

            Drop()
                .fill(
                    LinearGradient(
                        colors: [Theme.tearLight, Theme.tear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.062, height: size * 0.092)
                // Swells out of the lid over the first fifth instead of
                // popping into existence at full size.
                .scaleEffect(min(1, t * 5), anchor: .top)
                // Gone before it reaches the feet — a tear that lands looks
                // like a leak.
                .opacity(t > 0.75 ? Double(1 - (t - 0.75) / 0.25) : 1)
                .offset(
                    // Hangs off the outer corner, where the lid is lowest.
                    x: side * size * eyeSpan * 0.30,
                    y: size * (eyeSpan * 0.34 + 0.62 * t * t)
                )
        }
    }

    /// The clock, offset per eye.
    ///
    /// Without the offset both eyes ripple identically and the face turns into
    /// a mirror — the same tell as the dizzy pupils, in reverse. A beat of
    /// difference is enough; they still have to look like one creature.
    private func waterPhase(side: CGFloat) -> CGFloat {
        guard clock > 0 else { return 0 }
        return CGFloat(clock) + (side > 0 ? 0.63 : 0)
    }

    /// How wide the whole eye is, as a fraction of the body.
    ///
    /// The sad eye is bigger. Grown-up proportions read as competent; the eye
    /// taking over the face is the oldest trick there is for asking to be
    /// forgiven, and it is doing more work here than the lid.
    private var eyeSpan: CGFloat { welling ? 0.345 : 0.30 }

    /// The pupil, as a fraction of the body. Nearly two thirds of the eye when
    /// sad — past that the white disappears and it stops looking like an eye.
    private var pupilSpan: CGFloat {
        switch animation {
        case .sad: 0.10
        case .gloomy: 0.225
        default: 0.145
        }
    }

    /// Where the pupil sits in the eye.
    ///
    /// Low, for both flavours of unhappy. A hooded eye with a centred pupil
    /// reads as sleepy — it is the pupil sinking toward the bottom lid that
    /// turns the same shape into downcast.
    private var pupilDrop: CGFloat {
        switch animation {
        case .sad: 0.055
        // Barely below centre. Pleading looks *up* at you — dropping a pupil
        // this large would only push it out of sight under the bottom lid.
        case .gloomy: 0.010
        default: 0.018
        }
    }

    /// An occasional look to one side and back while idle.
    ///
    /// Both pupils move together here — that is the difference between looking
    /// at something and being dizzy, where they disagree. It slides over, holds
    /// long enough to read as attention rather than a twitch, and returns.
    private var gaze: CGFloat {
        guard isLive, clock > 0 else { return 0 }

        let period = 7.4
        let cycle = (clock / period).rounded(.down)
        let phase = clock.truncatingRemainder(dividingBy: period)

        // Alternating sides, so it is not always glancing the same way.
        let side: CGFloat = cycle.truncatingRemainder(dividingBy: 2) == 0 ? 1 : -1
        let reach: CGFloat = 0.032
        let move = 0.22, hold = 1.25
        let t = phase - 3.1

        guard t > 0, t < move + hold + move else { return 0 }

        if t < move { return side * reach * CGFloat(t / move) }
        if t < move + hold { return side * reach }
        return side * reach * CGFloat(1 - (t - move - hold) / move)
    }

    /// Pupils rolling in circles after the spin, unwinding to a stop.
    ///
    /// The two eyes run in opposite directions, which is the part that reads as
    /// dizzy rather than as looking around: a face whose halves disagree with
    /// each other. The radius decays to zero so it recovers rather than being
    /// switched off, and the whole thing is a function of the clock, so nothing
    /// upstream can animate over it.
    private func dizzy(side: CGFloat) -> (x: CGFloat, y: CGFloat) {
        guard animation == .arrive else { return (0, 0) }

        let t = clock - arrivedAt - 0.44
        let span = 1.5
        guard t > 0, t < span else { return (0, 0) }

        let radius = 0.030 * dizzyLevel
        let angle = t * .pi * 3.4 * side

        return (CGFloat(cos(angle)) * radius, CGFloat(sin(angle)) * radius * 0.7)
    }

    /// How open the eye is right now, straight from the clock.
    ///
    /// A 3.2s cycle with the blink in a fixed window near its end, nudged by the
    /// cycle number so the gaps are uneven. No stored animation state at all:
    /// the value is a pure function of time, which is why nothing upstream can
    /// interfere with it.
    private var lid: CGFloat {
        // Shut for the whole celebration: the happy arc is a closed eye, so it
        // is reached through the same value everything else uses. Swapping the
        // eye for a different view was what made SwiftUI cross-fade the two.
        // Shut for the flight, opening on the landing. Faces that arrive a few
        // frames behind the body are what make a jump look like something alive
        // rather than an image being moved.
        if animation == .arrive {
            let t = clock - arrivedAt
            return t < 0.34 ? 0 : min(1, CGFloat((t - 0.34) / 0.14))
        }
        if animation == .celebrate { return 0 }
        guard isLive, clock > 0 else { return 1 }

        let cycle = (clock / blinkPeriod).rounded(.down)
        let phase = clock.truncatingRemainder(dividingBy: blinkPeriod)

        let elapsed = phase - blinkStart(cycle)
        guard elapsed > 0, elapsed < blinkClosing + blinkShut + blinkOpening else { return 1 }

        if elapsed < blinkClosing { return 1 - CGFloat(elapsed / blinkClosing) }
        if elapsed < blinkClosing + blinkShut { return 0 }
        return CGFloat((elapsed - blinkClosing - blinkShut) / blinkOpening)
    }

    // MARK: - Blink clock

    private var blinkPeriod: Double { 3.2 }
    private var blinkClosing: Double { 0.10 }
    private var blinkShut: Double { 0.10 }
    private var blinkOpening: Double { 0.16 }

    /// Where in its own cycle a blink begins, nudged by the cycle number so the
    /// gaps between blinks come out uneven.
    private func blinkStart(_ cycle: Double) -> Double {
        2.2 + (cycle.truncatingRemainder(dividingBy: 4)) * 0.18
    }

    /// Absolute time at which the given cycle's lid finishes squeezing shut —
    /// the instant a tear would be pushed out.
    private func squeezedAt(_ cycle: Double) -> Double {
        cycle * blinkPeriod + blinkStart(cycle) + blinkClosing + blinkShut
    }

    /// Which blink most recently finished, and how long ago.
    ///
    /// Counted against absolute time, not against the position inside the
    /// current cycle. The blink lands near the end of its 3.2s window, so a
    /// phase-based count rolls over a fraction of a second later and would cut
    /// the tear off in mid-air every single time.
    private var lastBlink: (cycle: Double, ago: Double) {
        guard isLive, clock > 0 else { return (0, .infinity) }

        let cycle = (clock / blinkPeriod).rounded(.down)
        let latest = squeezedAt(cycle)
        if clock >= latest { return (cycle, clock - latest) }

        let previous = cycle - 1
        return (previous, clock - squeezedAt(previous))
    }

    /// Which eye, if either, sheds a tear on the blink ending `cycle`.
    ///
    /// One tear every third blink, and the eyes take turns. Every blink from
    /// both eyes at once was the thing that read as wailing: two drops falling
    /// in perfect mirror is a lot of water, and it is also the giveaway that
    /// there is a formula behind it. Alternating means a tear never has a twin
    /// to be symmetrical with.
    private func weepingSide(_ cycle: Double) -> CGFloat {
        guard cycle >= 0, cycle.truncatingRemainder(dividingBy: 3) == 0 else { return 0 }

        let turn = (cycle / 3).rounded(.down)
        return turn.truncatingRemainder(dividingBy: 2) == 0 ? -1 : 1
    }

    /// How long after the lid opens this eye lets go.
    ///
    /// The right one hangs on a beat longer. Small, but it stops the tears
    /// arriving on a metronome when several go by in a row.
    private func weepDelay(side: CGFloat) -> Double { side > 0 ? 0.15 : 0 }

    /// How long ago this eye let a tear go, if it is the one crying.
    private func weepAge(side: CGFloat) -> Double? {
        guard welling else { return nil }

        let (cycle, ago) = lastBlink
        guard weepingSide(cycle) == side else { return nil }

        let age = ago - weepDelay(side: side)
        return age >= 0 ? age : nil
    }


    /// One mouth on screen at a time, switched hard.
    ///
    /// Scaling one down while the other grew meant both were visible together
    /// through the middle of the change. There is nothing to interpolate here:
    /// while it is dizzy the mouth is an "O" at full size, and the moment the
    /// eyes stop rolling it is the normal curve again.
    private var mouth: some View {
        ZStack {
            Mouth(curve: mouthCurve, tilt: mouthTilt)
                .stroke(Theme.text.opacity(0.85), style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
                .frame(width: isDizzy ? 0 : size * 0.16, height: size * 0.05)
                .offset(y: mouthDrop)

            Ellipse()
                .fill(Theme.text.opacity(0.85))
                .frame(
                    width: isDizzy ? size * 0.085 : 0,
                    height: isDizzy ? size * 0.105 : 0
                )
        }
        .frame(width: size * 0.16, height: size * 0.11)
        .transaction { $0.animation = nil }
    }

    /// How far the mouth bends: 1 content, 0 flat, negative unhappy.
    private var mouthCurve: CGFloat {
        switch animation {
        case .sad: -0.75
        case .gloomy: -0.62
        default: 1.0
        }
    }

    /// How much lower one corner hangs than the other.
    ///
    /// The flinch gets the harder lean — that one is a wince, and a wince is
    /// lopsided. The pleading face is closer to symmetric: too much tilt there
    /// starts to read as a smirk rather than a wobbling lip.
    private var mouthTilt: CGFloat {
        switch animation {
        case .sad: 0.45
        case .gloomy: 0.18
        default: 0
        }
    }

    /// An unhappy mouth also sits lower on the face, not just upside down.
    private var mouthDrop: CGFloat {
        switch animation {
        case .sad: size * 0.035
        case .gloomy: size * 0.030
        default: 0
        }
    }

    /// Dizzy or not — no in-between, so the two mouths are never on screen together.
    private var isDizzy: Bool { dizzyLevel > 0 }

    /// How dizzy it is right now, 1 down to 0. Shared by the pupils and the
    /// mouth so the whole face sobers up at the same rate.
    private var dizzyLevel: CGFloat {
        guard animation == .arrive else { return 0 }

        let t = clock - arrivedAt - 0.44
        let span = 1.5
        guard t > 0, t < span else { return 0 }

        // Ramp in over the first 180ms instead of snapping to full.
        //
        // The decay out was already gradual, but the way in jumped straight to
        // 1 — so the "O" appeared fully formed and there was no transition to
        // see at either end of the same shape.
        let rampIn = 0.18
        if t < rampIn { return CGFloat(t / rampIn) }
        return CGFloat(1 - ((t - rampIn) / (span - rampIn)))
    }

    // MARK: - Feet

    private var feet: some View {
        HStack(spacing: size * 0.30) {
            foot
            foot
        }
        .offset(y: size * 0.40)
    }

    private var foot: some View {
        Ellipse()
            .fill(Theme.greenEdge)
            .frame(width: size * 0.26, height: size * 0.20)
    }
}

/// What the lab can play. One at a time, so each can be judged on its own.
enum CreatureAnimation: String, CaseIterable, Identifiable {
    case none = "Parado"
    /// Breathing and blinking together — one state, because that is what being
    /// alive and doing nothing actually looks like. They were split while each
    /// was being tuned; keeping them apart afterwards only made it possible to
    /// ship a creature that breathes without ever blinking.
    case idle = "Vivo (respira + pisca)"
    case arrive = "Chegando"
    case celebrate = "Comemorando"
    case sad = "Errou"
    /// `idle` with a hooded eye. Same breathing, same blink, same glance — the
    /// only difference is the lid, and that carries the whole read. It is the
    /// state for the quit card, where the creature has to look let down while
    /// still looking alive.
    case gloomy = "Tristinho (vivo)"

    var id: Self { self }

    var label: String { rawValue }
}

/// Where the body is mid-jump. One value per track so squash, stretch and
/// height can each have their own timing.
private struct JumpPose {
    var width: CGFloat = 1
    var height: CGFloat = 1
    var lift: CGFloat = 0
    var spin: CGFloat = 0
}

/// One mouth that bends both ways instead of two mouths.
///
/// `curve` runs from 1 (content) through 0 (flat) to negative (down), and `tilt`
/// pulls one corner lower than the other. The tilt is the important half: a
/// perfectly symmetrical frown looks like a drawn arc, while a mouth with one
/// corner dragged down looks like an actual face that is unhappy. It also means
/// the two expressions interpolate instead of the whole shape spinning around.
struct Mouth: Shape {

    var curve: CGFloat
    var tilt: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(curve, tilt) }
        set { curve = newValue.first; tilt = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let drop = rect.height * curve
        let lean = rect.height * tilt

        path.move(to: CGPoint(x: rect.minX, y: rect.midY + lean))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - lean * 0.35),
            control: CGPoint(x: rect.midX + rect.width * tilt * 0.35, y: rect.midY + drop * 1.7)
        )
        return path
    }
}

/// A single tear: round at the bottom, drawn to a point at the top.
///
/// The point matters more than the roundness. A plain oval reads as a bead or a
/// bubble; it is the tail — the bit still reaching back toward the eye it just
/// left — that makes the shape say water.
struct Drop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let radius = rect.width / 2
        let belly = CGPoint(x: rect.midX, y: rect.maxY - radius)
        let tip = CGPoint(x: rect.midX, y: rect.minY)

        path.move(to: tip)
        // Out to the widest point, then round the bottom and back up. The
        // control points sit high, which is what keeps the sides concave near
        // the tip instead of bulging into a teardrop-shaped balloon.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: belly.y),
            control: CGPoint(x: rect.midX + radius * 0.72, y: rect.minY + rect.height * 0.42)
        )
        path.addArc(
            center: belly,
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addQuadCurve(
            to: tip,
            control: CGPoint(x: rect.midX - radius * 0.72, y: rect.minY + rect.height * 0.42)
        )
        path.closeSubpath()

        return path
    }
}

/// The pool of water standing in the eye.
///
/// Fills its rect from the bottom up to `level`, with a wavy surface. It is
/// drawn as a plain rectangle-with-a-bumpy-top and left to be clipped by the
/// eye, so it never has to know it is sitting inside an ellipse.
///
/// The surface is sampled from a sine rather than built out of arcs. Two arcs
/// would draw the same shape today, but a sampled line takes a phase offset,
/// and sliding that phase is how this ripples later without redrawing anything.
struct Waterline: Shape {

    /// How full the eye is, 0 to 1.
    var level: CGFloat
    /// Seconds on the shared clock. Slides both waves, in opposite directions.
    var phase: CGFloat = 0
    /// Wave height, as a fraction of the eye. Small — this is a teary eye, not
    /// a glass of water in a moving car.
    var ripple: CGFloat = 0.038

    var animatableData: CGFloat {
        get { level }
        set { level = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard level > 0 else { return path }

        let surface = rect.maxY - rect.height * level
        let amplitude = rect.height * ripple
        // Fine enough that the facets vanish at the size the eye is actually
        // drawn, coarse enough to stay cheap on every frame.
        let steps = 32

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))

        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)

            // Two waves, not one, and deliberately mismatched: different
            // wavelengths, different speeds, opposite directions. A single
            // sine sliding along is a wave machine — you can see the same
            // crest come round again. Two that never line up twice read as a
            // surface that cannot hold still.
            //
            // The quarter-turn head start puts a crest near the middle of the
            // eye rather than a flat crossing, which is what makes a stretch
            // this short read as water at all.
            let slow = sin((t * 1.6 + 0.25) * 2 * .pi + phase * 5.0)
            let fast = sin(t * 2.9 * 2 * .pi - phase * 7.3) * 0.45

            path.addLine(to: CGPoint(
                x: rect.minX + rect.width * t,
                y: surface + (slow + fast) * amplitude
            ))
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The eye, minus whatever the upper lid is covering.
///
/// Used as a mask, so the removed wedge shows the body behind the eye rather
/// than a colour of its own. The lid line is slanted, not level: the outer
/// corner sits far lower than the inner one, which is the single detail that
/// separates sad from sleepy. Mirrored per eye so the pair tilts outward like a
/// pair of raised inner brows.
struct Hood: Shape {

    /// 0 leaves the eye whole; 1 is the full droop.
    var droop: CGFloat
    /// -1 for the left eye, 1 for the right. Decides which corner is "outer".
    var side: CGFloat

    var animatableData: CGFloat {
        get { droop }
        set { droop = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let eye = Path(ellipseIn: rect)
        guard droop > 0 else { return eye }

        // The inner corner barely moves. Almost all of the travel is on the
        // outer one — a lid that comes down evenly just closes the eye.
        //
        // Kept shallow on purpose. The lid is here for the tilt, not for the
        // sadness: that is the pupil's job now, and a heavy lid over a big wet
        // pupil hides the very thing doing the work.
        let inner = rect.height * droop * 0.03
        let outer = rect.height * droop * 0.30

        var lid = Path()
        // Starts well above the eye so the wedge covers the whole top no matter
        // how the rect is squashed mid-blink.
        lid.move(to: CGPoint(x: rect.minX, y: rect.minY - rect.height))
        lid.addLine(to: CGPoint(x: rect.maxX, y: rect.minY - rect.height))
        lid.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + (side > 0 ? outer : inner)))
        lid.addLine(to: CGPoint(x: rect.minX, y: rect.minY + (side > 0 ? inner : outer)))
        lid.closeSubpath()

        return eye.subtracting(lid)
    }
}

/// The upward arc used for happy, closed eyes.
struct Smile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY * 1.6)
        )
        return path
    }
}

/// A scratch screen for looking at the character on its own, away from the game.
struct CharacterLab: View {

    @Environment(\.dismiss) private var dismiss
    @State private var playing: CreatureAnimation = .idle

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 50) {
                Creature(size: 240, animation: playing)

                // The same drawing small, because the map and the tab bar will
                // ask for it at a fraction of this size.
                HStack(spacing: 40) {
                    Creature(size: 90, animation: playing)
                    Creature(size: 44, animation: playing)
                }

                Picker("Animação", selection: $playing) {
                    ForEach(CreatureAnimation.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.greenEdge)
                .font(Theme.label(16, .bold))
            }

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.dim)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                Spacer()
            }
            .padding(.horizontal, 8)
        }
    }
}

#Preview {
    CharacterLab()
}
