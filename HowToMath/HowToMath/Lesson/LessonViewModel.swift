//
//  LessonViewModel.swift
//  HowToMath
//

import Foundation
import SwiftUI

enum MathOperation: CaseIterable, Hashable {
    case add, subtract, multiply

    var symbol: String {
        switch self {
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        }
    }
}

/// How a question is dressed. The arithmetic underneath is the same in all
/// three — only the reading changes, so difficulty never rides on the format.
enum ProblemStyle: Hashable {
    /// Bare numerals: `8 + 2 = ?`
    case equation
    /// A sentence that hides the sum. The answer is still the result.
    case story
    /// A sentence with a hole in the middle. The answer is the *operand* that
    /// closes the gap, which is the inverse operation — the part that actually
    /// trips children up.
    case gap
    /// The result is given and the sum is not: you build `7 + 8` from loose
    /// pieces to reach a total that never leaves the screen.
    case build
    /// A board of sums on one side and results on the other, cleared by pairing
    /// them off. Holding several sums at once is the point.
    case match
}

/// One card on a matching board. `key` is what makes two cards a pair.
struct MatchCard: Identifiable, Equatable {
    let id: Int
    let label: String
    let key: Int
}

/// A piece in the word bank of a `.build` question.
enum Token: Hashable, Identifiable {
    case number(Int)
    case op(MathOperation)

    var id: Self { self }

    var label: String {
        switch self {
        case .number(let value): "\(value)"
        case .op(let operation): operation.symbol
        }
    }

    var number: Int? {
        if case .number(let value) = self { return value }
        return nil
    }
}

struct Problem: Identifiable {
    let id = UUID()
    let left: Int
    let right: Int
    let operation: MathOperation
    let answer: Int
    let choices: [Int]
    let style: ProblemStyle
    /// The loose pieces for a `.build` question, already shuffled.
    var bank: [Token] = []
    /// The two columns of a `.match` board.
    var sums: [MatchCard] = []
    var results: [MatchCard] = []
    /// The sentence, for the two written styles. The bare operation stays filled
    /// in either way, so the screen can still show the sum that was hiding
    /// inside the words once it is answered.
    let text: String?

    /// Both written styles share the same layout: sentence up top, options stacked.
    var isWritten: Bool { style != .equation }

    /// What to do, in as few words as possible. Every question type carries its
    /// own line so a new type never lands on screen unexplained.
    var instruction: String {
        switch style {
        case .equation: "Resolva a conta"
        case .story: "Leia e responda"
        case .gap: "Complete o valor que falta"
        case .build: "Monte a conta"
        case .match: "Ligue cada conta ao resultado"
        }
    }

    /// The sum spelled out, shown once the answer lands. A gap question reads
    /// forwards here — `2 + 13 = 15` — because seeing the whole is the lesson.
    /// What the miss banner says.
    var answerLabel: String { "\(answer)" }

    var solvedLine: String {
        switch style {
        case .equation, .story, .build, .match:
            "\(left) \(operation.symbol) \(right) = \(answer)"
        case .gap:
            "\(left) \(operation.symbol) \(right) = \(left + right)"
        }
    }
}

/// Where the screen is in the answer cycle. The view keys most of its animation
/// off this, so feedback state and visual state can never drift apart.
enum LessonPhase: Equatable {
    case asking
    case correct(choice: Int)
    case wrong(choice: Int)
    case finished
}

@Observable
final class LessonViewModel {

    private(set) var problem: Problem
    private(set) var phase: LessonPhase = .asking
    private(set) var streak = 0
    private(set) var bestStreak = 0
    private(set) var solved = 0
    private(set) var index = 0

    /// How many fresh questions a run asks before any fixing starts.
    private let baseTotal = 10

    /// Grows past `baseTotal` as misses are queued up for the end.
    private(set) var total = 10

    /// Questions sent to the back of the line after a miss, kept whole so they
    /// come back exactly as they were.
    private var queue: [Problem] = []

    /// True only while a question that *came back off the queue* is on screen.
    /// Derived state was wrong here: the id is added the moment the question is
    /// queued, so the badge lit up on the miss itself instead of on the retry.
    private(set) var isFixing = false

    /// How many misses are still waiting at the end of the run.
    var pendingFixes: Int { queue.count }

    /// A run finished without a single miss.
    ///
    /// Read off the length of the lesson rather than off a counter, because the
    /// two can never disagree: a miss is what makes the lesson longer, so a
    /// lesson that never grew is a lesson nobody got wrong.
    var isPerfect: Bool { total == baseTotal }

