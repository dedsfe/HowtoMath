//
//  SoundEngine.swift
//  HowToMath
//
//  Synthesized feedback tones. No audio assets — every sound is rendered
//  at runtime so the pitch can track the streak.
//

import AVFoundation

/// Plays short synthesized tones for lesson feedback.
///
/// The core trick: consecutive correct answers walk *up* a pentatonic scale,
/// so a run of right answers reads as a rising melodic phrase instead of the
/// same chime over and over. Getting one wrong drops you back to the root.
final class SoundEngine {

    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private let format: AVAudioFormat
    /// Round-robin pool so a tap click can overlap the answer tone.
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var cache: [String: AVAudioPCMBuffer] = [:]

    /// Major pentatonic, two octaves. Streak index walks this ladder.
    private let ladder: [Double] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
    private let root: Double = 62 // D4

    /// Which combo run plays next.
    private var comboRun = 0

    /// Where the bubbles sit, in MIDI.
    ///
    /// Where the run sits, measured off a recording rather than reasoned about.
    ///
    /// Analysing a real bubble track put 86% of its energy between 200Hz and
    /// 800Hz, with a spectral centre near 450Hz — and almost literally nothing
    /// above 1.6kHz. This had been walked down to a G2 chasing "less cartoon",
    /// which overshot in the other direction: the run ended up under the band
    /// the reference lives in. What made the old version sound like a toy was
    /// never the height, it was the shape of the sweeps and the hiss on top.
    ///
    /// This exact note was found by sweeping the root and measuring: at B3 the
    /// run's spectral centre lands at 443Hz against the reference's 454.
    private let comboRoot: Double = 59 // B3

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

        for _ in 0..<4 {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }

