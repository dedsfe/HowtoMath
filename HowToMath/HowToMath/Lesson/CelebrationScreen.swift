//
//  CelebrationScreen.swift
//  HowToMath
//

import SwiftUI

/// The first screen after the last question: applause, and nothing else.
///
/// No XP, no time, no accuracy — the numbers come later. This one exists purely
/// to land the punch, and it is built as a sequence rather than a layout: rays,
/// then the creature, then the title, then the paper, then the button. Five
/// things arriving together is a screen appearing; five things arriving in
/// order is an event happening.
struct CelebrationScreen: View {

    /// Whether the lesson was finished without a single miss.
    var isPerfect = false
    /// The longest unbroken run of correct answers in the lesson.
    var bestStreak = 0
    var onContinue: () -> Void

    @State private var raysIn = false
    @State private var creatureIn = false
    @State private var titleIn = false
    @State private var buttonIn = false
    @State private var confettiToken = 0
    /// The heartbeat's squeeze, multiplied onto the title's own scale.
    @State private var pulse: CGFloat = 1
    /// Bumped on the frame the title lands.
    @State private var impactToken = 0
    /// Flipped once, on appear, to start the rays turning.
    @State private var spinning = false
    /// Bumped to run the whole sequence again from the top.
    @State private var replayToken = 0
    /// Set only by the debug bar, so a build without it can never disagree with
    /// the lesson it just came out of.
    @State private var forcedPerfect: Bool?
    @State private var forcedLeap: Bool?
    /// Which line of praise is showing. Picked once per screen, stepped through
    /// by hand from the debug bar.
    @State private var praiseIndex = Int.random(in: 0..<Praise.lines.count)
    /// True once the somersault has finished and the creature has been handed
    /// back to its standing animation.
    @State private var landed = false

    /// Which of the two celebrations is on screen.
    private var perfect: Bool { forcedPerfect ?? isPerfect }

    /// How long a run has to be before the creature earns its entrance.
    ///
    /// Seven, not ten. Tying it to a flawless lesson would have made this the
    /// same reward twice — the point of a second signal is that it can be won on
    /// a run that was recovered rather than clean.
    private var leaping: Bool { forcedLeap ?? (bestStreak >= 7) }

    /// When the creature's feet hit the floor, measured from the first frame of
    /// the leap. Read off the keyframes in `Creature`: everything up to and
    /// including the landing squash, without the spring that settles it.
    private let leapImpact = 1.15

    /// The somersault first if it was earned, then the standing face.
    private var creatureAnimation: CreatureAnimation {
        if leaping && !landed { return .leapIn }
        return perfect ? .joy : .celebrate
    }

    var body: some View {
        ZStack {
            // Outside the shake, so the jolt never drags a white edge in from
            // off-screen. The ground stays put; everything standing on it does
            // not.
            Theme.surface.ignoresSafeArea()
            vignette

            ZStack {
                rays
                // Behind the creature and in front of it. One plane of paper
                // falls flat no matter how much of it there is; two planes at
                // different sizes and speeds put the creature *inside* the
                // shower instead of behind a curtain of it.
                confetti(depth: 0.55)
                stack
                confetti(depth: 1.25)
            }
            .keyframeAnimator(initialValue: Jolt(), trigger: impactToken) { view, jolt in
                view.offset(x: jolt.x, y: jolt.y)
            } keyframes: { _ in
                // Down first, then a shrinking wobble. A shake that starts by
                // going up reads as a bump from below; this one has to read as
                // the word landing on the screen from the front.
                KeyframeTrack(\.y) {
                    CubicKeyframe(11, duration: 0.05)
                    CubicKeyframe(-6, duration: 0.06)
                    CubicKeyframe(3, duration: 0.07)
                    CubicKeyframe(0, duration: 0.11)
                }
                KeyframeTrack(\.x) {
                    CubicKeyframe(-6, duration: 0.05)
                    CubicKeyframe(4, duration: 0.06)
                    CubicKeyframe(-2, duration: 0.07)
                    CubicKeyframe(0, duration: 0.11)
                }
            }

            flash

            #if DEBUG
            debugBar
            #endif
        }
        .task(id: replayToken) { await play() }
        // Starts only once the word has landed, and dies with the screen — a
        // detached Task would go on tapping after this view is gone. Keyed on
        // the replay too, so a second run gets a fresh set of felt beats.
        .task(id: [titleIn ? 1 : 0, replayToken]) {
            guard titleIn else { return }
            await heartbeat()
        }
    }

