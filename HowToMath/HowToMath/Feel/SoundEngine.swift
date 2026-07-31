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

    /// Dry click under the finger the instant a tile is pressed.
    func tap() {
        play(key: "tap") {
            self.tone(partials: [(self.root + 24, 0.13)], duration: 0.05, decay: 70)
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
        // `.ambient` respects the silent switch and never stops the user's music.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func start() {
        engine.prepare()
        try? engine.start()
    }
}