        configureSession()
        start()
    }

    // MARK: - Public

    /// Rising tone for a correct answer. `streak` is the run length *after* this answer.
    func correct(streak: Int) {
        let step = ladder[min(max(streak - 1, 0), ladder.count - 1)]
        // Root + a fifth above gives it body without sounding like a game show.
        play(key: "ok-\(Int(step))") {
            self.tone(
                partials: [(self.root + step, 0.55), (self.root + step + 7, 0.18), (self.root + step + 12, 0.10)],
                duration: 0.42,
                decay: 9
            )
        }
    }

    /// Soft descending pair for a wrong answer — deliberately gentle, not a buzzer.
    func wrong() {
        play(key: "wrong") {
            let a = self.tone(partials: [(self.root - 5, 0.40), (self.root - 5 + 3, 0.14)], duration: 0.20, decay: 14)
            let b = self.tone(partials: [(self.root - 9, 0.40), (self.root - 9 + 3, 0.14)], duration: 0.34, decay: 10)
            return self.concat(a, b)
        }
    }

    /// The combo: a stream of bubbles going up the screen.
    ///
    /// The one sound here that is a *gesture* rather than a note — it lasts a
    /// second and it goes somewhere, because it is standing in for something the
    /// eye is watching travel. A single chime, however triumphant, would be over
    /// before the first bubble cleared the answer tiles.
    ///
    /// Three pre-baked runs, rotating. Every other sound in the app is allowed to
    /// repeat exactly because each one is a beat; this one is long enough that
    /// hearing the identical clip on every fifth answer would start to sound like
    /// a jingle being triggered.
    func combo() {
        let run = comboRun % comboRuns.count
        comboRun += 1

        play(key: "combo-\(run)") {
            self.stream(comboRuns[run])
        }
    }

    /// Resolving chord for the end of a lesson.
    func finish() {
        play(key: "finish") {
            let one = self.tone(partials: [(self.root + 12, 0.40), (self.root + 16, 0.26)], duration: 0.16, decay: 16)
            let two = self.tone(partials: [(self.root + 19, 0.40), (self.root + 24, 0.30), (self.root + 28, 0.18)], duration: 0.90, decay: 4)
            return self.concat(one, two)
        }
    }

    // MARK: - Playback

    private func play(key: String, build: () -> AVAudioPCMBuffer) {
        guard engine.isRunning else { return }

        let buffer: AVAudioPCMBuffer
        if let cached = cache[key] {
            buffer = cached
        } else {
            buffer = build()
            cache[key] = buffer
        }

        let node = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        node.stop()
        node.scheduleBuffer(buffer, at: nil, options: [])
        node.play()
    }

    // MARK: - Bubbles

    /// One bubble leaving the water: when it goes, and how high it sits.
    private struct Blup {
        /// Seconds from the start of the run.
        let at: Double
        /// Steps above `comboRoot`, in semitones.
        let step: Double
        /// The one that ends the run: rings longer and brighter than the rest.
        ///
        /// A reward sound has to *land*. Without this the run simply stops on
        /// whichever bubble happened to be last, which is the difference between
        /// a phrase and a recording that ran out.
        var cap: Bool = false

        /// How loud, against a full-sized bubble. The swarm is built from the
        /// same shape turned right down.
        var gain: Double = 1

        /// What the pitch multiplies by across the pop. Under 1 falls.
        ///
        /// Per bubble, and wildly varied, because that is what a recording of
        /// real bubbles turned out to contain: measured event by event, the
        /// sweeps ran from 0.30x to 2.10x with no pattern to which way they
        /// went. Every version before this one swept every bubble gently
        /// upward, on the theory that a consistent rise is what sounds like a
        /// cartoon. Half right — the rise is the cartoon; the *size* of it is
        /// not. Real water bends hard and picks a direction at random.
        var sweep: Double = 1
    }

    /// A deterministic noise source.
    ///
    /// Seeded rather than `random`, because these buffers are built once and
    /// cached forever — a roll of the dice inside the builder is not variation,
    /// it is one arbitrary result frozen for the life of the app.
    private struct Noise {
        private var state: UInt64

        init(seed: UInt64) { state = seed | 1 }

        mutating func next() -> Double {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Double(state % 20_001) / 10_000 - 1
        }
    }

    /// The three runs, hand-placed.
    ///
    /// None of them climbs, and that is the correction that mattered most. They
    /// used to wander upward across two octaves, on the reasoning that a rising
    /// sound belongs under rising bubbles. It is the wrong instinct twice over:
    /// a pitch that tracks something going up the screen is the oldest gag in
    /// animation, and real bubbles do not do it — a stream of them is a crowd of
    /// unrelated sizes, and size is pitch, so the crowd has no direction at all.
    /// These wander inside a sixth and end lower than they start.
    ///
    /// A major third was tried and put back. Squeezing to three notes did turn
    /// the run into a texture, which was the idea — and took the life out with
    /// the tune, because at that width the only thing left telling one bubble
    /// from the next is when it happens.
    ///
    /// The gaps stay uneven for the same reason they always were: evenly spaced
    /// blups are a clock.
    ///
    /// Steps are counted from `comboRoot`, not from the root the answer tones
    /// use — the run is written here as a shape and dropped into its register in
    /// one place.
    private var comboRuns: [[Blup]] {
        [
            [
                Blup(at: 0.00, step: 12, sweep: 1.85),
                Blup(at: 0.05, step: 16, sweep: 0.42),
                Blup(at: 0.19, step: 9, sweep: 0.55),
                Blup(at: 0.27, step: 14, sweep: 2.05),
                Blup(at: 0.40, step: 7, sweep: 0.35),
                Blup(at: 0.48, step: 16, sweep: 1.60),
                Blup(at: 0.65, step: 12, sweep: 0.48),
                Blup(at: 0.79, step: 9, sweep: 1.90),
                Blup(at: 0.95, step: 4, cap: true, sweep: 0.62)
            ],
            [
                Blup(at: 0.00, step: 14, sweep: 0.45),
                Blup(at: 0.10, step: 9, sweep: 1.95),
                Blup(at: 0.16, step: 16, sweep: 0.38),
                Blup(at: 0.30, step: 12, sweep: 1.55),
                Blup(at: 0.38, step: 7, sweep: 0.60),
                Blup(at: 0.52, step: 16, sweep: 2.10),
                Blup(at: 0.63, step: 9, sweep: 0.44),
                Blup(at: 0.74, step: 14, sweep: 1.70),
                Blup(at: 0.88, step: 4, cap: true, sweep: 0.55)
            ],
            [
                Blup(at: 0.00, step: 16, sweep: 0.50),
                Blup(at: 0.07, step: 12, sweep: 1.75),
                Blup(at: 0.21, step: 7, sweep: 0.40),
                Blup(at: 0.29, step: 14, sweep: 2.00),
                Blup(at: 0.36, step: 9, sweep: 0.58),
                Blup(at: 0.49, step: 16, sweep: 1.45),
                Blup(at: 0.61, step: 12, sweep: 0.36),
                Blup(at: 0.77, step: 9, sweep: 1.85),
                Blup(at: 0.90, step: 4, cap: true, sweep: 0.68)
            ]
        ]
    }

    /// Renders a whole run into one buffer, blups overlapping where they overlap.
    private func stream(_ run: [Blup]) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let tail = 0.30
        let length = (run.map(\.at).max() ?? 0) + tail

        let frames = AVAudioFrameCount(rate * length)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]

        // Silence first: a fresh buffer is not guaranteed to be zeroed, and this
        // one is written into by addition rather than assignment.
        for i in 0..<Int(frames) { samples[i] = 0 }

        // The water the bubbles are coming out of, under everything else.
        //
        // Made of more bubbles, and this is the whole correction. It was a bed
        // of high-passed noise before, which is a perfectly good way to build a
        // hiss and a perfectly wrong way to build a liquid: continuous broadband
        // noise is the sound of carbonation escaping, and that is exactly what
        // it sounded like. A liquid is not noise with a filter on it, it is a
        // pile of individual bubbles ringing at once — so the bed is now sixty
        // of the same bubble, tiny and quiet, and the texture falls out of the
        // pile instead of being imitated by a filter.
        swarm(into: samples, frames: Int(frames), rate: rate, length: length)

        for bubble in run {
            render(bubble, into: samples, frames: Int(frames), rate: rate)
        }
        return buffer
    }

    /// The froth: many small bubbles, none of them meant to be picked out.
    private func swarm(into samples: UnsafeMutablePointer<Float>, frames: Int, rate: Double, length: Double) {
        var dice = Noise(seed: 90_001)

        for _ in 0..<60 {
            // Unit interval out of the -1...1 the generator gives.
            let when = (dice.next() + 1) / 2
            let pitch = (dice.next() + 1) / 2
            let bend = (dice.next() + 1) / 2

            // Denser at the front, thinning toward the end, the same shape the
            // wave on screen has: most of the bubbles leave in the first half.
            let at = pow(when, 1.5) * (length - 0.20)

            // Above the run, because a speck of air is a small bubble whatever
            // the big ones are doing — but still inside the band the reference
            // occupies. Sixty tiny things up in the sizzle is a hiss again by
            // another route, and the hiss was the whole thing being fixed.
            //
            // Each one bends its own way, half of them downward: it is the same
            // coin toss the big bubbles get, and without it a swarm of sixty
            // identical chirps is a cricket.
            let bubble = Blup(
                at: at,
                step: 9 + pitch * 12,
                gain: 0.14,
                sweep: bend < 0.5 ? 0.35 + bend * 0.7 : 1.2 + bend * 1.1
            )

            render(bubble, into: samples, frames: frames, rate: rate)
        }
    }

    /// One blup, added on top of whatever is already in the buffer.
    ///
    /// A bubble is a pocket of air ringing as it shrinks, so the pitch *rises*
    /// across the pop — that sweep is the entire difference between a bubble and
    /// a bleep, and it is why a plain sine at a fixed frequency never sounds like
    /// water no matter what envelope is put on it.
    private func render(_ bubble: Blup, into samples: UnsafeMutablePointer<Float>, frames: Int, rate: Double) {
        let start = Int(bubble.at * rate)
        guard start < frames else { return }

        // Higher bubbles are smaller, so they are shorter and they die faster.
        // One number decides all of it, the same way the drawn bubbles take
        // their size, speed and opacity off a single depth.
        //
        // The spread is much wider than it was, and measured: events in the
        // reference ran from 38ms to 300ms. Everything here used to land between
        // 70 and 125, which is a single bubble played at different pitches.
        let small = min(1, max(0, bubble.step / 24))
        let duration = (0.32 - 0.28 * small) * (bubble.cap ? 1.6 : 1)
        let decay = (14 + 40 * small) * (bubble.cap ? 0.45 : 1)
        // Loud enough to be heard *through* the answer chime, which is playing
        // on the same frame and is the louder sound of the two. A combo that
        // only registers in the gap afterwards is a combo nobody hears.
        let amplitude = (0.62 - 0.20 * small) * (bubble.cap ? 1.15 : 1) * bubble.gain

        let count = min(Int(rate * duration), frames - start)
        // Under a millisecond. This is most of the crispness: the ear reads the
        // first two or three milliseconds of a sound as its edge, and a soft
        // ramp there rounds off the very thing that makes a pop a pop.
        let attack = 0.0008 * rate
        let base = 440 * pow(2, (comboRoot + bubble.step - 69) / 12)

        // No click on the front any more.
        //
        // There were three milliseconds of white noise here, added to give each
        // pop an edge — and white noise is broadband by definition, which is
        // exactly the problem: the reference recording puts one part in a
        // thousand of its energy above 1.6kHz. There is no bright edge in real
        // bubbles at all. The sub-millisecond attack below is where the
        // definition has to come from, and it comes from it honestly, because a
        // step that fast on a 400Hz tone has its own click built in.
        //
        // Phase is accumulated rather than computed from `t`.
        //
        // `sin(2π · f(t) · t)` is the obvious way to write a sweep and it is
        // wrong: it stretches the whole waveform behind the moving frequency
        // instead of advancing it, which sweeps far harder than asked and ends
        // on the wrong note. Only the integral of frequency is phase.
        var phase = 0.0

        for i in 0..<count {
            let t = Double(i) / rate
            let frequency = base * pow(bubble.sweep, t / duration)
            phase += 2 * .pi * frequency / rate

            let envelope = exp(-t * decay) * min(1, Double(i) / attack)

            // An octave on top, dying about three times faster than the body.
            //
            // A bubble really is close to a pure sine, and a pure sine is dull —
            // this is the point where the physics has to give way, because the
            // job is not to be a bubble, it is to be *heard* as one over a game.
            // Fading it out quickly keeps the trick to the attack: bright on the
            // way in, honest a moment later.
            //
            // Turned well down from where it started. Brightness on top of a
            // swept tone is the second half of the cartoon read; the crispness
            // it was buying is the tick's job, and the tick has no pitch to
            // sound comic with.
            let shimmer = sin(phase * 2) * 0.11 * exp(-t * decay * 3.2)

            samples[start + i] += Float((sin(phase) + shimmer) * amplitude * envelope)
        }
    }

    // MARK: - Synthesis

    /// Renders a sum of sine partials under an exponential decay envelope.
    /// - Parameters:
    ///   - partials: `(midiNote, amplitude)` pairs.
    ///   - decay: higher is snappier.
    private func tone(partials: [(Double, Double)], duration: Double, decay: Double) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(rate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let samples = buffer.floatChannelData![0]
        let attack = 0.004 * rate

        for i in 0..<Int(frames) {
            let t = Double(i) / rate
            var value = 0.0
            for (midi, amplitude) in partials {
                let frequency = 440 * pow(2, (midi - 69) / 12)
                value += sin(2 * .pi * frequency * t) * amplitude
            }
            let envelope = exp(-t * decay) * min(1, Double(i) / attack)
            samples[i] = Float(value * envelope)
        }
        return buffer
    }

    private func concat(_ first: AVAudioPCMBuffer, _ second: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let frames = first.frameLength + second.frameLength
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames

        let out = buffer.floatChannelData![0]
        out.update(from: first.floatChannelData![0], count: Int(first.frameLength))
        (out + Int(first.frameLength)).update(from: second.floatChannelData![0], count: Int(second.frameLength))
        return buffer
    }

    // MARK: - Session

    private func configureSession() {
        // `.playback`, so the sound survives the silent switch.
        //
        // It was `.ambient`, which obeys the switch by definition — and a phone
        // that lives on silent is most phones, so the whole sound design was
        // simply absent for most people. Feedback that only some of the room
        // hears is not feedback.
        //
        // `.mixWithOthers` is what keeps that from being rude: it is the half of
        // `.ambient` worth keeping, and without it this category stops whatever
        // the user was already listening to the moment the app opens.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func start() {
        engine.prepare()
        try? engine.start()
    }
}
