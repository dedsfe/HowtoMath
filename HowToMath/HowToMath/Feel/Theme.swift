//
//  Theme.swift
//  HowToMath
//

import SwiftUI

/// Visual language for the lesson screen. See `design.md` at the repo root.
///
/// The identity is a light, high-contrast surface with one saturated green
/// carrying every positive signal, and buttons that physically sink under the
/// finger via a 3D lip rather than a scale trick.
enum Theme {

    // MARK: - Palette

    static let green = Color(hex: 0x85CB33)
    static let greenEdge = Color(hex: 0x689E28)
    static let ink = Color(hex: 0x100B00)
    static let pale = Color(hex: 0xEFFFC8)
    static let surface = Color.white

    /// Ink at reduced strength — these are not new colours.
    static let text = ink
    static let dim = ink.opacity(0.45)
    static let line = ink.opacity(0.16)
    static let track = ink.opacity(0.08)

    /// The one hue outside the brand palette. Wrong has to read as wrong, and a
    /// dark green cannot do that. Three shades of it, used nowhere else.
    static let miss = Color(hex: 0xFF4B4B)      // tile border and numeral
    static let missSoft = Color(hex: 0xFFDFE0)  // banner ground
    static let missDeep = Color(hex: 0xEA2B2B)  // banner text and CTA face
    static let missEdge = Color(hex: 0xC02222)  // CTA lip

    /// Kept as a function so callers stay unchanged, but the accent no longer
    /// drifts with the streak — brand colour beats temperature.
    static func accent(streak: Int) -> Color { green }

    // MARK: - Metrics

    /// How far a button's face sits above its lip, and how far it sinks.
    static let lip: CGFloat = 4
    static let radius: CGFloat = 16

    // MARK: - Type

    static func numeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded).monospacedDigit()
    }

    static func label(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Motion

    /// Overshoots just enough to read as physical without feeling bouncy.
    static let snap = Animation.spring(response: 0.30, dampingFraction: 0.62)
    static let settle = Animation.spring(response: 0.45, dampingFraction: 0.80)
    static let press = Animation.spring(response: 0.16, dampingFraction: 0.70)

    /// Critically damped — arrives and stops. For a piece travelling to a slot,
    /// where an overshoot reads as the number wobbling instead of seating.
    static let glide = Animation.spring(response: 0.26, dampingFraction: 1.0)
}

extension Color {
    /// `Color(hex: 0x85CB33)` — keeps the palette readable against `design.md`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
