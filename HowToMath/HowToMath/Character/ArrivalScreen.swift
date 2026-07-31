//
//  ArrivalScreen.swift
//  HowToMath
//

import SwiftUI

/// The beat before the fixing round: a blank white screen the creature drops
/// into, spins on, and shakes off.
///
/// It exists to mark a change of chapter. Going straight from the last new
/// question into a repeat of an old one reads as the app glitching; a held
/// moment with nothing else on screen says out loud that something different is
/// starting now.
struct ArrivalScreen: View {

    var onDone: () -> Void

    /// Arrives, then simply exists — the entrance plays once and hands over to
    /// the idle loop, so the screen does not turn into a looping cartoon.
    @State private var mood: CreatureAnimation = .arrive

    /// Long enough for the landing, the dizziness and a breath after it.
    private let dwell = 3.4

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 34) {
                Creature(size: 190, animation: mood)

                Text("Bora consertar as escolhas erradas?")
                    .font(Theme.label(24, .heavy))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        // Tappable to skip: nobody should be held by a cutscene they have
        // already seen twenty times.
        .contentShape(.rect)
        .onTapGesture { onDone() }
        .task {
            // The arrival takes about two seconds including the dizzy spell.
            try? await Task.sleep(for: .seconds(2.3))
            mood = .idle

            try? await Task.sleep(for: .seconds(dwell - 2.3))
            onDone()
        }
    }
}

#Preview {
    ArrivalScreen {}
}
