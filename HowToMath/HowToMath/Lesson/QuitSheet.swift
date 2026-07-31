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
/// Everything cheap dismisses back into the lesson: the scrim, a downward drag,
/// the primary button. Only the word SAIR ends the run.
struct QuitSheet: View {

    var onStay: () -> Void
    var onQuit: () -> Void

    /// Follows the finger, then springs back. Never travels up — dragging the
    /// card into the notch reads as a bug.
    @State private var drag: CGFloat = 0

    /// Past this the intent is clear enough to close without a second thought.
    private let dismissThreshold: CGFloat = 90

    var body: some View {
        VStack(spacing: 26) {
            grabber

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
        .padding(.top, 12)
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
        .offset(y: drag)
        .gesture(
            DragGesture()
                .onChanged { value in
                    drag = max(0, value.translation.height)
                }
                .onEnded { value in
                    if value.translation.height > dismissThreshold {
                        onStay()
                        // Reset behind the exit so a reopened card starts seated.
                        drag = 0
                    } else {
                        withAnimation(Theme.snap) { drag = 0 }
                    }
                }
        )
    }

    private var grabber: some View {
        Capsule()
            .fill(Theme.line)
            .frame(width: 44, height: 5)
    }
}

#Preview {
    ZStack {
        Theme.pale.ignoresSafeArea()
        QuitSheet(onStay: {}, onQuit: {})
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
