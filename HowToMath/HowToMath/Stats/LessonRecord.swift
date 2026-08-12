//
//  LessonRecord.swift
//  HowToMath
//

import Foundation

/// One answer, exactly as it happened.
///
/// The grain is the *attempt*, not the question, and that is the whole reason
/// this file exists. A question answered wrong and then right is two attempts,
/// so the history can still say which one came first, how long each took, and
/// what the wrong guess actually was. Store one row per question instead and
/// every one of those is gone forever — you can always collapse attempts into
/// questions later, and you can never go the other way.
struct AttemptRecord: Codable, Hashable {

    /// The concept, and the most valuable field on the record.
    ///
    /// In arithmetic what trips someone up is a number; in algebra it is a
    /// *rule* — distributing, isolating the term, recognising a difference of
    /// squares. No amount of analysis on `numbers` reaches that, and it is what
    /// turns into advice worth giving: "your borrowing subtractions take twice
    /// as long" is a finding, "you did twelve lessons" is a vanity metric.
    let skill: String

    /// How it was presented: `equation`, `story`, `gap`, `build`, `match`.
    let style: String

    /// The question as it was shown: `7 + 8`, `2(x+5) = 10`.
    let prompt: String

    /// The numbers that appeared, in order. `[7, 8]`, or `[2, 5, 10]`.
    ///
    /// Doubles rather than integers, because a coefficient arrives fractional
    /// the moment equations do. Kept even though it is all inside `prompt`,
    /// since the alternative is writing a parser to answer "does she miss more
    /// often when a number is negative".
    let numbers: [Double]

    /// `+`, `−`, `×`. Nil when the question is not a single operation.
    let operation: String?

    /// Always a list. `["15"]` for a sum, `["1", "-6"]` for a quadratic.
    ///
    /// Text, not numbers: a root is a fraction, is negative, and one day is
    /// `2/3`. An `Int` answer was the field that made the first schema unable to
    /// hold anything past arithmetic.
    let solutions: [String]

    /// What the player gave, in the same shape.
    let chosen: [String]
    let correct: Bool

    /// Up to the first touch. Separates "did not know" from "knew, was looking
    /// out of the window" — without it `seconds` averages two different things.
    let hesitationSeconds: Double?
    /// Up to the answer landing.
    let seconds: Double

    /// The app went to the background mid-question.
    ///
    /// Produces no insight of its own; it stops the others from lying. Without
    /// it a phone left face-up on a table for seven minutes poisons every
    /// average anyone computes from this table, forever.
    let wasBackgrounded: Bool

    /// The choices that were on screen. Without them `chosen` cannot say
    /// whether the tempting wrong answer was even offered.
    let options: [String]

    /// The run of correct answers at the moment of answering: does accuracy
    /// fall off under a streak?
    let streakAtAnswer: Int

    /// Whether this was a question coming back around after a miss.
    let isRetry: Bool
    /// Wrong pairs turned over before a matching board was cleared. Zero for
    /// every other style, and the only miss a matching question can produce —
    /// a bad pair costs the streak without ending the round.
    let badPairs: Int
}

/// Everything one finished lesson knows about itself.
///
/// Written whole, once, when the last question lands. Only three numbers on it
/// are shown to anyone today — the rest is here because it costs nothing to
/// write and cannot be recovered afterwards: which operation is slowest, whether
/// gap questions really are the ones that trip people up, what time of day the
/// app actually gets used, whether accuracy falls off at question eight.
///
/// `Codable` end to end and flat on purpose. When this does go to a server, the
/// rows go up as they are.
struct LessonRecord: Codable, Identifiable, Hashable {

    let id: UUID
    let stageId: Int
    let stageTitle: String

    let startedAt: Date
    let finishedAt: Date
    /// Wall-clock length of the run, banner-reading time included — the honest
    /// answer to "how long did that take me", which is the one the screen shows.
    var seconds: Double { finishedAt.timeIntervalSince(startedAt) }

    /// Questions the lesson asked, retries and all.
    let askedTotal: Int
    /// How long the lesson would have been with no misses. Always 10 today, kept
    /// on the record anyway so a change to the lesson length never silently
    /// rewrites the accuracy of everything already stored.
    let baseTotal: Int
    /// Questions answered right the first time they were seen.
    let firstTryCorrect: Int
    let misses: Int
    let bestStreak: Int

    let xp: Int

    /// Every answer, in order.
    let attempts: [AttemptRecord]

    /// Which build wrote the row, so a jump in the numbers can be traced to a
    /// release rather than argued about.
    let appVersion: String
    /// On the lesson and not on the attempt: it cannot change mid-run, and it
    /// exists only to tell "this phone is slow" apart from "this person is
    /// thinking".
    let deviceModel: String
    let osVersion: String

    var isPerfect: Bool { misses == 0 }

    /// Right first time, out of the questions the lesson set out to ask.
    ///
    /// Against `baseTotal` rather than `askedTotal`: a lesson grows by one for
    /// every miss, so dividing by the grown total would forgive the mistake it
    /// is supposed to be counting — miss three and you would be scored out of
    /// thirteen for having got seven right.
    var accuracy: Double {
        guard baseTotal > 0 else { return 0 }
        return Double(firstTryCorrect) / Double(baseTotal)
    }

    /// The lesson's XP.
    ///
    /// Stored rather than computed on read. The formula will change — every
    /// scoring rule does — and when it does, a lesson finished last month has to
    /// keep the number it was actually awarded, or a total that a player has
    /// been watching go up will quietly change behind them.
    static func award(firstTryCorrect: Int, misses: Int) -> Int {
        // A point for each clean answer, and five for a clean sheet. The bonus
        // is deliberately worth half a lesson: big enough to be worth going
        // after, small enough that a bad day is not a wasted one.
        firstTryCorrect + (misses == 0 ? 5 : 0)
    }
}
