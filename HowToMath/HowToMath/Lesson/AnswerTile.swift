//
//  AnswerTile.swift
//  HowToMath
//

import SwiftUI

enum TileState {
    /// Waiting for input.
    case idle
    /// The one you picked, and it was right.
    case hit
    /// The one you picked, and it was wrong.
    case miss
    /// Not picked, but shown as the right answer after a miss.
    case reveal
    /// Not picked, faded back while feedback plays.
    case muted
}

/// One answer option.
///
/// The whole point of this view is the press: the face drops onto its lip the
/// moment the finger lands, and sound and haptic fire on *touch-down*, not on
/// release, so the tile answers the finger before the system has decided
/// whether it was a tap.
struct AnswerTile: View {

    let value: Int
    let state: TileState
    let accent: Color
    /// Square in the grid, shorter when the tiles are stacked full-width under
    /// a word problem — the text above needs the room more than the tile does.
    var height: CGFloat = 84
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(value)")
                .font(Theme.numeral(34))
                .foregroundStyle(foreground)
        }
        .buttonStyle(LipStyle(face: face, edge: edge, height: height))
        .disabled(state != .idle)
        .opacity(state == .muted ? 0.32 : 1)
        // Bloom on a hit.
        .keyframeAnimator(initialValue: 1.0, trigger: state == .hit) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(state == .hit ? 1.09 : 1.0, duration: 0.14, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.36, spring: .bouncy)
            }
        }
        // Shake on a miss — amplitude decays so it reads as a stumble, not a rattle.
        .keyframeAnimator(initialValue: 0.0, trigger: state == .miss) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(state == .miss ? -11 : 0, duration: 0.055)
                CubicKeyframe(state == .miss ? 9 : 0, duration: 0.055)
                CubicKeyframe(state == .miss ? -6 : 0, duration: 0.055)
                CubicKeyframe(state == .miss ? 3 : 0, duration: 0.055)
                CubicKeyframe(0, duration: 0.055)
            }
        }
        .animation(Theme.snap, value: state)
    }

    // MARK: - Skin

    private var foreground: Color {
        switch state {
        case .idle, .muted, .hit, .reveal: Theme.text
        case .miss: Theme.miss
        }
    }

    /// The top surface the finger lands on. Every face is opaque on purpose —
    /// the lip sits directly behind it, so a translucent face would let the
    /// darker edge bleed through and swallow the whole tile.
    private var face: Color {
        switch state {
        case .idle, .muted: Theme.surface
        case .hit, .reveal: Theme.pale
        case .miss: Theme.missSoft
        }
    }

    /// The darker sliver under the face — the whole 3D read comes from this.
    private var edge: Color {
        switch state {
        case .idle, .muted: Theme.line
        case .hit, .reveal: accent
        case .miss: Theme.miss
        }
    }
}

/// A button with a 3D lip: the face sits `Theme.lip` above a darker edge and
/// drops onto it when pressed. The footprint never changes size — the sink is
/// the entire effect, which is why there is no `scaleEffect` here.
struct LipStyle: ButtonStyle {

    let face: Color
    let edge: Color
    var height: CGFloat = 56
    /// Full-width by default; a word-bank chip hugs its own number instead.
    var stretches: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)

        return ZStack(alignment: .top) {
            shape
                .fill(edge)
                .frame(height: height + Theme.lip)

            configuration.label
                .frame(maxWidth: stretches ? .infinity : nil)
                .frame(height: height)
                .background(shape.fill(face))
                .overlay(shape.strokeBorder(edge, lineWidth: 2))
                .offset(y: configuration.isPressed ? Theme.lip : 0)
        }
        .frame(height: height + Theme.lip)
        .animation(Theme.press, value: configuration.isPressed)
        // Haptics only, no click.
        //
        // There was a tone here on every press and it was noise in the literal
        // sense: pressing a tile is not an outcome, and the outcome — right or
        // wrong — announces itself a fraction of a second later anyway. Two
        // sounds for one action left the answer chime arriving on top of the
        // click that preceded it. The tap still has to be felt, so the haptic
        // stays; that one confirms the touch without claiming anything.
        .onChange(of: configuration.isPressed) { _, pressed in
            guard pressed else { return }
            Haptics.press()
        }
    }
}
