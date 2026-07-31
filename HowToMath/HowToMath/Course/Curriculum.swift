//
//  Curriculum.swift
//  HowToMath
//

import Foundation

/// One unit of the course: a closed topic, small enough to finish in about two
/// minutes.
///
/// A stage is defined by three axes — which operations it asks, how big the
/// numbers get, and which question styles are unlocked. The last one matters as
/// much as the arithmetic: a child who can add still cannot read a word problem,
/// so the early stages ask bare sums only and the written styles arrive later.
struct Stage: Identifiable, Hashable {
    let id: Int
    let title: String
    let section: String
    let operations: [MathOperation]
    let range: ClosedRange<Int>
    let styles: [ProblemStyle]


    /// The style for a given question, rotated so a lesson never asks the same
    /// format twice in a row while a stage has more than one unlocked.
    func style(at index: Int) -> ProblemStyle {
        styles[index % styles.count]
    }

    func operation(at index: Int) -> MathOperation {
        operations[index % operations.count]
    }
}

/// The course, in order. Each section introduces one operation on its own and
/// closes with a stage that mixes it back into everything already learned —
/// nothing is ever retired, it just stops being the only thing on screen.
enum Curriculum {

    static let stages: [Stage] = [
        // MARK: Soma
        Stage(id: 0, title: "Soma até 10", section: "Soma",
              operations: [.add], range: 1...9, styles: [.equation]),
        Stage(id: 1, title: "Soma até 20", section: "Soma",
              operations: [.add], range: 2...12, styles: [.equation, .match]),
        Stage(id: 2, title: "Soma no dia a dia", section: "Soma",
              operations: [.add], range: 2...12, styles: [.equation, .story, .match]),
        Stage(id: 3, title: "Montar somas", section: "Soma",
              operations: [.add], range: 2...14, styles: [.equation, .build, .gap]),

        // MARK: Subtração
        Stage(id: 4, title: "Subtração até 10", section: "Subtração",
              operations: [.subtract], range: 1...10, styles: [.equation]),
        Stage(id: 5, title: "Subtração até 20", section: "Subtração",
              operations: [.subtract], range: 2...18, styles: [.equation, .match]),
        Stage(id: 6, title: "Sobrou quanto?", section: "Subtração",
              operations: [.subtract], range: 2...18, styles: [.equation, .story]),
        Stage(id: 7, title: "Soma e subtração", section: "Subtração",
              operations: [.add, .subtract], range: 2...15,
              styles: [.equation, .match, .story, .build]),

        // MARK: Vezes
        Stage(id: 8, title: "Vezes 2, 5 e 10", section: "Vezes",
              operations: [.multiply], range: 2...10, styles: [.equation]),
        Stage(id: 9, title: "Vezes 3 e 4", section: "Vezes",
              operations: [.multiply], range: 2...9, styles: [.equation, .match]),
        Stage(id: 10, title: "Tabuada inteira", section: "Vezes",
              operations: [.multiply], range: 2...9, styles: [.equation, .match, .build]),
        Stage(id: 11, title: "Vezes no dia a dia", section: "Vezes",
              operations: [.multiply], range: 2...9, styles: [.equation, .story]),

        // MARK: Tudo junto
        Stage(id: 12, title: "Mistura tudo", section: "Tudo junto",
              operations: [.add, .subtract, .multiply], range: 2...12,
              styles: [.equation, .match, .story, .build, .gap])
    ]

    static func stage(id: Int) -> Stage { stages[min(max(id, 0), stages.count - 1)] }
}

/// What the learner has finished, kept between launches.
///
/// `UserDefaults` is the right size for this: a handful of integers that must
/// survive a relaunch. It grows into something larger the day stats need a
/// history rather than a high-water mark.
@Observable
final class CourseProgress {

    private static let key = "howtomath.completedStages"

    private(set) var completed: Set<Int>

    init() {
        let stored = UserDefaults.standard.array(forKey: Self.key) as? [Int] ?? []
        completed = Set(stored)
    }

    /// The next stage is open only once the one before it is done. Stage zero is
    /// always open, so a fresh install has exactly one thing to tap.
    func isUnlocked(_ stage: Stage) -> Bool {
        stage.id == 0 || completed.contains(stage.id - 1)
    }

    func isCompleted(_ stage: Stage) -> Bool { completed.contains(stage.id) }

    func complete(_ stage: Stage) {
        guard !completed.contains(stage.id) else { return }
        completed.insert(stage.id)
        UserDefaults.standard.set(Array(completed), forKey: Self.key)
    }

    /// The furthest stage that can be played — where the map should open.
    var current: Stage {
        Curriculum.stages.first { !completed.contains($0.id) } ?? Curriculum.stages.last!
    }
}
