//
//  StatsStore.swift
//  HowToMath
//

import Foundation

/// Every lesson ever finished, on disk.
///
/// A file rather than `UserDefaults`, which is where the rest of this app keeps
/// its state. Defaults is a preferences store: it is loaded into memory whole,
/// on launch, on the main thread — fine for a set of stage numbers and wrong for
/// a list that grows by one record with ten attempts inside it every few
/// minutes. This writes JSON to Application Support, which is the folder Apple
/// means for exactly this: data the app generates, that the user cannot see, and
/// that should be backed up.
///
/// It is also deliberately the *shape* of a table. One row per lesson, flat
/// fields, no object graph. Nothing here is going to a server yet — without
/// accounts there is nothing to sync and nobody to sync it to — but when it
/// does, the migration is reading this file and posting the rows.
@Observable
final class StatsStore {

    static let shared = StatsStore()

    /// Newest last, the order they were played in.
    private(set) var records: [LessonRecord] = []

    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? Self.defaultURL
        records = Self.load(from: self.url)
    }

    // MARK: - Writing

    func record(_ lesson: LessonRecord) {
        records.append(lesson)
        save()
    }

    /// Kept for the debug menu and for tests. Nothing in the app calls it.
    func erase() {
        records = []
        save()
    }

    // MARK: - Totals

    var totalXP: Int { records.reduce(0) { $0 + $1.xp } }

    var lessonsFinished: Int { records.count }

    var perfectLessons: Int { records.filter(\.isPerfect).count }

    /// Time spent inside lessons, in seconds.
    var totalSeconds: Double { records.reduce(0) { $0 + $1.seconds } }

    /// The best run of correct answers across every lesson ever played.
    var bestStreakEver: Int { records.map(\.bestStreak).max() ?? 0 }

    /// First-time-right across everything, weighted by how many questions each
    /// lesson asked rather than by averaging the percentages — ten lessons of
    /// ten questions and one of two should not count the same.
    var lifetimeAccuracy: Double {
        let asked = records.reduce(0) { $0 + $1.baseTotal }
        guard asked > 0 else { return 0 }

        let right = records.reduce(0) { $0 + $1.firstTryCorrect }
        return Double(right) / Double(asked)
    }

    /// Days in a row, counting back from today, with at least one lesson on
    /// them.
    ///
    /// Yesterday counts as the start of the run as well as today, so a streak is
    /// not lost at midnight — it is lost by missing a whole day. Anything else
    /// punishes someone for not having played yet this morning.
    var dayStreak: Int {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.finishedAt) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: .now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        var cursor = days.contains(today) ? today : yesterday
        guard days.contains(cursor) else { return 0 }

        var run = 0
        while days.contains(cursor) {
            run += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return run
    }

    // MARK: - Disk

    private static var defaultURL: URL {
        let folder = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "lesson-history.json")
    }

    private static func load(from url: URL) -> [LessonRecord] {
        guard let data = try? Data(contentsOf: url) else { return [] }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // A history that cannot be read is dropped rather than thrown: losing
        // the numbers is a disappointment, and refusing to open the app because
        // of them is a bug.
        return (try? decoder.decode([LessonRecord].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