    // MARK: - Measurement

    /// When the first question appeared.
    private let startedAt = Date()
    /// When the question now on screen appeared.
    private var questionShownAt = Date()
    /// The first touch on the question now on screen, whatever it landed on.
    private var firstTouchAt: Date?
    /// Whether the app left the foreground while this question was up.
    private var wasBackgrounded = false
    /// Wrong pairs turned over on the matching board currently on screen.
    private var badPairs = 0
    /// Every answer given in this run, in order.
    private var attempts: [AttemptRecord] = []

    /// The finished lesson, available from the moment the last question lands.
    ///
    /// Held here rather than handed to the screen as loose numbers so the thing
    /// being displayed and the thing being stored are the same object — a
    /// summary that computes its own XP is a summary that can disagree with the
    /// history.
    private(set) var result: LessonRecord?
    let stage: Stage

    /// Bumped on every correct answer so the view can retrigger the particle burst.
    private(set) var burstToken = 0

    /// Debug only: pins every question to one style, so a type can be looked at
    /// without playing through the rotation to reach it. Nil is the real game.
    private(set) var forcedStyle: ProblemStyle?

    init(stage: Stage = Curriculum.stages[0]) {
        self.stage = stage
        self.problem = Self.make(stage, index: 0, forced: nil)
    }

    /// Steps through the styles and rebuilds the current question in place.
    func cycleForcedStyle() {
        let order: [ProblemStyle?] = [nil, .equation, .story, .gap, .build, .match]
        let next = (order.firstIndex(of: forcedStyle).map { $0 + 1 } ?? 0) % order.count

        forcedStyle = order[next]
        isFixing = false
        placed = []
        matchedKeys = []
        pickedCard = nil
        phase = .asking
        problem = Self.make(stage, index: index, forced: forcedStyle)
    }

    var forcedStyleLabel: String {
        switch forcedStyle {
        case .none: "AUTO"
        case .equation: "CONTA"
        case .story: "HIST"
        case .gap: "LACUNA"
        case .build: "MONTA"
        case .match: "PAREIA"
        }
    }

    var progress: Double { Double(index) / Double(total) }

    /// What the bar actually draws. It runs ahead of the truth and eases off:
    /// the first answers move it a long way, the middle crawls, and it only
    /// meets the real number at the end. Early progress is what keeps someone
    /// in a run they have barely started — and the bar never lies about
    /// finishing, because the curve is pinned at both ends.
    var displayProgress: Double { pow(progress, 0.58) }
    var accent: Color { Theme.accent(streak: streak) }

    // MARK: - Input

    func choose(_ value: Int) {
        guard phase == .asking else { return }
        settle(value, isRight: value == problem.answer)
    }

    // MARK: - Building an expression

    /// Positions in `problem.bank` that have been moved into the slots, in
    /// order. Indices rather than tokens, so two pieces showing the same number
    /// stay independent.
    private(set) var placed: [Int] = []

    /// A build question needs both operands and the operator between them.
    private let slotCount = 3

    var placedTokens: [Token] {
        placed.compactMap { problem.bank.indices.contains($0) ? problem.bank[$0] : nil }
    }

    func place(bankIndex: Int) {
        guard phase == .asking, placed.count < slotCount,
              problem.bank.indices.contains(bankIndex),
              !placed.contains(bankIndex)
        else { return }

        placed.append(bankIndex)

        // The expression judges itself the moment it is complete — there is no
        // confirm button anywhere else in the app and there shouldn't be one here.
        guard placed.count == slotCount else { return }
        let result = evaluated()
        settle(result ?? .min, isRight: result == problem.answer)
    }

    /// Takes a piece back out of the slots and returns it to the bank.
    func removePlaced(at position: Int) {
        guard phase == .asking, placed.indices.contains(position) else { return }
        placed.remove(at: position)
    }

    /// The value of what has been built, or nil if the pieces don't form a sum.
    private func evaluated() -> Int? {
        let tokens = placedTokens
        guard tokens.count == slotCount,
              let left = tokens[0].number,
              case .op(let operation) = tokens[1],
              let right = tokens[2].number
        else { return nil }

        return switch operation {
        case .add: left + right
        case .subtract: left - right
        case .multiply: left * right
        }
    }

    // MARK: - Matching a board

