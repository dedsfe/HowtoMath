//
//  FeedbackBanner.swift
//  HowToMath
//

import SwiftUI

/// The panel that slides up from the bottom after a miss.
///
/// Only misses get one. A correct answer is already confirmed three ways — the
/// tile fills, the tone rises, the burst fires — so stopping the run to say
/// "correct" would be pure friction. The panel exists to hold the screen still
/// at the one moment the user actually has something to read, and it hands the
/// timing to them: no auto-advance, they leave when they are done looking.
struct FeedbackBanner: View {

    /// Text rather than a number: a comparison round answers with a side, not
    /// with a value.
    let answer: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Theme.missSoft)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.missDeep))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Resposta certa:")
                        .font(Theme.label(14, .bold))
                    Text(answer)
                        .font(Theme.numeral(26))
                }
                .foregroundStyle(Theme.missDeep)

                Spacer(minLength: 0)
            }

            Button(action: onContinue) {
                Text("ENTENDI")
                    .font(Theme.label(18, .heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
            }
            .buttonStyle(LipStyle(face: Theme.missDeep, edge: Theme.missEdge))
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            Theme.missSoft
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    VStack {
        Spacer()
        FeedbackBanner(answer: "19") {}
    }
}
