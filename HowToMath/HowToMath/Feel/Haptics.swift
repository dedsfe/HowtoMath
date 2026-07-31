//
//  Haptics.swift
//  HowToMath
//

import UIKit

/// Haptic vocabulary for the lesson loop.
///
/// Each sound in `SoundEngine` has a matching tap here — the two always fire
/// together, which is what makes a hit read as physical rather than decorative.
enum Haptics {

    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let notice = UINotificationFeedbackGenerator()

    /// Call before a burst of feedback so the Taptic Engine is already spun up.
    static func prepare() {
        rigid.prepare()
        soft.prepare()
        notice.prepare()
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

    static func finish() {
        notice.notificationOccurred(.success)
        notice.prepare()
    }
}