    private var stack: some View {
        VStack(spacing: 0) {
                Spacer(minLength: 0)

                // The clean run gets the welling-up face; every other finish
                // gets the everyday bouncing one.
                //
                // Which way round this goes is the whole idea. Being moved to
                // tears is the biggest thing this creature does, and a face that
                // plays on every single lesson is a face nobody looks at by the
                // third one. Spending it only on a lesson without a single miss
                // turns it into something a player can go after.
                Creature(size: 200, animation: creatureAnimation)
                    // Lands from above, so the bounce it is already doing reads
                    // as the end of a fall rather than as a loop starting.
                    //
                    // None of that applies to the somersault: it brings itself
                    // in from the back of the scene, so the screen has to leave
                    // it alone and let it arrive.
                    .offset(y: leaping || creatureIn ? 0 : -60)
                    .scaleEffect(leaping || creatureIn ? 1 : 0.6)
                    .opacity(leaping || creatureIn ? 1 : 0)

                title
                    .padding(.top, 30)
                    .padding(.horizontal, 24)

                praise
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

                Spacer(minLength: 0)

                Button(action: onContinue) {
                    Text("CONTINUAR")
                        .font(Theme.label(17, .heavy))
                        .foregroundStyle(.white)
                }
                .buttonStyle(LipStyle(face: Theme.green, edge: Theme.greenEdge))
                .padding(.horizontal, 22)
                .padding(.bottom, 20)
                .offset(y: buttonIn ? 0 : 90)
                .opacity(buttonIn ? 1 : 0)
        }
    }

    /// The running order. Each gap is long enough for the previous beat to be
    /// read as its own thing and short enough that the whole thing still feels
    /// like one moment.
    private func play() async {
        withAnimation(.easeOut(duration: 0.45)) { raysIn = true }

        if leaping {
            // Nothing to bring on: the creature is already standing at the back
            // of the scene, and the wait is the length of its jump. The word
            // then lands on the same frame its feet do — one impact, not two.
            try? await Task.sleep(for: .seconds(leapImpact))
        } else {
            try? await Task.sleep(for: .seconds(0.12))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.58)) { creatureIn = true }
            Haptics.press()

