//
//  MatchBoard.swift
//  HowToMath
//

import SwiftUI

/// The pairing board: sums down one side, results down the other, cleared by
/// tapping one of each.
///
/// Nothing is dragged. A tap picks a card up and the next tap tries it against
/// what is held, which is the same one-finger grammar as every other question
/// type here — and it survives a board taller than the thumb can reach.
struct MatchBoard: View {

    let sums: [MatchCard]
    let results: [MatchCard]
    let picked: MatchCard?
    let missToken: Int
    let accent: Color
    let isMatched: (MatchCard) -> Bool
    let onPick: (MatchCard) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            column(sums)
            column(results)
        }
        .padding(.horizontal, 20)
    }

    private func column(_ cards: [MatchCard]) -> some View {
        VStack(spacing: 20) {
            ForEach(cards) { card in
                card_(card)
            }
        }
    }

    private func card_(_ card: MatchCard) -> some View {
        let matched = isMatched(card)
        let held = picked?.id == card.id

        return Button {
            onPick(card)
        } label: {
            Text(card.label)
                .font(Theme.numeral(26))
                .foregroundStyle(matched ? accent : Theme.text)
                .opacity(matched ? 0.45 : 1)
        }
        .buttonStyle(LipStyle(
            face: matched ? Theme.pale : (held ? Theme.pale : Theme.surface),
            edge: matched ? accent.opacity(0.4) : (held ? accent : Theme.line),
            height: 64
        ))
        .disabled(matched)
        // Only the held card lifts, so at a glance there is exactly one card in
        // hand and the board says what it is waiting for.
        .scaleEffect(held ? 1.05 : 1)
        .animation(Theme.snap, value: held)
        .animation(Theme.settle, value: matched)
        // The shake is fired for the held card only: the pair that failed is the
        // one the eye is already on.
        .keyframeAnimator(initialValue: 0.0, trigger: held ? missToken : 0) { view, offset in
            view.offset(x: offset)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(-9, duration: 0.05)
                CubicKeyframe(7, duration: 0.05)
                CubicKeyframe(-4, duration: 0.05)
                CubicKeyframe(0, duration: 0.05)
            }
        }
    }
}
