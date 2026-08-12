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
    /// Bumped once per leap.
    @State private var leapToken = 0

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
                // The same splay for the leap, on its own clock: the roll takes
                // longer to come down than the spin does.
                .keyframeAnimator(initialValue: 1.0, trigger: leapToken) { view, spread in
                    view.scaleEffect(x: spread, y: 2 - spread, anchor: .bottom)
                } keyframes: { _ in
                    KeyframeTrack {
                        LinearKeyframe(1.0, duration: 1.06)
                        CubicKeyframe(1.34, duration: 0.09)
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
            // The crouch before the leap, on the body and not on the feet.
            //
            // Squashing the whole creature squashed its feet along with it,
            // which is why the wind-up never landed: the feet are the thing it
            // is pushing *against*, and something being pushed against does not
            // give. Keeping them still turns the same squash into weight going
            // down into the floor.
            .keyframeAnimator(initialValue: JumpPose(), trigger: leapToken) { view, pose in
                view.scaleEffect(x: pose.width, y: pose.height, anchor: .bottom)
            } keyframes: { _ in
                // Far more squash than the landing gets, and not because the
                // crouch is heavier — because it happens while the creature is
                // a fifth of its final size. A squash to 0.76 is about ten
                // pixels of travel back there: really running, and impossible
                // to see. Anything that plays at a distance has to be drawn at
                // the size it will be *read* at, not the size it would be.
                // The crouch is *held*, and that is the whole difference.
                //
                // Every version before this one went down and came straight
                // back up, so there was never a frame where the creature was
                // simply crouched — the pose existed only as something passed
                // through on the way somewhere else, and a pose passed through
                // is a pose nobody sees. Anticipation is held by definition:
                // the wind-up is the pause, not the movement into it. It sinks
                // early, sits there while the eye catches up, and only then
                // goes.
                KeyframeTrack(\.width) {
                    LinearKeyframe(1.0, duration: 0.11)
                    CubicKeyframe(1.42, duration: 0.22)
                    LinearKeyframe(1.42, duration: 0.17)
                    CubicKeyframe(1.0, duration: 0.14)
                    LinearKeyframe(1.0, duration: 0.81)
                }
                KeyframeTrack(\.height) {
                    LinearKeyframe(1.0, duration: 0.11)
                    CubicKeyframe(0.52, duration: 0.22)
                    LinearKeyframe(0.52, duration: 0.17)
                    CubicKeyframe(1.0, duration: 0.14)
                    LinearKeyframe(1.0, duration: 0.81)
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
        // The leap.
        //
        // Small at the back of the scene, one somersault forward, and it lands
        // in front at full size. This is the arrival that the walk could not
        // be: a jump has no contact with the floor for most of its length, so
        // there is nothing that *can* slide. Only one frame has to be right,
        // and it is the landing.
        .keyframeAnimator(initialValue: LeapPose(), trigger: leapToken) { view, pose in
            view
                // Over the top, not around like a wheel.
                //
                // Turning it in the picture plane was a cartwheel: the creature
                // stayed face-on and swung round sideways. A somersault goes
                // over the horizontal axis — head down, feet up, back to front.
                .rotation3DEffect(
                    .degrees(pose.flip),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.28
                )
                // Distance and squash in one transform, both anchored at the
                // feet so it grows up off the floor instead of about its middle.
                .scaleEffect(
                    x: pose.scale * pose.width,
                    y: pose.scale * pose.height,
                    anchor: .bottom
                )
                .offset(y: pose.lift)
        } keyframes: { _ in
            // Crouch, throw, roll, land, settle. The crouch is the part that is
            // easy to leave out and impossible to look right without — a jump
            // that starts on the first frame reads as the creature being fired
            // from somewhere rather than deciding to go.
            KeyframeTrack(\.scale) {
                // Bigger at the back than distance alone would put it.
                //
                // At a fifth of full size the crouch had nowhere to happen: the
                // body is thirty-odd pixels tall back there, so squashing it in
                // half buys fifteen pixels and reads as nothing at all. A pose
                // has to be given room to be seen in, and the only room here is
                // scale — so it starts a third of the way in rather than a
                // fifth, and gives up some of the distance to keep the wind-up.
                LinearKeyframe(0.34, duration: 0.01)
                // Standing at the back for a beat before anything happens. The
                // jump used to start on the frame it appeared, which gave the
                // eye nowhere to find it — by the time you noticed something
                // was there it was already halfway across.
                LinearKeyframe(0.34, duration: 0.35)
                CubicKeyframe(0.34, duration: 0.14)
                CubicKeyframe(0.42, duration: 0.16)
                CubicKeyframe(0.92, duration: 0.40)
                CubicKeyframe(1.02, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
            }
            // Starts high, because far away is up near the horizon, and comes
            // down to the floor as it arrives.
            KeyframeTrack(\.lift) {
                LinearKeyframe(-size * 0.52, duration: 0.01)
                LinearKeyframe(-size * 0.52, duration: 0.35)
                CubicKeyframe(-size * 0.52, duration: 0.14)
                CubicKeyframe(-size * 0.60, duration: 0.16)
                CubicKeyframe(-size * 0.05, duration: 0.40)
                CubicKeyframe(0, duration: 0.09)
                SpringKeyframe(0, duration: 0.30, spring: .bouncy)
            }
            // One turn, and nearly all of it in the air. The last twenty degrees
            // are spent on the landing so the roll finishes *into* the floor
            // rather than stopping short and dropping the rest of the way.
            KeyframeTrack(\.flip) {
                LinearKeyframe(0, duration: 0.01)
                LinearKeyframe(0, duration: 0.35)
                LinearKeyframe(0, duration: 0.14)
                CubicKeyframe(-25, duration: 0.16)
                CubicKeyframe(-340, duration: 0.40)
                CubicKeyframe(-360, duration: 0.09)
                LinearKeyframe(-360, duration: 0.30)
            }
            KeyframeTrack(\.width) {
                LinearKeyframe(1.0, duration: 0.01)
                LinearKeyframe(1.0, duration: 0.35)
                // Flat here: the crouch belongs to the body alone now, and it
                // is applied further in, above the feet.
                LinearKeyframe(1.0, duration: 0.14)
                CubicKeyframe(0.88, duration: 0.16)
                CubicKeyframe(1.0, duration: 0.40)
                CubicKeyframe(1.24, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
            }
            KeyframeTrack(\.height) {
                LinearKeyframe(1.0, duration: 0.01)
                LinearKeyframe(1.0, duration: 0.35)
                LinearKeyframe(1.0, duration: 0.14)
                CubicKeyframe(1.20, duration: 0.16)
                CubicKeyframe(1.0, duration: 0.40)
                CubicKeyframe(0.74, duration: 0.09)
                SpringKeyframe(1.0, duration: 0.30, spring: .bouncy)
            }
        }
        // The approach, applied to the creature as a whole.
        //
        // Anchored at the bottom so it grows up off the floor rather than out
        // from its middle — scaling about the centre would sink its feet into
        // the ground on the way in.
        // Flight, as one piece: lean, stretch, and the gentlest of the three
        // jitter weights. The body is what the eye locks onto, so it gets the
        // least movement — the feet below are shaken far harder.
        .scaleEffect(x: flightStretch.width, y: flightStretch.height, anchor: .center)
        .rotationEffect(.degrees(flightLean))
        .offset(x: flightJitter(weight: 0.5).x, y: flightJitter(weight: 0.5).y)
        .scaleEffect(walkScale, anchor: .bottom)
        .rotationEffect(.degrees(walkSway), anchor: .bottom)
        .offset(y: walkRise + walkBob)
        // No `transaction` clearing animations out here.
        //
        // There was one, to stop an inherited animation interpolating between
        // walk frames that are already correct. But it clears the animation for
        // the whole subtree, which meant a creature riding inside something
        // else — the quit card sliding up — refused to travel with it and
        // simply appeared at its final spot while the card moved. The eyes and
        // mouth guard themselves individually; the body does not need to.
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

            if animation == .leapIn {
                // On a loop while it is being tuned. An arrival plays once in
                // the app, but once is not enough to judge one by: the whole
                // thing is over in a second and the eye needs several passes to
                // find what is wrong with it.
                while !Task.isCancelled {
                    // The stopwatch is what the eye reads off, so it has to be
                    // set before the token is bumped.
                    arrivedAt = Date.timeIntervalSinceReferenceDate
                    leapToken += 1
                    try? await Task.sleep(for: .seconds(2.6))
                }
            }

            if animation == .walkIn {
                // Same stopwatch, same reason: the walk plays once and then the
                // creature is simply standing there.
                arrivedAt = Date.timeIntervalSinceReferenceDate
            }

            if animation == .sad {
                while !Task.isCancelled {
                    sadToken += 1
                    try? await Task.sleep(for: .seconds(2.2))
                }
            }

        }
    }

    /// Flying is excluded: the body is already held stretched, and a breath
    /// swelling it on top of that reads as the pose wobbling loose rather than
    /// as something alive.
    private var breathIn: Bool { isLive && breathing && animation != .flying }

    /// Standing there being alive: breathing, blinking, glancing about. `gloomy`
    /// is `idle` wearing a different lid, so every one of those has to keep
    /// running — a sad creature that stops breathing reads as a frozen screen.
    private var isLive: Bool {
        animation == .idle || animation == .gloomy || animation == .joy
            || animation == .walkIn || animation == .leapIn || animation == .serious
            || animation == .wtf || animation == .flying
    }

    /// How far the upper lid hangs over the eye, 0 to 1.
    ///
    /// Sadness is drawn by dropping the *outer* corner: the lid comes down at an
    /// angle so the two eyes tilt away from each other. Level lids just make it
    /// look sleepy, and lids low on the inner corners make it look cross.
    private var hood: CGFloat {
        animation == .gloomy || animation == .serious || animation == .flying ? 1 : 0
    }

    /// Which corner of the lid is the low one.
    ///
    /// Sadness drops the outer corners and the two eyes tilt away from each
    /// other; a scowl drops the inner ones and they tilt toward the nose. Same
    /// lid, same amount, opposite direction — and that single sign flip is the
    /// difference between miserable and having had enough.
    /// Flight deliberately stays `false`, which puts the low corner at the
    /// *front* of the single visible eye.
    ///
    /// In profile there is no inner and outer any more — there is leading and
    /// trailing. A lid dropping toward the back of the head reads as looking
    /// over its own shoulder; dropping toward the front is a creature squinting
    /// at where it is headed, which is the whole expression in the reference.
    private var hoodInward: Bool { animation == .serious }

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

    /// Turned side-on, one eye showing.
    ///
    /// I argued against this and was wrong. A front-facing head laid flat reads
    /// as a creature toppling over, not flying — so the profile is what lets
    /// the body lie horizontal at all. The two go together or neither works.
    private var inProfile: Bool { animation == .flying }

    private var face: some View {
        VStack(spacing: size * 0.045) {
            HStack(spacing: size * 0.10) {
                eye(side: -1)
                // The far eye is simply not drawn. Dropping it lets the HStack
                // recentre on the one that is left, and the offset below then
                // carries the whole face toward the direction of travel — which
                // is all "looking where you are going" has ever meant.
                if !inProfile { eye(side: 1) }
            }
            // Narrowed, not shrunk. A profile eye is the same eye seen at an
            // angle, so it loses width and keeps its height — this is the one
            // thing every side-view guide agrees on, and skipping it leaves a
            // front-facing eye stuck on a side-facing head.
            .scaleEffect(x: inProfile ? 0.84 : 1, anchor: .leading)

            mouth
                // Still ahead of the eye, but only just. At 0.12 the front end
                // crossed the body outline and hung in open sky — and a line
                // that starts outside the character reads as something he is
                // carrying, not as part of his face. The body narrows toward
                // the chin, so there is less room down here than the widest
                // point suggests.
                .offset(x: inProfile ? -size * 0.05 : 0)
        }
        // You were right — this was too shy at 0.19. On a profile the features
        // crowd the leading edge and leave the whole back of the head empty;
        // keeping them near the centre is what made it look like a front-facing
        // face that had merely slid sideways.
        .offset(x: inProfile ? -size * 0.30 : 0, y: size * 0.02)
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
            // The everyday eye with the inside taken out.
            //
            // Same ellipse, same white, same faint edge — the pupil and the
            // catchlight are simply not drawn. Those two are the whole of what
            // makes an eye look like it is looking at you, so removing them and
            // changing nothing else is what leaves it staring at nothing.
            if animation == .wtf {
                Ellipse()
                    .fill(.white)
                    .overlay(Ellipse().strokeBorder(Theme.greenEdge.opacity(0.35), lineWidth: size * 0.010))
                    .frame(width: size * eyeSpan, height: size * eyeSpan)
            } else if lid > 0.2 {
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
                                .opacity(tearAlpha)
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
                    .mask(Hood(droop: hood, side: side, inward: hoodInward))
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
        .overlay(alignment: .top) { brow(side: side) }
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

    /// The angled brow, and the entire serious face.
    ///
    /// Slanted down toward the middle and mirrored, so the pair makes a shallow
    /// V over the eyes. That angle is the whole expression — the eyes are the
    /// everyday ones and the mouth is a flat line. It is also the part of a face
    /// that survives being shrunk: at the size this thing sits on the map, a
    /// mouth is three pixels and a brow is still a brow.
    ///
    /// Thick on purpose. A thin brow at this scale reads as a scratch on the
    /// drawing rather than as part of the face.
    @ViewBuilder
    private func brow(side: CGFloat) -> some View {
        if animation == .serious {
            Capsule()
                .fill(Theme.text)
                .frame(width: size * 0.34, height: size * 0.052)
                // Mirrored: the inner end of each brow is the low one, which is
                // what makes a pair of lines read as a scowl instead of a frame.
                .rotationEffect(.degrees(-side * 26))
                // Down onto the eye, past where the frame's top edge is.
                //
                // Lining it up with the top of the eye's *box* left it floating,
                // because the lid now cuts almost half the eye away at the inner
                // corner and the box top is nowhere near what you can see. It
                // has to be placed against the shape that is actually drawn.
                // Centred on the eye, not pushed outward.
                //
                // The outward nudge was what opened the gap at the inner end:
                // it slid the whole brow away from the nose, and the inner tip
                // — the end that has to land on the eye — went with it. The eye
                // is an ellipse, so its inner corner curves away well inside the
                // box it is laid out in; the brow has to reach past the box edge
                // to meet the shape that is actually drawn, and overlapping is
                // right. A brow resting *on* an eye is a brow pressing it shut.
                .offset(y: size * 0.075)
        }
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
            // A third one, only for joy.
            //
            // Two highlights make an eye look wet. Three, at three different
            // sizes, make it look *glassy* — the cartoon shorthand for brimming
            // over. It is also the cheapest way to tell the two teary faces
            // apart at a glance, before anyone gets as far as the mouth.
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(.white)
                    .frame(width: size * (animation == .joy ? 0.030 : 0))
                    .padding(size * 0.022)
            }
    }

    /// Whether the eye is doing the big wet-pupil act.
    private var welling: Bool { animation == .gloomy || animation == .joy }

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

    /// How solid the water reads, in the eye and on the cheek.
    ///
    /// One value for both: the pool and the drop are the same water, and any
    /// gap between them shows the moment one leaves the other. Short of opaque
    /// so the pupil stays visible under the surface, which is most of what
    /// makes the eye look wet rather than painted blue.
    private var tearAlpha: Double { 0.72 }

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
                .opacity(tearAlpha * (t > 0.75 ? Double(1 - (t - 0.75) / 0.25) : 1))
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
    private var eyeSpan: CGFloat {
        switch animation {
        // Wider than the sad one. Sadness half-closes an eye; being moved to
        // tears throws it open, and the widest eye on the face is the one that
        // reads as overwhelmed rather than miserable.
        case .joy: 0.375
        case .gloomy: 0.345
        default: 0.30
        }
    }

    /// The pupil, as a fraction of the body. Nearly two thirds of the eye when
    /// sad — past that the white disappears and it stops looking like an eye.
    private var pupilSpan: CGFloat {
        switch animation {
        case .sad: 0.10
        case .gloomy: 0.225
        case .joy: 0.245
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
        // Fractionally high, so it looks up rather than out. An eye brimming
        // over while aiming downward is just crying.
        case .joy: -0.006
        default: 0.018
        }
    }

    /// An occasional look to one side and back while idle.
    ///
    /// Both pupils move together here — that is the difference between looking
    /// at something and being dizzy, where they disagree. It slides over, holds
    /// long enough to read as attention rather than a twitch, and returns.
    private var gaze: CGFloat {
        // In flight it stops wandering and locks forward.
        //
        // A centred pupil is the tell that nobody is driving — the eye can be
        // as narrowed as you like, but if the dot sits in the middle he is
        // squinting at nothing in particular. Pinning it to the leading edge is
        // what turns the squint into aim. Returning early also kills the idle
        // glance, which up here would read as him looking around for the exit.
        if animation == .flying { return -0.055 }

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
        // Screwed shut through the roll, open on the way down.
        //
        // Nobody somersaults with their eyes open, and more to the point a face
        // that keeps looking straight ahead while the body turns over is the
        // fastest way to make a flip read as a texture spinning on a card.
        if animation == .leapIn {
            let t = clock - arrivedAt
            if t < 0.50 { return 1 }
            return t < 1.03 ? 0 : min(1, CGFloat((t - 1.03) / 0.12))
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
        // Joy wells up and stays welled up. A drop running down the cheek drags
        // the read straight back toward crying, and the whole point of this
        // face is that the water never wins.
        guard animation == .gloomy else { return nil }

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
            // A box, not a curve. Every other mouth here bends; this one has
            // given up on having an opinion. White inside and edged like the
            // eyes, so the three shapes on this face are plainly the same
            // material — a mouth drawn any other way would read as a hole.
            if animation == .wtf {
                RoundedRectangle(cornerRadius: size * 0.014, style: .continuous)
                    .fill(.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.014, style: .continuous)
                            .strokeBorder(Theme.greenEdge.opacity(0.35), lineWidth: size * 0.010)
                    )
                    .frame(width: size * 0.13, height: size * 0.105)
            }

            Mouth(curve: mouthCurve, tilt: mouthTilt)
                .stroke(Theme.text.opacity(0.85), style: StrokeStyle(lineWidth: size * 0.018, lineCap: .round))
                // Halved in profile, and for a literal reason: side-on you can
                // only see the front half of a mouth — the back half has gone
                // around the cheek. Drawn at full width it stops reading as a
                // mouth and starts reading as a stick held in one.
                .frame(
                    width: isDizzy || beaming || animation == .wtf
                        ? 0
                        : size * (inProfile ? 0.075 : 0.16),
                    height: size * 0.05
                )
                .offset(y: mouthDrop)

            openMouth

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

    /// Whether the grin is wide enough to be open.
    private var beaming: Bool { animation == .joy }

    /// An open smile with a tongue sitting in the bottom of it.
    ///
    /// No teeth. Teeth on a shape this simple turn a grin into a grimace —
    /// they need a jaw and a lip line to sit in, and this face has neither.
    /// The tongue does the same job of giving the mouth a floor, and it does it
    /// with one soft shape instead of a row of hard ones.
    @ViewBuilder
    private var openMouth: some View {
        if beaming {
            OpenSmile()
                .fill(Theme.text.opacity(0.88))
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(Theme.tongue)
                        .frame(width: size * 0.105, height: size * 0.070)
                        // Pushed below the lip so only its top curve shows,
                        // the way a tongue actually sits in an open mouth.
                        .offset(y: size * 0.026)
                }
                .clipShape(OpenSmile())
                .frame(width: size * 0.185, height: size * 0.105)
                .offset(y: size * 0.014)
        }
    }

    /// How far the mouth bends: 1 content, 0 flat, negative unhappy.
    private var mouthCurve: CGFloat {
        switch animation {
        case .sad: -0.75
        case .gloomy: -0.62
        // Dead flat. A serious mouth that curves at all picks a side — up is
        // smug, down is sulking — and the brows are already saying the thing.
        case .serious: 0
        // Also flat, and for a reason worth keeping separate from `serious`:
        // the smile was the thing making him look like he was enjoying a ride
        // rather than going somewhere. The reference has no smile at all — a
        // beak and a squint, nothing else. Effort does not grin.
        case .flying: 0
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
        // In flight they draw together and shrink — pointed back and away from
        // camera, like a diver's. Trailing behind and shaken three times as
        // hard as the body: extremities lag and whip, and that difference is
        // most of what says "moving fast" rather than "vibrating".
        // In flight the HStack stops doing the placing — `flightStride` puts
        // each foot where it belongs, so the spacing collapses to nothing and
        // the pair rises from under the body to the middle of it.
        HStack(spacing: size * (animation == .flying ? 0 : 0.30)) {
            foot(side: -1)
            foot(side: 1)
        }
        .offset(
            x: flightJitter(weight: 1.6).x,
            y: size * (animation == .flying ? 0.06 : 0.40) + flightJitter(weight: 1.6).y
        )
    }

    private func foot(side: CGFloat) -> some View {
        let pose = step(side)
        let air = flightStride(side: side)

        return Ellipse()
            .fill(Theme.greenEdge)
            .frame(width: size * 0.26, height: size * 0.20)
            // Drawn out lengthwise in flight — a round foot trailing behind
            // reads as a dropped ball, a long one reads as a leg.
            .scaleEffect(
                x: animation == .flying ? 1.55 : 1,
                y: animation == .flying ? 0.70 : 1
            )
            .scaleEffect(pose.scale * air.scale)
            .offset(x: pose.x + air.x, y: pose.y + air.y)
            // The forward foot passes in front of the other one. Works for the
            // walk and the flight alike, because both say "nearer" the same
            // way — by being drawn bigger.
            .zIndex(pose.scale * air.scale)
    }

    // MARK: - Walking in

    /// How long the approach takes, door to standstill.
    private var walkSpan: Double { 2.6 }

    /// Seconds since the walk began, on the creature's own clock.
    private var walkElapsed: Double { (clock - arrivedAt) / LabLaunch.timeScale }

    /// 0 at the back of the scene, 1 standing at full size.
    private var walkProgress: CGFloat {
        guard animation == .walkIn, clock > 0 else { return 1 }
        return CGFloat(min(1, max(0, walkElapsed / walkSpan)))
    }

    /// How big it looks right now.
    ///
    /// Squared rather than linear. Apparent size goes as one over distance, so
    /// something walking toward you at a steady pace appears to grow slowly for
    /// most of the trip and then rush the last few steps. A linear ramp reads as
    /// a picture being zoomed rather than as something coming closer.
    private var walkScale: CGFloat {
        guard animation == .walkIn else { return 1 }
        let p = walkProgress
        return 0.20 + 0.80 * p * p + surge
    }

    /// The lurch forward on each planted foot.
    ///
    /// A body that closes the distance at a perfectly even rate is a body on
    /// rails, and that even rate is most of what reads as sliding. Real walking
    /// gains ground in shoves: the planted foot pushes, the body surges, the
    /// swing foot catches up. Twice the step rate, because each foot gets a
    /// shove of its own.
    private var surge: CGFloat {
        guard animation == .walkIn, walkProgress < 1 else { return 0 }
        // Tied to how close it is, so the shoves grow with the creature instead
        // of being a fixed wobble that dominates while it is still tiny.
        //
        // `cos`, not `sin`. A foot plants at stride π/2 and stays down until
        // 3π/2, so mid-stance — the middle of the shove — falls on 0 and π.
        // The old `sin` put the shove exactly on the changeover, so the body
        // gained ground while both feet were swapping and coasted while one was
        // pushing. Right rhythm, wrong half of it, which is why it still slid.
        return CGFloat(cos(stride * 2)) * 0.022 * walkScaleBase
    }

    /// The smooth part of the approach, without the shoves — used to size them.
    private var walkScaleBase: CGFloat {
        let p = walkProgress
        return 0.20 + 0.80 * p * p
    }

    /// How far up the screen it is.
    ///
    /// This is what actually sells the depth. Things further away sit closer to
    /// the horizon, so the walk starts high and settles down to the floor as it
    /// arrives — scale alone, without the drop, just looks like growing.
    private var walkRise: CGFloat {
        guard animation == .walkIn else { return 0 }
        let p = walkProgress
        return -size * 0.42 * (1 - p * p)
    }

    /// The pace, in radians. One full turn is a pair of steps.
    ///
    /// Slows as it gets close, so it comes to rest instead of stopping dead.
    private var stride: Double {
        guard animation == .walkIn, clock > 0 else { return 0 }
        return walkElapsed * 5.0 * (1 - 0.45 * Double(walkProgress))
    }

    /// Where one foot is in its step: out to the side, up off the floor, and
    /// how big that makes it look.
    ///
    /// The front-to-back travel is gone, and that is the whole fix for the
    /// slide. A foot cannot look planted while it is moving, and it was moving:
    /// the old cycle walked each foot from near to far across its own stance,
    /// which is only correct if the body crosses the same distance the other
    /// way. Head-on the body does not cross anything — it grows — so the travel
    /// had nothing to be still against and read as the foot slipping backwards
    /// on the floor.
    ///
    /// Round cartoons all solve this the same way, and it is a waddle: the
    /// planted foot does not move *at all*, the swing foot lifts and arcs wide,
    /// and the body rocks over the top. The weight comes from the rocking.
    ///
    /// `max(0, cos)` is what splits the cycle — positive over the half the foot
    /// is in the air, clamped flat over the half it is carrying the creature.
    private func step(_ side: CGFloat) -> (x: CGFloat, y: CGFloat, scale: CGFloat) {
        guard animation == .walkIn, walkProgress < 1 else { return (0, 0, 1) }

        let phase = stride + (side > 0 ? .pi : 0)
        let lift = max(0, cos(phase))

        // Planted: the one thing on screen that holds still.
        //
        // The rock has to be subtracted back out here. Both the bob and the
        // sway are applied to the whole creature, feet included, so without this
        // the floor rode up and leaned along with everything standing on it —
        // and a foot that travels with the body is not a foot, it is a sticker.
        guard lift > 0 else {
            return (x: 0, y: -rockOffset(side), scale: 1)
        }

        return (
            // The swing foot goes *around* rather than through.
            //
            // A creature with no legs cannot pass a foot under its own middle,
            // and if it tries, the foot spends the airborne half of the cycle
            // hidden behind the body — which is exactly what was happening.
            x: side * CGFloat(lift) * size * 0.085,
            // Raised. The old lift was a third of this, and against a body it
            // has to climb out from behind, a small lift is no lift: the foot
            // ducked under the belly and came back without ever reading as a
            // step. High enough now that the sole clears the body's outline.
            y: -CGFloat(lift) * size * 0.078,
            // Nearest the camera at the top of its arc, which is the only depth
            // cue left now that the travel is gone — and the only one that was
            // ever honest, because a swinging foot really does come forward.
            scale: 1 + CGFloat(lift) * 0.10
        )
    }

    /// How far the body's own rocking carries a foot, in the foot's own units.
    ///
    /// Subtracted from the planted foot so it stays where it was put. The bob is
    /// applied outside the scale, in screen points, so it has to be divided back
    /// down; the sway is a rotation about the creature's feet, and at these
    /// angles all it does to something sitting off to one side is lift it.
    private func rockOffset(_ side: CGFloat) -> CGFloat {
        let leaned = side * 0.28 * size * CGFloat(sin(walkSway * .pi / 180))
        return walkBob / walkScale + leaned
    }

    /// The body rocking over each planted foot.
    ///
    /// Twice the step rate, because the body dips once per foot. Without it the
    /// legs move under a body that glides along like it is on rails.
    private var walkBob: CGFloat {
        guard animation == .walkIn, walkProgress < 1 else { return 0 }

        // Highest over the planted foot, lowest at the changeover — a walk
        // rides up over a straight supporting leg and sinks when the weight is
        // split between two bent ones. This was the wrong way round, which put
        // the body at its peak on the very frame the feet swapped.
        //
        // Raised to a power so it hangs near the low point and rises in a quick
        // arc instead of spending equal time everywhere.
        let rise = pow(abs(cos(stride)), 1.6)
        return -CGFloat(rise) * size * 0.030 * walkScaleBase
    }

    // MARK: - Flying

    /// The buzz of speed, at whatever strength a given part deserves.
    ///
    /// Two frequencies stacked, and neither divides the other: a fast rattle
    /// for the engine and a slow drift under it. A single sine at one rate is a
    /// vibrating icon; two that never line up is something being pushed through
    /// air.
    ///
    /// `weight` is what keeps this from reading as the *screen* shaking. The
    /// head is held nearly still and the extremities are let go — if every part
    /// buzzed by the same amount there would be no relative motion at all, and
    /// no relative motion is exactly what a camera wobble looks like.
    private func flightJitter(weight: CGFloat) -> (x: CGFloat, y: CGFloat) {
        guard animation == .flying, clock > 0 else { return (0, 0) }

        let t = clock
        let rattle = sin(t * 41) * 0.7 + sin(t * 27) * 0.3
        let drift = sin(t * 2.3)

        return (
            x: (CGFloat(rattle) * 0.9 + CGFloat(drift) * 2.2) * weight * size * 0.004,
            y: CGFloat(sin(t * 34)) * weight * size * 0.003
        )
    }

    /// Leaning into it. Not upright — a body going somewhere is angled at where
    /// it is going, and vertical reads as hovering.
    /// Tipped over toward where he is going — left.
    ///
    /// A circle has no long axis to show you an angle, so the only evidence of
    /// a lean is where the face and the feet end up. It has to be big enough to
    /// read on a silhouette with no corners, which is why this is 28° and not
    /// the 14 I started with.
    /// Down from 28° now that the body lies flat.
    ///
    /// The lean was standing in for a pose I could not draw front-on. Side-on,
    /// the horizontal body says "going somewhere" by itself, and a steep angle
    /// on top of that just reads as falling. This is barely a tilt — enough to
    /// lift the head above the tail and no more.
    private var flightLean: Double { animation == .flying ? -8 : 0 }

    /// Stretched along the direction of travel, which is now sideways.
    ///
    /// This flipped with the flight. Going up, the stretch was vertical; going
    /// left, a tall creature would be stretched across its own path — the smear
    /// has to lie the way the movement does or it fights every other cue on
    /// screen.
    /// Pushed out to a capsule. The reference body is long and low, closer to a
    /// lozenge than a ball, and that silhouette is doing more of the work than
    /// any amount of streaking behind it.
    private var flightStretch: (width: CGFloat, height: CGFloat) {
        animation == .flying ? (1.38, 0.78) : (1, 1)
    }

    /// Both feet thrown out behind him, level with the body.
    ///
    /// They used to hang below and scissor apart, which was the pose of
    /// something that had just jumped. Trailing straight back is the pose of
    /// something that has been up here a while and stopped thinking about its
    /// legs — and because the feet sit behind the body in the stack, they read
    /// as streaming out from under it.
    ///
    /// The two are still offset from each other. Perfectly stacked feet lose
    /// one of them entirely; a small split keeps both legible without going
    /// back to a scissor.
    private func flightStride(side: CGFloat) -> (x: CGFloat, y: CGFloat, scale: CGFloat) {
        guard animation == .flying else { return (0, 0, 1) }

        // The upper foot is the near one, so it is drawn a touch bigger.
        let upper = side < 0
        return (
            x: size * (upper ? 0.30 : 0.37),
            y: size * (upper ? -0.05 : 0.03),
            scale: upper ? 1 : 0.9
        )
    }

    private var walkSway: Double {
        guard animation == .walkIn, walkProgress < 1 else { return 0 }
        // Leans over whichever foot is carrying it, so `cos` — the same phase
        // as the shove and the rise, not a third rhythm of its own.
        return cos(stride) * 2.2
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
    /// Welling up, but happy about it. Almost the same eye as `gloomy` — the
    /// same big pupil, the same water — with the lid thrown open instead of
    /// hooded, and the everyday grin left exactly where it was. That grin is
    /// the entire difference between the two, which is why nothing here
    /// touches the mouth.
    case joy = "Chorinho de alegria"
    /// Walking in from the back of the scene: small and high, growing and
    /// dropping until it is standing at full size, then stopping.
    case walkIn = "Chegando andando"
    /// Flying, chest to camera. Leaning, stretched tall and buzzing — the
    /// scenery is what actually moves, so this pose has to hold on its own.
    case flying = "Voando (herói)"
    /// The scrawl: two hand-drawn circles for eyes with nothing inside them,
    /// and a crooked square for a mouth. Nothing else on this creature is drawn
    /// this way, which is the point — it is the face for the moment the joke is
    /// that it has no idea what just happened.
    case wtf = "WTF?!"
    /// Brows down, mouth flat. Everything else — the breathing, the blink, the
    /// glance — carries on exactly as it does when it is idle, because a face
    /// that stops doing those looks switched off rather than stern.
    case serious = "Sério"
    /// The same trip, jumped instead of walked: it crouches at the back of the
    /// scene, throws itself forward through one somersault, and lands in front
    /// at full size.
    case leapIn = "Chegando de salto"

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

/// Where the creature is mid-leap.
///
/// `scale` is distance and `width`/`height` are squash, kept apart rather than
/// folded into one pair: they are on different clocks — distance climbs steadily
/// across the whole jump while the squash snaps at the two ends — and a single
/// value cannot be given two shapes.
private struct LeapPose {
    var scale: CGFloat = 1
    var lift: CGFloat = 0
    var flip: CGFloat = 0
    var width: CGFloat = 1
    var height: CGFloat = 1
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
    /// Drop the inner corner instead of the outer one — a scowl rather than a
    /// sulk. Also cuts deeper: a sad lid only has to tilt, but a hard stare has
    /// to actually narrow the eye, and an eye that is still wide open under an
    /// angled lid just looks surprised.
    var inward: Bool = false

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
        let inner = rect.height * droop * (inward ? 0.46 : 0.03)
        let outer = rect.height * droop * (inward ? 0.10 : 0.30)

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

/// A wide open grin: corners up, floor round.
///
/// The upper edge bows *upward* rather than running straight across. A flat top
/// makes the same shape read as a shout — it is the lift at the lip line that
/// keeps an open mouth smiling.
struct OpenSmile: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let left = CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.22)
        let right = CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22)

        path.move(to: left)
        path.addQuadCurve(to: right, control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.30))
        path.addQuadCurve(to: left, control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.55))
        path.closeSubpath()

        return path
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

/// Opening the lab straight from the launch arguments: `--lab=walkIn`.
///
/// The animation lives three taps from the app's first screen, which is fine by
/// hand and useless to anything driving the simulator — screenshots come back
/// but taps do not go in. Naming the state on the command line is the only way
/// to get a frame of a specific animation out of a real build.
enum LabLaunch {

    /// The part after `--lab=`, if the flag is there at all.
    private static var flag: String? {
        #if DEBUG
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--lab=") }
            .map { String($0.dropFirst("--lab=".count)) }
        #else
        nil
        #endif
    }

    static var requested: Bool { flag != nil }

    /// How far to stretch time, from `--slowmo=6`.
    ///
    /// A walk is two and a half seconds long and every judgement about it is
    /// about single poses — where the weight sits at mid-stance, whether the
    /// back foot is still down when the front one lands. At full speed there is
    /// nothing to look at. This stretches the creature's own clock rather than
    /// slowing the animation, so every pose is the pose it would really hit.
    static var timeScale: Double {
        #if DEBUG
        ProcessInfo.processInfo.arguments
            .first { $0.hasPrefix("--slowmo=") }
            .flatMap { Double($0.dropFirst("--slowmo=".count)) } ?? 1
        #else
        1
        #endif
    }

    /// Matched on the case name rather than the label: the labels are Portuguese
    /// display strings and would have to be quoted and accented on the way in.
    static var animation: CreatureAnimation? {
        guard let flag else { return nil }
        return CreatureAnimation.allCases.first { String(describing: $0) == flag }
    }
}

/// A scratch screen for looking at the character on its own, away from the game.
struct CharacterLab: View {

    @Environment(\.dismiss) private var dismiss
    @State private var playing: CreatureAnimation = LabLaunch.animation ?? .idle
    /// Bumped to send one wave of combo bubbles up the screen.
    @State private var bubbleToken = 0

    @State private var tab: LabTab = .character
    /// The full-screen moment currently playing, if any.
    @State private var staged: LabEvent?

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            // Two kinds of thing, kept apart on purpose.
            //
            // A creature pose and a full-screen moment are not the same object
            // and are not judged the same way: one you stare at while it loops,
            // the other you fire once and watch play out. Mixing them in a
            // single list meant the menu grew every time either side did, and
            // picking "Comemorando" next to "Fim de lição" implied the two were
            // interchangeable when one is a face and the other is a scene.
            VStack(spacing: 0) {
                Picker("", selection: $tab) {
                    ForEach(LabTab.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 28)
                .padding(.top, 56)

                Spacer(minLength: 0)

                switch tab {
                case .character: characterBench
                case .events: eventBench
                }

                Spacer(minLength: 0)
            }

            // Over everything, edge to edge. A wave that has to respect the safe
            // area is a wave with a strip of dead screen at each end, and the
            // whole read here is that it crosses the *whole* screen.
            ComboBubbles(token: bubbleToken)
                .ignoresSafeArea()
                // On a loop when the lab was opened from the command line, for
                // the same reason the leap is: taps do not go into a simulator
                // being driven from outside, so a wave that only ever fires from
                // a button is a wave that can never be screenshotted.
                .task {
                    guard LabLaunch.requested else { return }
                    while !Task.isCancelled {
                        bubbleToken += 1
                        try? await Task.sleep(for: .seconds(2.4))
                    }
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
            // Hidden while a scene is on, so the lab's own chrome never sits on
            // top of the thing being judged.
            .opacity(staged == nil ? 1 : 0)

            if let staged {
                stage(staged)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
    }

    // MARK: - Character

    /// The creature on its own, at the three sizes the app actually asks for.
    private var characterBench: some View {
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
    }

    // MARK: - Events

    /// One button per full-screen moment. A list rather than a picker: these
    /// are fired, not selected, and a menu that stays showing your last choice
    /// implies a state that does not exist.
    private var eventBench: some View {
        VStack(spacing: 14) {
            ForEach(LabEvent.allCases) { event in
                Button(event.label) { fire(event) }
                    .font(Theme.label(16, .bold))
                    .tint(Theme.greenEdge)
                    .buttonStyle(.bordered)
            }
        }
    }

    private func fire(_ event: LabEvent) {
        // The bubbles are not a scene — they wash over whatever is already on
        // screen and leave. Staging them would hide the very thing they are
        // supposed to be judged against.
        guard event != .comboBubbles else {
            bubbleToken += 1
            SoundEngine.shared.combo()
            Haptics.combo()
            return
        }

        withAnimation(.easeOut(duration: 0.2)) { staged = event }
    }

    /// A moment playing at full size, with its own real way out.
    @ViewBuilder
    private func stage(_ event: LabEvent) -> some View {
        switch event {
        case .comboBubbles:
            EmptyView()

        case .heroFlight:
            HeroFlight { close() }

        case .arrival:
            ArrivalScreen { close() }

        case .celebration:
            CelebrationScreen { close() }

        case .quit:
            ZStack {
                Theme.ink.opacity(0.78).ignoresSafeArea()

                QuitSheet(onStay: close, onQuit: close)
                    .transition(.move(edge: .bottom))
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private func close() {
        withAnimation(.easeOut(duration: 0.25)) { staged = nil }
    }
}

/// The two halves of the lab.
enum LabTab: String, CaseIterable, Identifiable {
    case character = "Personagem"
    case events = "Eventos"

    var id: Self { self }
    var label: String { rawValue }
}

/// A moment that takes the whole screen, rather than a pose the creature holds.
enum LabEvent: String, CaseIterable, Identifiable {
    case comboBubbles = "Bolhas do combo"
    case heroFlight = "Voo de herói"
    case arrival = "Chegada da revisão"
    case celebration = "Fim de lição"
    case quit = "Card de sair"

    var id: Self { self }
    var label: String { rawValue }
}

#Preview {
    CharacterLab()
}