            try? await Task.sleep(for: .seconds(0.22))
        }

        // Title and paper together: the confetti reads as being knocked loose
        // by the word slamming into place.
        withAnimation(.spring(response: 0.38, dampingFraction: 0.52)) { titleIn = true }
        confettiToken += 1
        impactToken += 1
        // The face is handed over on this exact frame, and the timing is the
        // whole of the fix.
        //
        // Nothing about this creature interpolates: every feature is read
        // straight off `animation`, and the eye and mouth explicitly clear any
        // inherited animation, so the swap from the leap's ordinary face to the
        // wide wet one is a hard cut no matter when it happens. A hard cut is
        // only ugly when you can see it — so it goes where the screen flashes,
        // jolts and throws a hundred pieces of paper in the air. Three tenths of
        // a second later, which is where this used to sit, all of that cover has
        // passed and the change is alone on a still screen.
        //
        // Landing on the squash helps too: the new face arrives on the frame the
        // body is flattest, so the eyes reading as blown wide is exactly what
        // hitting the floor should do to them.
        if leaping { landed = true }
        // The app already has a sound and a pattern for finishing something.
        // This screen was firing the button tap, which is the noise you get for
        // pressing anything at all — the wrong size of event entirely.
        SoundEngine.shared.finish()
        Haptics.finish()

        try? await Task.sleep(for: .seconds(0.30))
        withAnimation(Theme.settle) { buttonIn = true }
    }

    // MARK: - Title

    /// Set on its own lip, the same 3D trick the buttons use.
    ///
    /// A copy of the word in the darker green, offset straight down. Every
    /// raised thing in this app is lit from above and sits on an edge; the
    /// headline had no reason to be the exception.
    private var title: some View {
        // Flat, on purpose.
        //
        // The lip belongs to things you press. On a headline it was borrowing
        // the vocabulary of a button for something nobody can tap, and the
        // second copy underneath also had to be scaled and pulsed along with
        // the first — two stacked words breathing is where the edges start to
        // shimmer.
        Text(perfect ? "LIÇÃO PERFEITA!" : "LIÇÃO COMPLETA!")
            .foregroundStyle(perfect ? Theme.gold : Theme.green)
            .font(Theme.label(36, .black))
        .multilineTextAlignment(.center)
            .scaleEffect((titleIn ? 1 : 0.5) * pulse)
            .opacity(titleIn ? 1 : 0)
    }

    /// Lub-dub, and the taps that go with it.
    ///
    /// Driven by one loop rather than a `phaseAnimator` plus a separate timer,
    /// because the haptics have to land on the same frame as the squeeze. Two
    /// clocks running side by side start in step and drift apart, and a tap
    /// that arrives a frame off the beat feels like a stutter rather than a
    /// heartbeat.
    ///
    /// The shape is the point: a hard first beat, a smaller second one close
    /// behind, then a long rest. Evenly spaced pulses are a metronome — it is
    /// the gap that makes it read as a heart.
    private func heartbeat() async {
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.10)) { pulse = 1.065 }
            Haptics.beat(strong: true)
            try? await Task.sleep(for: .seconds(0.13))

            withAnimation(.easeIn(duration: 0.11)) { pulse = 1.012 }
            try? await Task.sleep(for: .seconds(0.11))

            withAnimation(.easeOut(duration: 0.09)) { pulse = 1.040 }
            Haptics.beat(strong: false)
            try? await Task.sleep(for: .seconds(0.10))

            withAnimation(.easeInOut(duration: 0.50)) { pulse = 1.0 }
            try? await Task.sleep(for: .seconds(0.66))
        }
    }

    /// One line of praise under the headline, different every time.
    ///
    /// Under the title rather than instead of it. The headline is the *label* —
    /// it is how you tell a clean lesson from an ordinary one at a glance, and
    /// rotating it would have thrown that away to buy variety. A second line
    /// costs nothing and carries the variety on its own: the thing that never
    /// changes stays legible, and the thing that changes is new every time.
    private var praise: some View {
        Text(Praise.lines[praiseIndex % Praise.lines.count])
            .font(Theme.label(16, .semibold))
            .foregroundStyle(Theme.dim)
            .multilineTextAlignment(.center)
            // A beat behind the headline rather than with it. Two lines of text
            // arriving together is a paragraph; one after the other is somebody
            // saying a thing and then adding to it.
            .opacity(titleIn ? 1 : 0)
            .offset(y: titleIn ? 0 : 8)
            .animation(.easeOut(duration: 0.28).delay(0.14), value: titleIn)
    }

    // MARK: - Background

    /// Brand green closing in around the edges, with the middle left white.
    ///
    /// The screen was one flat sheet of white, so the only saturated thing on it
    /// was a flash lasting four tenths of a second — the colour of winning
    /// arrived and left before the eye could settle on it. Darkening the rim
    /// does two jobs at once: it holds brand colour on screen for the whole
    /// beat, and it aims the eye at the middle, which is where the creature and
    /// the word are.
    ///
    /// It starts well out from the centre on purpose. A vignette that begins at
    /// the middle is not a vignette, it is a wash — and a wash would put green
    /// behind a green creature.
    ///
    /// Gold on a clean run, and the whole screen changes temperature with it.
    /// One swapped colour on the rim is worth more than any extra badge: you can
    /// tell which of the two celebrations you got from across the room, before a
    /// single word has been read.
    private var vignette: some View {
        GeometryReader { proxy in
            let reach = max(proxy.size.width, proxy.size.height)
            let edge = perfect ? Theme.gold : Theme.green

            RadialGradient(
                colors: [edge.opacity(0), edge.opacity(perfect ? 0.42 : 0.34)],
                center: .center,
                startRadius: reach * 0.16,
                endRadius: reach * 0.64
            )
        }
        .ignoresSafeArea()
        // In on the same beat as the rays: they are one background, and two
        // fades a tenth apart would read as the screen assembling itself.
        .opacity(raysIn ? 1 : 0)
        .allowsHitTesting(false)
    }

    /// A pale starburst, turning slowly behind everything.
    ///
    /// Rotation is the whole job. Static rays are wallpaper; rays that creep
    /// round keep a screen with one still creature on it from looking frozen
    /// while the player reads the word.
    ///
    /// Turned by a repeating animation rather than by a per-frame timeline.
    /// A `TimelineView` rebuilds its contents sixty times a second, which was
    /// fine while this was one flat colour and stopped being fine the moment it
    /// became a gradient: every frame was re-rasterising a full-screen radial
    /// fill behind a creature and a hundred pieces of confetti. Handing the spin
    /// to the animation system instead means the gradient is drawn once and the
    /// render server turns the finished picture — the same look, none of the
    /// per-frame work.
    private var rays: some View {
        GeometryReader { proxy in
            let reach = max(proxy.size.width, proxy.size.height)

            SunBurst()
                // Faint in the middle, solid at the tips.
                //
                // Flat `pale` on white was very nearly nothing, and simply
                // turning the whole shape up would have put wedges behind the
                // creature's face. Fading them in from the centre means they
                // gain their strength exactly where the vignette has taken the
                // page down — so the rays read hardest at the rim, against
                // green, and never compete with what is in front of them.
                .fill(
                    RadialGradient(
                        colors: [Theme.pale.opacity(0.2), Theme.pale],
                        center: .center,
                        startRadius: reach * 0.10,
                        endRadius: reach * 0.58
                    )
                )
                // Flattened to a texture before it is turned, so the spin is one
                // rotating bitmap on the GPU instead of a gradient being filled
                // again on every frame.
                .drawingGroup()
                // 72 seconds a lap is the 5°/s the timeline was doing. The wrap
                // from 360 back to 0 is invisible on a shape with sixteen
                // identical spokes.
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(.linear(duration: 72).repeatForever(autoreverses: false), value: spinning)
        }
        .scaleEffect(raysIn ? 1 : 0.3)
        .opacity(raysIn ? 1 : 0)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { spinning = true }
    }

    /// A wash of brand green over the whole screen on the beat of impact.
    ///
    /// Green rather than white: the page is already white, so a white flash is
    /// invisible on the one surface it has to read against. In and out inside
    /// four tenths of a second — long enough to feel, too short to look at.
    ///
    /// Brighter after a somersault, for two reasons that happen to agree: a
    /// creature that arrives at speed hits the floor harder than one that fades
    /// in, and this is the frame its face is being swapped on. The flash is the
    /// curtain that swap goes behind.
    private var flash: some View {
        (perfect ? Theme.gold : Theme.green)
            .ignoresSafeArea()
            .keyframeAnimator(initialValue: 0.0, trigger: impactToken) { view, alpha in
                view.opacity(alpha)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(leaping ? 0.62 : 0.40, duration: 0.05)
                    // Held for a frame or two at the top before it starts
                    // clearing. Peaking and immediately falling gives the eye a
                    // single bright frame to see past; a short plateau is what
                    // actually hides something.
                    LinearKeyframe(leaping ? 0.62 : 0.40, duration: leaping ? 0.05 : 0)
                    CubicKeyframe(0, duration: 0.33)
                }
            }
            .allowsHitTesting(false)
    }

    /// `depth` under 1 is the far layer: smaller, slower, paler.
    private func confetti(depth: Double) -> some View {
        ConfettiFall(token: confettiToken, perfect: perfect, depth: depth)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Debug

    #if DEBUG
    /// Switches between the two celebrations and replays the whole sequence.
    ///
    /// On the screen it is judging rather than on the lesson behind it: the
    /// thing being compared is a two-second run of animation, and any control
    /// that makes you leave and come back has already lost the comparison.
    private var debugBar: some View {
        VStack {
            HStack(spacing: 6) {
                debugChip("NORMAL", on: !perfect) { replay(perfect: false, leap: leaping) }
                debugChip("PERFEITA", on: perfect) { replay(perfect: true, leap: leaping) }
                debugChip("SALTO", on: leaping) { replay(perfect: perfect, leap: !leaping) }
                // One button for the whole bank rather than one per line: there
                // are eight of them and there will be more, and every chip up
                // here is space the next thing being compared cannot have.
                debugChip("FRASE \(praiseIndex % Praise.lines.count + 1)", on: false) {
                    praiseIndex += 1
                }
            }
            .padding(.top, 8)

            Spacer()
        }
    }

    private func debugChip(_ label: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.label(10, .heavy))
                .foregroundStyle(on ? .white : Theme.dim)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(on ? Theme.ink.opacity(0.72) : Theme.surface.opacity(0.9))
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
                )
        }
        .buttonStyle(.plain)
    }

    /// Puts every beat back to its starting position and runs the order again.
    ///
    /// The reset is deliberately not animated: this is the cut back to the top
    /// of the take, and letting SwiftUI tween it would play the entrance
    /// backwards before playing it forwards.
    private func replay(perfect: Bool, leap: Bool) {
        var instant = Transaction()
        instant.disablesAnimations = true

        withTransaction(instant) {
            forcedPerfect = perfect
            forcedLeap = leap
            landed = false
            raysIn = false
            creatureIn = false
            titleIn = false
            buttonIn = false
        }

        replayToken += 1
    }
    #endif
}

