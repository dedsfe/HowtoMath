//
//  LessonView.swift
//  HowToMath
//

import SwiftUI

/// The lesson screen — the whole product, for now.
///
/// Design intent follows `design.md`: the Duolingo shape language — white
/// surface, heavy rounded type, chunky buttons that sink onto a 3D lip — in our
/// own green. One accent carries every positive signal, and the pale halo
/// behind the problem swells with the streak so a good run visibly fills the
/// screen. The rising pentatonic tone in `SoundEngine` is the audio half of
/// the same idea.
struct LessonView: View {

    @State private var model: LessonViewModel
    @Environment(\.dismiss) private var dismiss
    /// Carries a chip from the bank into its slot instead of teleporting it.
    @Namespace private var pieceFlight

    /// One duration for both directions of the arrival screen, so in and out
    /// can never drift apart.
    private let arrivalFade = Animation.easeInOut(duration: 0.42)

    /// Shown once, on the way into the fixing round.
    @State private var showingArrival = false
    @State private var arrivalDone = false

    /// The lesson is handed a stage; everything it asks comes from there.
    let onFinish: (Bool) -> Void

    init(stage: Stage, onFinish: @escaping (Bool) -> Void = { _ in }) {
        _model = State(initialValue: LessonViewModel(stage: stage))
        self.onFinish = onFinish
    }

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if model.isFixing {
                    fixingBadge
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                instruction
                    .padding(.horizontal, 20)
                    .padding(.top, model.isFixing ? 10 : 20)

                Spacer(minLength: 0)

                // The creature sits above the question whatever the question is,
                // so it is a constant presence rather than something that comes
                // and goes with the format.
                Creature(size: 74, animation: creatureMood)
                    .padding(.top, 10)

                // A fixed stage: without it each style is a different height and
                // the problem jumps up and down as the types rotate. Every style
                // sits in it the same way, the board included.
                problemBlock
                    .frame(maxWidth: .infinity, minHeight: 250)

                Spacer(minLength: 0)

                answerGrid
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
            // The banner is an inset rather than an overlay, so the grid lifts
            // out of its way instead of being sliced in half. A correct answer
            // never raises one — the run keeps its rhythm.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if case .wrong = model.phase {
                    FeedbackBanner(answer: model.problem.answerLabel) {
                        model.acknowledge()
                    }
                    .transition(.move(edge: .bottom))
                }
            }

            if showingArrival {
                // Fades in over the question and lifts away when it leaves, so
                // the cut to a blank white screen is a move rather than a jolt.
                ArrivalScreen {
                    withAnimation(arrivalFade) { showingArrival = false }
                }
                // Symmetric on purpose: the same curve and the same 0.42s in
                // both directions. Different scales at each end were reading as
                // different speeds even though the timing already matched.
                .transition(.opacity.combined(with: .scale(scale: 1.03)))
                .zIndex(3)
            }

            if model.phase == .finished {
                summary
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(2)
            }
        }
        .animation(Theme.settle, value: model.phase)
        // Fires the moment the run crosses from new questions into repeats, and
        // only that once.
        .onChange(of: model.isFixing) { _, fixing in
            guard fixing, !arrivalDone else { return }
            arrivalDone = true
            withAnimation(arrivalFade) { showingArrival = true }
        }
        .onAppear {
            Haptics.prepare()
            _ = SoundEngine.shared // warm the audio graph before the first tap
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            Theme.surface

            // The halo: a pale wash that swells with the streak.
            RadialGradient(
                colors: [Theme.pale.opacity(0.55 + 0.45 * heat), .clear],
                center: .init(x: 0.5, y: 0.32),
                startRadius: 0,
                endRadius: 260 + 220 * heat
            )
        }
        .ignoresSafeArea()
        .animation(Theme.settle, value: model.streak)
    }

    private var heat: Double { min(Double(model.streak) / 8, 1) }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                onFinish(false)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.dim)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }

            progressBar

            streakPill

            #if DEBUG
            styleToggle
            arrivalToggle
            #endif
        }
        .frame(height: 44)
    }

    #if DEBUG
    /// Cycles the question style so a type can be checked without grinding the
    /// rotation. Debug builds only — it never ships.
    private var styleToggle: some View {
        Button {
            model.cycleForcedStyle()
        } label: {
            Text(model.forcedStyleLabel)
                .font(Theme.label(10, .heavy))
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
    #endif

    #if DEBUG
    /// Plays the arrival screen on demand. Debug builds only.
    private var arrivalToggle: some View {
        Button {
            withAnimation(arrivalFade) { showingArrival = true }
        } label: {
            Text("BOT")
                .font(Theme.label(10, .heavy))
                .foregroundStyle(Theme.dim)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(Capsule().strokeBorder(Theme.line, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
    #endif

    private var progressBar: some View {
        LessonProgressBar(
            progress: model.displayProgress,
            streak: model.streak,
            burstToken: model.burstToken,
            color: model.accent
        )
    }

    private var streakPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(model.accent)
            Text("\(model.streak)")
                .font(Theme.label(15, .bold))
                .foregroundStyle(Theme.text)
                .contentTransition(.numericText(value: Double(model.streak)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Theme.pale))
        .opacity(model.streak >= 2 ? 1 : 0)
        .scaleEffect(model.streak >= 2 ? 1 : 0.7)
        .animation(Theme.snap, value: model.streak)
    }

    /// Says out loud that this one already went wrong once, so a repeat reads as
    /// the run fixing itself rather than as the app looping.
    private var fixingBadge: some View {
        Label("Consertando um erro", systemImage: "arrow.counterclockwise")
            .font(Theme.label(13, .heavy))
            .foregroundStyle(Theme.missDeep)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Theme.missSoft))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Instruction

    /// The task in a few words, anchored under the bar. It also gives the screen
    /// a top edge — without it the content floats in the middle of nothing.
    private var instruction: some View {
        Text(model.problem.instruction)
            .font(Theme.label(28, .heavy))
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
            .animation(Theme.settle, value: model.problem.instruction)
    }

    // MARK: - Problem

    @ViewBuilder
    private var problemBlock: some View {
        switch model.problem.style {
        case .gap: gapBlock
        case .story: writtenBlock
        case .equation: equationBlock
        case .build: buildBlock
        case .match: matchBlock
        }
    }

    private var matchBlock: some View {
        MatchBoard(
            sums: model.problem.sums,
            results: model.problem.results,
            picked: model.pickedCard,
            missToken: model.missToken,
            accent: model.accent,
            isMatched: model.isMatched,
            onPick: { card in withAnimation(Theme.glide) { model.pick(card) } }
        )
        .id(model.problem.id)
        .transition(.blurReplace.combined(with: .scale(0.92)))
        .burst(model.burstToken, color: model.accent)
        .animation(Theme.settle, value: model.problem.id)
    }

    /// Build a sum that reaches a total which never leaves the screen: three
    /// slots and `= 15` sitting on the same line, so the goal is always in view
    /// while the pieces go in.
    private var buildBlock: some View {
        FlowLayout(spacing: 8, lineSpacing: 12) {
            ForEach(0..<3, id: \.self) { position in
                Button {
                    withAnimation(Theme.glide) { model.removePlaced(at: position) }
                } label: {
                    slot(at: position)
                }
                .buttonStyle(.plain)
                .disabled(!model.placed.indices.contains(position))
            }

            Text("=")
                .font(Theme.numeral(30))
                .foregroundStyle(Theme.dim)

            Text("\(model.problem.answer)")
                .font(Theme.numeral(44))
                .foregroundStyle(model.accent)
        }
        .padding(.horizontal, 24)
        .id(model.problem.id)
        .transition(.blurReplace.combined(with: .scale(0.92)))
        .burst(model.burstToken, color: model.accent)
        .animation(Theme.settle, value: model.problem.id)
        .animation(Theme.snap, value: model.phase)
    }

    /// One slot of a build. The bed is always there; the piece that lands in it
    /// is drawn separately so it can fly in from the bank.
    private func slot(at position: Int) -> some View {
        let bankIndex = model.placed.indices.contains(position) ? model.placed[position] : nil

        return ZStack {
            ChipSocket()

            if let bankIndex {
                PieceFace(
                    label: model.problem.bank[bankIndex].label,
                    face: isWrongPick ? Theme.missSoft : Theme.pale,
                    edge: isWrongPick ? Theme.miss : model.accent
                )
                .matchedGeometryEffect(id: bankIndex, in: pieceFlight, properties: .position)
            }
        }
    }

    /// The gap question: the sentence is built word by word so the hole can be a
    /// real view sitting in the line of text, the way it reads on paper.
    private var gapBlock: some View {
        VStack(spacing: 20) {
                FlowLayout(spacing: 7, lineSpacing: 12) {
                    ForEach(Array(sentenceParts.enumerated()), id: \.offset) { _, part in
                        if part == StoryBank.blank {
                            GapSlot(
                                filled: pickedValue.map(String.init),
                                isWrong: isWrongPick,
                                accent: model.accent
                            )
                            .burst(model.burstToken, color: model.accent)
                        } else {
                            Text(numeralsHighlighted(part))
                                .font(Theme.label(25, .bold))
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
                .padding(.horizontal, 24)

                if isSolved {
                    Text(model.problem.solvedLine)
                        .font(Theme.numeral(32))
                        .foregroundStyle(model.accent)
                        .transition(.scale(0.6).combined(with: .opacity))
                }
            }
        .id(model.problem.id)
        .transition(.blurReplace.combined(with: .scale(0.92)))
        .animation(Theme.settle, value: model.problem.id)
        .animation(Theme.snap, value: model.phase)
    }

    /// The sentence split into flowable pieces, with the blank standing alone so
    /// it can be swapped for the slot view. Punctuation glued to the blank stays
    /// with the following piece rather than orphaning a line.
    private var sentenceParts: [String] {
        (model.problem.text ?? "")
            .replacingOccurrences(of: StoryBank.blank, with: " \(StoryBank.blank) ")
            .split(separator: " ")
            .map(String.init)
    }

    /// What was picked this round, right or wrong — the slot shows it either way.
    private var pickedValue: Int? {
        switch model.phase {
        case .correct(let choice), .wrong(let choice): choice
        default: nil
        }
    }

    /// The creature reacts to the round: it tells the story, then owns the result.
    private var creatureMood: CreatureAnimation {
        switch model.phase {
        case .correct: .celebrate
        case .wrong: .sad
        default: .idle
        }
    }

    private var isWrongPick: Bool {
        if case .wrong = model.phase { return true }
        return false
    }

    /// A written problem — story or gap. The sentence carries the question, and
    /// the sum it was hiding only surfaces once the answer lands.
    private var writtenBlock: some View {
        VStack(spacing: 20) {
                Text(numeralsHighlighted(model.problem.text ?? ""))
                    .font(Theme.label(25, .bold))
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
                    .burst(model.burstToken, color: model.accent)

                if isSolved {
                    Text(model.problem.solvedLine)
                        .font(Theme.numeral(32))
                        .foregroundStyle(model.accent)
                        .transition(.scale(0.6).combined(with: .opacity))
                }
            }
        .id(model.problem.id)
        .transition(.blurReplace.combined(with: .scale(0.92)))
        .animation(Theme.settle, value: model.problem.id)
        .animation(Theme.snap, value: model.phase)
    }

    /// Pulls the digits out of the sentence in the accent colour, so the numbers
    /// to work with are findable without reading the whole line twice. The blank
    /// in a gap question gets a pale bed instead — it reads as a slot waiting to
    /// be filled rather than as punctuation.
    private func numeralsHighlighted(_ text: String) -> AttributedString {
        var out = AttributedString()

        // The blank is split off first — it sits inside a run of non-digits, so
        // colouring by digit alone would paint half the sentence with it.
        for (offset, segment) in text.components(separatedBy: StoryBank.blank).enumerated() {
            if offset > 0 {
                var slot = AttributedString(StoryBank.blank)
                slot.foregroundColor = model.accent
                out.append(slot)
            }

            for chunk in segment.chunkedByDigits() {
                var piece = AttributedString(chunk)
                if chunk.first?.isNumber == true {
                    piece.foregroundColor = model.accent
                }
                out.append(piece)
            }
        }
        return out
    }

    private var equationBlock: some View {
        VStack(spacing: 10) {

                HStack(spacing: 16) {
                    Text("\(model.problem.left)")
                    Text(model.problem.operation.symbol)
                        .foregroundStyle(model.accent)
                    Text("\(model.problem.right)")
                }
                .font(Theme.numeral(62))
                .foregroundStyle(Theme.text)
                // A small breath on the sum itself, so the hit lands on the
                // problem and not only on the tile that was tapped.
                .scaleEffect(isSolved ? 1.04 : 1)

                // On a hit the equals sign stops hanging empty — the answer
                // drops in beside it and the problem is seen finished before
                // the next one arrives.
                HStack(spacing: 12) {
                    Text("=")
                        .font(Theme.numeral(28))
                        .foregroundStyle(Theme.dim)

                    if isSolved {
                        Text("\(model.problem.answer)")
                            .font(Theme.numeral(52))
                            .foregroundStyle(model.accent)
                            .transition(.scale(0.5).combined(with: .opacity))
                    }
                }
                .burst(model.burstToken, color: model.accent)
            }
        .id(model.problem.id)
        .transition(.blurReplace.combined(with: .scale(0.92)))
        .animation(Theme.settle, value: model.problem.id)
        .animation(Theme.snap, value: model.phase)
    }

    private var isSolved: Bool {
        if case .correct = model.phase { return true }
        return false
    }

    // MARK: - Answers

    /// Two-up squares for a bare sum; a full-width stack under a word problem,
    /// where the eye is already reading top to bottom.
    @ViewBuilder
    private var answerGrid: some View {
        if model.problem.style == .match {
            EmptyView()
        } else if model.problem.style == .build {
            // Pieces leave the bank for the slots; each one leaves its socket
            // behind so the bank never reflows under the finger.
            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(Array(model.problem.bank.enumerated()), id: \.offset) { index, token in
                    if model.placed.contains(index) {
                        ChipSocket()
                    } else {
                        ChipTile(label: token.label, isTaken: false, isDimmed: false) {
                            withAnimation(Theme.glide) { model.place(bankIndex: index) }
                        }
                        .matchedGeometryEffect(id: index, in: pieceFlight, properties: .position)
                    }
                }
            }
        } else if model.problem.style == .gap {
            // A word bank: the number leaves the bank and appears in the gap,
            // so the socket it came from stays visible and empty.
            FlowLayout(spacing: 10, lineSpacing: 12) {
                ForEach(model.problem.choices, id: \.self) { choice in
                    ChipTile(
                        label: "\(choice)",
                        isTaken: pickedValue == choice,
                        isDimmed: pickedValue != nil && pickedValue != choice
                    ) {
                        model.choose(choice)
                    }
                }
            }
        } else if model.problem.isWritten {
            VStack(spacing: 10) {
                ForEach(model.problem.choices, id: \.self) { choice in
                    tile(for: choice, height: 60)
                }
            }
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(model.problem.choices, id: \.self) { choice in
                    tile(for: choice, height: 84)
                }
            }
        }
    }

    private func tile(for choice: Int, height: CGFloat) -> some View {
        AnswerTile(
            value: choice,
            state: tileState(for: choice),
            accent: model.accent,
            height: height
        ) {
            model.choose(choice)
        }
    }

    private func tileState(for value: Int) -> TileState {
        switch model.phase {
        case .asking:
            return .idle
        case .correct(let choice):
            return value == choice ? .hit : .muted
        case .wrong(let choice):
            if value == choice { return .miss }
            if value == model.problem.answer { return .reveal }
            return .muted
        case .finished:
            return .muted
        }
    }

    // MARK: - Summary

    private var summary: some View {
        ZStack {
            Theme.surface.opacity(0.96).ignoresSafeArea()

            VStack(spacing: 26) {
                Text("\(model.solved)/\(model.total)")
                    .font(Theme.numeral(64))
                    .foregroundStyle(Theme.accent(streak: model.bestStreak))

                Text("Melhor sequência: \(model.bestStreak)")
                    .font(Theme.label(17))
                    .foregroundStyle(Theme.dim)

                Button {
                    onFinish(true)
                } label: {
                    Text("CONTINUAR")
                        .font(Theme.label(18, .heavy))
                        .tracking(0.8)
                        .foregroundStyle(.white)
                }
                .buttonStyle(LipStyle(face: Theme.green, edge: Theme.greenEdge))
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
        }
    }
}

private extension View {
    /// Fires the confetti centred on *this* view — whatever part of the screen
    /// the answer actually lands on — instead of the middle of the stage.
    func burst(_ token: Int, color: Color) -> some View {
        overlay {
            ParticleBurst(token: token, color: color)
                .frame(width: 280, height: 260)
                .allowsHitTesting(false)
        }
    }
}

private extension String {
    /// Splits into runs of digits and runs of everything else, keeping order —
    /// enough to colour the numbers in a sentence without a regex pass.
    func chunkedByDigits() -> [String] {
        reduce(into: [String]()) { chunks, character in
            let sameKind = chunks.last?.first.map { $0.isNumber == character.isNumber }
            if sameKind == true {
                chunks[chunks.count - 1].append(character)
            } else {
                chunks.append(String(character))
            }
        }
    }
}

#Preview {
    LessonView(stage: Curriculum.stages[2])
}
