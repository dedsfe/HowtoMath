//
//  QuitSheet.swift
//  HowToMath
//

import SwiftUI

/// The card that rises when someone reaches for the X.
///
/// Leaving mid-lesson is the one destructive act on this screen, so it costs a
/// second tap. The weight is deliberately lopsided: staying is the chunky green
/// button under the thumb, leaving is a bare word below it. The creature sells
/// the ask — a rule about lost progress is an accusation, a sad face is a
/// request.
///
/// There is no cheap way out of it. No grabber, no drag, and a scrim that does
/// nothing when tapped — the only two exits are the two buttons. Dismissing by
/// gesture is right for a sheet someone opened by accident; this one is a
/// question with two named answers, and a stray tap is neither.
struct QuitSheet: View {

    var onStay: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(spacing: 26) {
            Creature(size: 92, animation: .gloomy)

            Text("Espera, você tá quase acabando a lição!")
                .font(Theme.label(23, .heavy))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            VStack(spacing: 6) {
                Button(action: onStay) {
                    Text("CONTINUAR LIÇÃO")
                        .font(Theme.label(16, .heavy))
                        .foregroundStyle(.white)
                }
                .buttonStyle(LipStyle(face: Theme.green, edge: Theme.greenEdge))

                Button(action: onQuit) {
                    Text("SAIR")
                        .font(Theme.label(16, .heavy))
                        .foregroundStyle(Theme.missDeep)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        // 38, not 12, to match the bottom.
        //
        // The gap under SAIR is not the 12pt of padding: the word is centred in
        // a 52pt tap target, so 26pt of that target sits under it before the
        // padding even starts. Matching the declared numbers would have left
        // the card visibly top-heavy — what has to match is the space you can
        // actually see.
        .padding(.top, 38)
        .padding(.horizontal, 22)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            // Only the top corners round: the card is anchored to the bottom
            // edge, not floating in the middle of the screen.
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .fill(Theme.surface)
            // Reaches past the home indicator so no white gap opens under it.
            .padding(.bottom, -400)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Theme.line)
                    .frame(height: 1.5)
            }
        }
        // Swallows any touch that lands on the card without doing anything, so
        // a drag started here never reaches whatever is behind it.
        .contentShape(.rect)
        .gesture(DragGesture())
    }
}

#Preview {
    ZStack {
        Theme.pale.ignoresSafeArea()
        QuitSheet(onStay: {}, onQuit: {})
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
