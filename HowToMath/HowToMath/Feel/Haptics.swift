//
//  Haptics.swift
//  HowToMath
//

import CoreHaptics
import UIKit

/// Haptic vocabulary for the lesson loop.
///
/// Each sound in `SoundEngine` has a matching tap here — the two always fire
/// together, which is what makes a hit read as physical rather than decorative.
///
/// The single beats are `UIFeedbackGenerator`, which is the right tool for one
/// tap and the wrong one for anything shaped: it has no notion of how sharp a
/// tap is, no continuous vibration, and no timeline. Anything with a shape to it
/// goes through Core Haptics below.
enum Haptics {

    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notice = UINotificationFeedbackGenerator()

    /// Call before a burst of feedback so the Taptic Engine is already spun up.
    static func prepare() {
        rigid.prepare()
        soft.prepare()
        notice.prepare()
        _ = engine
    }

    // MARK: - Core Haptics

    /// Built once, on the first device that admits to having a Taptic Engine.
    ///
    /// `playsHapticsOnly` matters more than it looks: without it the engine
    /// claims an audio session of its own, and this app already configured one
    /// deliberately — `.playback` with `.mixWithOthers`, so the sounds survive
    /// the silent switch without stopping anyone's music. A second session would
    /// quietly take that decision back.
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }

        let engine = try? CHHapticEngine()
        engine?.playsHapticsOnly = true
        engine?.isAutoShutdownEnabled = true

        // The engine is stopped by the system whenever it feels like it — a call
        // arriving, the app going to the background, a reset. Both handlers are
        // required, not optional politeness: without them the first interruption
        // is permanent and the app simply stops vibrating for the rest of its life.
        engine?.resetHandler = { try? engine?.start() }
        engine?.stoppedHandler = { _ in }

        try? engine?.start()
        return engine
    }()

    /// Intensity that lands where it is asked to.
    ///
    /// The engine's response to `intensity` is not linear — 0.5 is nowhere near
    /// twice 0.25, it follows roughly a square. So the design here is written in
    /// what should be *felt* and square-rooted on the way in, which is why the
    /// numbers in the patterns below can be read as a straight ramp.
    private static func felt(_ level: Float) -> Float { sqrt(max(0, min(1, level))) }

    private static func play(_ events: [CHHapticEvent], curves: [CHHapticParameterCurve] = []) {
        guard let engine else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameterCurves: curves)
            try engine.start()
            try engine.makePlayer(with: pattern).start(atTime: CHHapticTimeImmediate)
        } catch {
            // A haptic that fails is not worth a single line of user-facing
            // anything. The sound and the animation carry the moment on their own.
        }
    }

    /// One beat of a heartbeat.
    ///
    /// The pair is not two of the same tap. A heart's first beat is the hard
    /// one and the second is softer and rounder — matching them makes it feel
    /// like a machine ticking twice rather than something alive.
    static func beat(strong: Bool) {
        if strong {
            rigid.impactOccurred(intensity: 0.95)
            rigid.prepare()
        } else {
            soft.impactOccurred(intensity: 0.55)
            soft.prepare()
        }
    }

    /// The instant a tile goes down.
    static func press() {
        rigid.impactOccurred(intensity: 0.7)
        rigid.prepare()
    }

    /// Correct answer. Intensity climbs with the streak so a long run escalates.
    static func correct(streak: Int) {
        notice.notificationOccurred(.success)
        let bonus = min(Double(streak) / 8, 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            soft.impactOccurred(intensity: 0.4 + 0.6 * bonus)
            soft.prepare()
        }
    }

    /// Wrong answer — two soft nudges, not the harsh `.error` buzz. Being wrong
    /// should feel like a stumble, not a punishment.
    static func wrong() {
        soft.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
            soft.impactOccurred(intensity: 0.5)
            soft.prepare()
        }
    }

    /// The combo: the bubbles, in the hand.
    ///
    /// Six taps, not the nine the sound has. The hand is a much blunter ear —
    /// taps closer together than about a tenth of a second stop being separate
    /// events and turn into a buzz, and a buzz is what a phone does when
    /// something is wrong. So this is not the rhythm transcribed; it is the
    /// moments in it worth feeling, on the same 1.25s the run takes.
    ///
    /// Sharpness is the parameter that was missing before, and it is the one
    /// that makes a tap feel like a *thing* rather than a pulse. On a transient
    /// it works as a low-pass: high is a fingernail on glass, low is a knuckle
    /// on a table. So the small bubbles are sharp and the big one that ends the
    /// run is the dullest thing in the pattern — a heavy, round thud. That
    /// inversion is the whole trick; a finale that is simply the sharpest tap
    /// reads as an alert.
    static func combo() {
        guard engine != nil else { return comboFallback() }

        // (when, how hard it should feel, how sharp)
        let beats: [(at: Double, force: Float, edge: Float)] = [
            (0.00, 0.42, 0.65),
            (0.19, 0.38, 0.72),
            (0.40, 0.52, 0.60),
            (0.55, 0.46, 0.75),
            (0.75, 0.58, 0.62),
            (0.95, 0.95, 0.28)
        ]

        var events = beats.map { beat in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: felt(beat.force)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: beat.edge)
                ],
                relativeTime: beat.at
            )
        }

        // The water under the bubbles, matching the froth in the sound.
        //
        // Kept faint on purpose, and not for taste: a transient landing on top
        // of a continuous event can partly cancel it — same engine, two signals,
        // no way to control the phase between them. At this level the ducking is
        // a texture rather than a hole punched in the taps.
        events.append(
            CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: felt(0.16)),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.25)
                ],
                relativeTime: 0,
                duration: 1.05
            )
        )

        // Swells in and drains out, so the bed arrives with the wave instead of
        // switching on under it.
        let bed = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0.00, value: 0.0),
                .init(relativeTime: 0.18, value: 1.0),
                .init(relativeTime: 0.70, value: 0.8),
                .init(relativeTime: 1.05, value: 0.0)
            ],
            relativeTime: 0
        )

        play(events, curves: [bed])
    }

    /// The old pattern, for hardware with no Taptic Engine to speak of.
    private static func comboFallback() {
        soft.prepare()
        rigid.prepare()

        for beat in [(0.00, 0.45), (0.19, 0.40), (0.40, 0.55), (0.65, 0.50)] {
            DispatchQueue.main.asyncAfter(deadline: .now() + beat.0) {
                soft.impactOccurred(intensity: beat.1)
                soft.prepare()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            rigid.impactOccurred(intensity: 1.0)
            rigid.prepare()
        }
    }

    static func finish() {
        notice.notificationOccurred(.success)
        notice.prepare()
    }
}
