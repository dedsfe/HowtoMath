//
//  GapSentence.swift
//  HowToMath
//

import SwiftUI

/// Lays subviews out left to right, wrapping to a new line when the next one
/// would not fit — what `Text` does with words, but for arbitrary views.
///
/// A sentence with a hole in it cannot be one `Text`, because the hole is a
/// view. So the sentence becomes one view per word and this puts them back
/// together. The word bank at the bottom of the screen wraps the same way.
struct FlowLayout: Layout {

    var spacing: CGFloat = 7
    var lineSpacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(for: subviews, maxWidth: width)

        let height = rows.reduce(0) { $0 + $1.height }
            + lineSpacing * CGFloat(max(rows.count - 1, 0))

        return CGSize(
            width: width.isFinite ? width : (rows.map(\.width).max() ?? 0),
            height: height
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY

        for row in rows(for: subviews, maxWidth: bounds.width) {
            // Rows are centred: a ragged last line reads as part of a paragraph
            // rather than as something that failed to fill.
            var x = bounds.minX + (bounds.width - row.width) / 2

            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows = [Row()]

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing

            if rows[rows.count - 1].width + needed > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }

            let last = rows.count - 1
            rows[last].indices.append(index)
            rows[last].width += rows[last].indices.count == 1 ? size.width : size.width + spacing
            rows[last].height = max(rows[last].height, size.height)
        }
        return rows
    }
}

/// The hole in the sentence. Empty and grey while the question is open, then
/// filled with whatever was picked — right or wrong, the number lands here so
/// the sentence can be read back complete.
struct GapSlot: View {

    /// The label sitting in the slot — a number, or an operator in a build.
    let filled: String?
    let isWrong: Bool
    let accent: Color

    var body: some View {
        Text(filled ?? " ")
            .font(Theme.numeral(26))
            .foregroundStyle(isWrong ? Theme.miss : accent)
            .frame(minWidth: 68, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(border, lineWidth: 2)
            )
            .animation(Theme.snap, value: filled)
    }

    private var background: Color {
        guard filled != nil else { return Theme.track }
        return isWrong ? Theme.missSoft : Theme.pale
    }

    private var border: Color {
        guard filled != nil else { return .clear }
        return isWrong ? Theme.miss : accent
    }
}

/// A number from the word bank. Same 3D lip as the big tiles, sized to its own
/// content, and left as an empty socket once it has been moved into the gap.
struct ChipTile: View {

    let label: String
    let isTaken: Bool
    let isDimmed: Bool
    let action: () -> Void

    /// Every chip is the same size, whatever it holds. A bank of ragged widths
    /// stops reading as one control, and the empty socket left behind has to
    /// match the piece that came out of it.
    static let width: CGFloat = 74
    static let height: CGFloat = 60

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.numeral(28))
                .foregroundStyle(Theme.text)
                .frame(width: Self.width)
        }
        .buttonStyle(LipStyle(face: Theme.surface, edge: Theme.line, height: Self.height, stretches: false))
        .disabled(isTaken || isDimmed)
        .opacity(isDimmed ? 0.32 : 1)
    }
}

/// The hole a chip leaves in the bank once it has been moved into a slot.
struct ChipSocket: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
            .fill(Theme.track)
            .frame(width: ChipTile.width, height: ChipTile.height + Theme.lip)
    }
}

/// A piece at rest — same face, same lip, same footprint as a chip in the bank,
/// but not a button. A number that has landed in a slot has to keep the 3D
/// identity it had in the bank; flattening it there was reading as a different
/// component halfway through the same gesture.
struct PieceFace: View {

    let label: String
    let face: Color
    let edge: Color

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)

        ZStack(alignment: .top) {
            shape
                .fill(edge)
                .frame(width: ChipTile.width, height: ChipTile.height + Theme.lip)

            Text(label)
                .font(Theme.numeral(28))
                .foregroundStyle(Theme.text)
                .frame(width: ChipTile.width, height: ChipTile.height)
                .background(shape.fill(face))
                .overlay(shape.strokeBorder(edge, lineWidth: 2))
        }
        .frame(width: ChipTile.width, height: ChipTile.height + Theme.lip)
    }
}