/// What the screen says under the headline.
///
/// Short, and about the player rather than about the app. Nothing here promises
/// anything, congratulates in the abstract, or uses an exclamation mark — the
/// headline is already shouting, and a second line shouting along with it reads
/// as a machine that says well done no matter what you did.
enum Praise {

    static let lines = [
        "Você mandou bem.",
        "Tá ficando fácil, né?",
        "Cada dia mais rápido.",
        "Isso é prática virando jeito.",
        "Mais uma no bolso.",
        "Olha só esse progresso.",
        "Você não travou uma vez.",
        "Amanhã fica mais fácil ainda."
    ]
}

/// How far the screen is thrown off centre by the impact.
private struct Jolt {
    var x: CGFloat = 0
    var y: CGFloat = 0
}

/// Wedges radiating from the centre, alternating with the gaps between them.
struct SunBurst: Shape {

    var spokes = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let centre = CGPoint(x: rect.midX, y: rect.midY)
        // Long enough that the tips are always off-screen, whatever the corner
        // distance is — a ray that ends inside the frame looks like a slice.
        let reach = max(rect.width, rect.height) * 1.5
        let step = .pi * 2 / Double(spokes)

        for spoke in 0..<spokes {
            let from = Double(spoke) * step
            let to = from + step * 0.5

            path.move(to: centre)
            path.addLine(to: CGPoint(x: centre.x + cos(from) * reach, y: centre.y + sin(from) * reach))
            path.addLine(to: CGPoint(x: centre.x + cos(to) * reach, y: centre.y + sin(to) * reach))
            path.closeSubpath()
        }