    /// Pair keys already cleared from the board.
    private(set) var matchedKeys: Set<Int> = []
    /// The card waiting for a partner, if any.
    private(set) var pickedCard: MatchCard?
    /// Bumped on a bad pair so the board can shake the two cards.
    private(set) var missToken = 0

    func pick(_ card: MatchCard) {
        guard phase == .asking, !matchedKeys.contains(card.key) else { return }

        guard let first = pickedCard else {
            pickedCard = card
            return
        }

        // Tapping the same card again just puts it back down.
        guard first.id != card.id else {
            pickedCard = nil
            return
        }

        pickedCard = nil

        guard first.key == card.key else {
            // A bad pair costs the streak but never stops the board — being sent
            // to a banner four times in one question would kill the round.
            streak = 0
            missToken += 1
            badPairs += 1
            SoundEngine.shared.wrong()
            Haptics.wrong()
            return
        }

        matchedKeys.insert(card.key)
        SoundEngine.shared.correct(streak: matchedKeys.count)
        Haptics.correct(streak: matchedKeys.count)

        guard matchedKeys.count == problem.sums.count else { return }
        award(problem.answer)
    }

    func isMatched(_ card: MatchCard) -> Bool { matchedKeys.contains(card.key) }

    // MARK: - Scoring

    /// The one place a round is won or lost, whichever style produced it.
    private func settle(_ value: Int, isRight: Bool) {
        // Logged here, in the one place every style ends up, rather than in each
        // of the five places an answer can come from. A telemetry call that has
        // to be remembered five times is a telemetry call that will be forgotten
        // the first time a sixth question type is added.
        log(value, isRight: isRight)

        guard !isRight else {
            award(value)
            return
        }

        streak = 0
        phase = .wrong(choice: value)

        // The run does not end owing anything. Every miss goes to the back of
        // the line and the lesson grows by one — including a miss on a retry, so
        // the only way out is to get it right.
        queue.append(problem)
        total += 1

        SoundEngine.shared.wrong()
        Haptics.wrong()
        // The banner holds the screen until the user acknowledges.
    }