        return path
    }
}

/// Paper falling from above the screen.
///
/// Drawn in a `Canvas` on a per-frame timeline rather than as a pile of views:
/// a hundred animated rectangles would each need their own identity and their
/// own animation, and SwiftUI would be diffing all of them every frame. Here it
/// is one view doing arithmetic.
struct ConfettiFall: View {

    let token: Int
    /// Gold paper, and more of it.
    var perfect = false
    /// Which plane this layer is on. Under 1 is further back: the paper is
    /// smaller, falls slower and sits paler, which is the whole of what makes
    /// one layer read as being behind the other.
    var depth: Double = 1

    private let duration = 3.2

    @State private var pieces: [Confetto] = []
    @State private var start = Date.distantPast
    @State private var isRunning = false

    var body: some View {
        TimelineView(.animation(paused: !isRunning)) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                guard elapsed >= 0, elapsed <= duration else { return }

                for piece in pieces {
                    draw(piece, at: elapsed, in: size, context: context)
                }
            }
        }
        .onChange(of: token) { _, new in
            guard new > 0 else { return }
            pieces = Confetto.batch(perfect ? 130 : 90, perfect: perfect)
            start = .now
            isRunning = true
        }
        .task(id: token) {
            guard token > 0 else { return }
            try? await Task.sleep(for: .seconds(duration))
            isRunning = false
        }
    }

    private func draw(_ piece: Confetto, at elapsed: Double, in size: CGSize, context: GraphicsContext) {
        let age = elapsed - piece.delay
        guard age > 0 else { return }

        let x = piece.x * size.width + sin(age * piece.sway + piece.phase) * 26 * depth
        // Starts above the top edge so pieces enter the frame already moving.
        let y = -40 + age * piece.fall * depth

        guard y < size.height + 40 else { return }

        var layer = context
        layer.translateBy(x: x, y: y)
        layer.rotate(by: .radians(piece.phase + age * piece.spin))
        layer.scaleBy(x: depth, y: depth)
        // Squashing the width on a sine is what sells paper: a real scrap of
        // confetti spends most of its fall edge-on to you, nearly invisible,
        // and flashes wide as it turns over.
        layer.scaleBy(x: cos(age * piece.flip + piece.phase), y: 1)

        // The far layer sits back behind a little haze, so it never competes
        // with the paper crossing in front of the creature.
        let fade = min(1, (duration - elapsed) / 0.6) * min(1, depth)
        layer.fill(
            Path(CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)),
            with: .color(piece.color.opacity(fade))
        )
    }
}

/// One scrap of paper. All of its randomness is decided once, at birth, so the
/// fall is a pure function of time from then on.
struct Confetto {

    /// Horizontal start, 0 to 1 across the screen.
    let x: Double
    let delay: Double
    /// Points per second downward.
    let fall: Double
    /// Radians per second about its own centre.
    let spin: Double
    /// How fast it turns edge-on and back.
    let flip: Double
    /// How fast it drifts side to side.
    let sway: Double
    /// Start angle, so no two pieces are ever in step.
    let phase: Double
    let width: Double
    let height: Double
    let color: Color

    static func batch(_ count: Int, perfect: Bool = false) -> [Confetto] {
        // Brand greens plus the tear blues. The red is deliberately absent:
        // it means "wrong" everywhere else in the app, and it would read as a
        // mistake even in a shower of paper.
        //
        // The clean run drops gold through the same greens rather than a shower
        // of pure gold. All one colour reads as a filter over the old shower;
        // gold arriving among the usual paper reads as something extra having
        // been added to it, which is what actually happened.
        let palette = perfect
            ? [Theme.gold, Theme.goldEdge, Theme.gold, Theme.pale, Theme.green, Theme.tearLight]
            : [Theme.green, Theme.greenEdge, Theme.pale, Theme.tear, Theme.tearLight]

        return (0..<count).map { _ in
            Confetto(
                x: .random(in: -0.05...1.05),
                delay: .random(in: 0...0.9),
                fall: .random(in: 260...480),
                spin: .random(in: -5.5...5.5),
                flip: .random(in: 3.0...7.0),
                sway: .random(in: 1.4...3.2),
                phase: .random(in: 0...(.pi * 2)),
                width: .random(in: 7...13),
                height: .random(in: 10...18),
                color: palette.randomElement() ?? Theme.green
            )
        }
    }
}

#Preview {
    CelebrationScreen {}
}