    private func award(_ value: Int) {
        streak += 1
        solved += 1
        bestStreak = max(bestStreak, streak)
        burstToken += 1
        phase = .correct(choice: value)

        SoundEngine.shared.correct(streak: streak)
        Haptics.correct(streak: streak)

        // A correct answer is already confirmed by the tile, the tone and the
        // burst, so it moves on by itself — asking for a second tap here would
        // only cost the rhythm.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) { [weak self] in
            self?.advance()
        }
    }

    /// The first touch since this question appeared. Ignored after that.
    ///
    /// The gap between a question appearing and a finger moving is the closest
    /// thing to a reading of whether someone knew it — everything after the
    /// first touch is them working, and everything before it is them deciding
    /// whether they can.
    func noteFirstTouch() {
        guard firstTouchAt == nil else { return }
        firstTouchAt = Date()
    }

    /// The app went to the background. Marks the current question's timings as
    /// not to be trusted, and never unmarks it — coming back does not undo the
    /// seven minutes.
    func noteBackgrounded() { wasBackgrounded = true }

    /// Writes down the answer that just happened.
    private func log(_ value: Int, isRight: Bool) {
        attempts.append(
            AttemptRecord(
                skill: skillName,
                style: String(describing: problem.style),
                prompt: "\(problem.left) \(problem.operation.symbol) \(problem.right)",
                numbers: [Double(problem.left), Double(problem.right)],
                operation: problem.operation.symbol,
                solutions: ["\(problem.answer)"],
                chosen: ["\(value)"],
                correct: isRight,
                // Nil when nothing was ever touched — a matching board cleared
                // by dragging, a question answered by the previous tap still
                // being processed. Empty is the honest answer there; zero would
                // read as an impossibly fast decision.
                hesitationSeconds: firstTouchAt.map { $0.timeIntervalSince(questionShownAt) },
                seconds: Date().timeIntervalSince(questionShownAt),
                wasBackgrounded: wasBackgrounded,
                options: problem.choices.map(String.init),
                streakAtAnswer: streak,
                isRetry: isFixing,
                badPairs: badPairs
            )
        )
    }

    /// The concept behind the question on screen.
    ///
    /// The one place to extend when the course reaches algebra: `2(x+5)=10` is
    /// not "addition", it is distributing and then isolating, and the whole
    /// point of `skill` is that it names the rule rather than the arithmetic.
    /// Today the course only teaches operations, so today it is the operation.
    private var skillName: String {
        switch problem.operation {
        case .add: problem.style == .gap ? "soma_inversa" : "soma"
        case .subtract: "subtracao"
        case .multiply: "multiplicacao"
        }
    }

    /// Seals the run and hands it to the history.
    ///
    /// Counted off the attempts rather than off the running counters, because
    /// the attempts are what was actually stored — anything derived a second way
    /// is a second answer waiting to disagree with the first.
    private func finish() {
        let firstTryCorrect = attempts.filter { !$0.isRetry && $0.correct }.count
        let misses = attempts.filter { !$0.correct }.count

        let lesson = LessonRecord(
            id: UUID(),
            stageId: stage.id,
            stageTitle: stage.title,
            startedAt: startedAt,
            finishedAt: Date(),
            askedTotal: total,
            baseTotal: baseTotal,
            firstTryCorrect: firstTryCorrect,
            misses: misses,
            bestStreak: bestStreak,
            xp: LessonRecord.award(firstTryCorrect: firstTryCorrect, misses: misses),
            attempts: attempts,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?",
            deviceModel: Device.model,
            osVersion: Device.osVersion
        )

        result = lesson
        StatsStore.shared.record(lesson)
    }

    /// Leaves the miss banner. Reading the right answer takes as long as it
    /// takes, so this is the user's move rather than a timer's.
    func acknowledge() {
        guard case .wrong = phase else { return }
        advance()
    }

    func restart() {
        streak = 0
        solved = 0
        index = 0
        total = 10
        attempts = []
        badPairs = 0
        result = nil
        questionShownAt = Date()
        firstTouchAt = nil
        wasBackgrounded = false
        queue = []
        isFixing = false
        phase = .asking
        placed = []
        matchedKeys = []
        pickedCard = nil
        problem = Self.make(stage, index: 0, forced: forcedStyle)
    }

    // MARK: - Flow

    private func advance() {
        index += 1
        guard index < total else {
            finish()
            phase = .finished
            SoundEngine.shared.finish()
            Haptics.finish()
            return
        }
        placed = []
        matchedKeys = []
        pickedCard = nil
        badPairs = 0
        questionShownAt = Date()
        firstTouchAt = nil
        wasBackgrounded = false
        // Fresh questions first, all ten of them. Fixing only starts once the
        // lesson proper is done — a miss should not interrupt the run.
        if index < baseTotal || queue.isEmpty {
            problem = Self.make(stage, index: index, forced: forcedStyle)
            isFixing = false
        } else {
            problem = queue.removeFirst()
            isFixing = true
        }
        phase = .asking
    }

    // MARK: - Generation

    /// The stage decides which formats exist at all; the index just rotates
    /// through them, so a lesson never asks the same one twice in a row.
    private static func style(_ stage: Stage, index: Int, forced: ProblemStyle?) -> ProblemStyle {
        forced ?? stage.style(at: index)
    }

    private static func make(_ stage: Stage, index: Int, forced: ProblemStyle?) -> Problem {
        let style = style(stage, index: index, forced: forced)
        let operation = stage.operation(at: index)
        let low = stage.range.lowerBound
        let high = stage.range.upperBound

        if style == .match {
            var seen = Set<Int>()
            var sums: [MatchCard] = []
            var results: [MatchCard] = []
            var key = 0
            var attempts = 0

            // Four pairs, and no two results alike — a repeated total would make
            // one of the sums impossible to place correctly.
            while sums.count < 4 && attempts < 80 {
                attempts += 1
                let pair = randomOperands(operation, in: stage.range)
                guard seen.insert(pair.answer).inserted else { continue }

                sums.append(MatchCard(
                    id: key,
                    label: "\(pair.left) \(operation.symbol) \(pair.right)",
                    key: key
                ))
                results.append(MatchCard(id: 100 + key, label: "\(pair.answer)", key: key))
                key += 1
            }

            return Problem(
                left: 0, right: 0, operation: operation,
                answer: 0,
                choices: [],
                style: .match,
                sums: sums.shuffled(),
                results: results.shuffled(),
                text: nil
            )
        }

        // A gap question is always additive: you hold part of a total and have
        // to find what is missing. Running it over subtraction or times tables
        // would mean two unknowns in one sentence.
        if style == .gap {
            let have = Int.random(in: low...high)
            let missing = Int.random(in: low...high)

            return Problem(
                left: have,
                right: missing,
                operation: .add,
                answer: missing,
                choices: choices(for: missing, operation: .add),
                style: .gap,
                text: StoryBank.gapText(have: have, total: have + missing)
            )
        }

        let left: Int
        let right: Int
        let answer: Int

        switch operation {
        case .add:
            left = Int.random(in: low...high)
            right = Int.random(in: low...high)
            answer = left + right
        case .subtract:
            let big = Int.random(in: max(low + 1, 3)...high)
            let small = Int.random(in: 1..<big)
            left = big
            right = small
            answer = big - small
        case .multiply:
            left = Int.random(in: low...min(high, 10))
            right = Int.random(in: low...min(high, 10))
            answer = left * right
        }

        return Problem(
            left: left,
            right: right,
            operation: operation,
            answer: answer,
            choices: choices(for: answer, operation: operation),
            style: style,
            bank: style == .build
                ? bank(left: left, right: right, operation: operation, answer: answer)
                : [],
            text: style == .story
                ? StoryBank.text(left: left, right: right, operation: operation)
                : nil
        )
    }

    /// One set of operands for the lesson's operation, with its result.
    private static func randomOperands(_ operation: MathOperation, in range: ClosedRange<Int>) -> (left: Int, right: Int, answer: Int) {
        let low = range.lowerBound, high = range.upperBound
        switch operation {
        case .add:
            let a = Int.random(in: low...high), b = Int.random(in: low...high)
            return (a, b, a + b)
        case .subtract:
            let big = Int.random(in: max(low + 1, 3)...high), small = Int.random(in: 1..<big)
            return (big, small, big - small)
        case .multiply:
            let a = Int.random(in: low...min(high, 10)), b = Int.random(in: low...min(high, 10))
            return (a, b, a * b)
        }
    }

    /// The loose pieces for a build question: the two operands, the operator,
    /// and three decoys.
    ///
    /// A decoy is only kept if it cannot be arranged into a second correct
    /// expression — otherwise the puzzle would have two right answers and the
    /// one it teaches would be the accident.
    private static func bank(left: Int, right: Int, operation: MathOperation, answer: Int) -> [Token] {
        var numbers = [left, right]
        var operators: [MathOperation] = [operation]

        // The decoy operator is never `×`: a times sign next to two small
        // numbers changes the size of the answer so wildly that it reads as a
        // trick rather than as a plausible slip.
        let spare = MathOperation.allCases
            .filter { $0 != operation && $0 != .multiply }
            .randomElement()
        if let spare { operators.append(spare) }

        var attempts = 0
        while numbers.count < 5 && attempts < 60 {
            attempts += 1
            let candidate = max(1, answer - Int.random(in: 1...9))
            guard !numbers.contains(candidate) else { continue }

            let extended = numbers + [candidate]
            guard !hasSecondSolution(numbers: extended, operators: operators, answer: answer) else { continue }
            numbers.append(candidate)
        }

        return (numbers.map(Token.number) + operators.map(Token.op)).shuffled()
    }

    /// True when some pairing other than the intended one also lands on `answer`.
    private static func hasSecondSolution(numbers: [Int], operators: [MathOperation], answer: Int) -> Bool {
        var hits = 0

        for a in numbers {
            for b in numbers where b != a || numbers.filter({ $0 == a }).count > 1 {
                for operation in operators {
                    let result = switch operation {
                    case .add: a + b
                    case .subtract: a - b
                    case .multiply: a * b
                    }
                    if result == answer { hits += 1 }
                }
            }
        }
        // Addition and multiplication commute, so the intended sum legitimately
        // shows up twice — anything beyond that is a genuine second answer.
        return hits > 2
    }

    /// Distractors mimic real slips — off-by-one, a carried digit, the neighbouring
    /// times-table row — so guessing by shape doesn't work.
    private static func choices(for answer: Int, operation: MathOperation) -> [Int] {
        var pool = Set<Int>([answer])
        let nudges: [Int]

        switch operation {
        case .add, .subtract:
            nudges = [1, -1, 2, -2, 10, -10]
        case .multiply:
            nudges = [1, -1, 2, -2, 3, -3, 5, -5]
        }

        var attempts = 0
        while pool.count < 4 && attempts < 40 {
            attempts += 1
            let candidate = answer + nudges.randomElement()!
            if candidate >= 0 { pool.insert(candidate) }
        }
        // Fallback if the nudges collided too often near zero.
        var next = answer + 1
        while pool.count < 4 {
            pool.insert(next)
            next += 1
        }

        return Array(pool).shuffled()
    }
}
