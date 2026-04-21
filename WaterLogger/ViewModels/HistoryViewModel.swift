import Foundation
import SwiftData
import Observation

/// A pre-computed summary for a single calendar day, used by the bar chart in `HistoryView`.
///
/// `Identifiable` conformance uses `date` as the stable ID, which is safe here
/// because `daySummaries` always contains one entry per unique calendar day.
struct DaySummary: Identifiable {
    /// The calendar day this summary represents (time component is start-of-day).
    let date: Date
    /// Total hydration-adjusted intake in ml for this day.
    let effectiveMl: Double
    /// All raw `IntakeEntry` records that fall on this day (for the drill-down sheet).
    let entries: [IntakeEntry]

    /// Stable identifier — the date itself, since each day appears at most once.
    var id: Date { date }
}

/// View model for `HistoryView` — provides the 7-day bar chart data and drill-down entries.
///
/// `@Observable` makes all stored properties automatically observable by SwiftUI views,
/// without the need to mark each one with `@Published`.
@Observable
final class HistoryViewModel {
    /// Summaries for the last 7 calendar days, ordered oldest-first (for left-to-right chart rendering).
    private(set) var daySummaries: [DaySummary] = []
    /// The user's daily goal in ml, loaded from `AppSettings`. Used to draw the goal line on the chart.
    private(set) var goalMl: Double = 2000
    /// The day the user tapped on the chart, used to show that day's entry list.
    var selectedDate: Date?

    /// The intake entries for `selectedDate`, or an empty array if no day is selected.
    ///
    /// Looks up the matching `DaySummary` using `Calendar.isDate(_:inSameDayAs:)` to
    /// avoid time-component mismatches.
    var selectedDayEntries: [IntakeEntry] {
        guard let date = selectedDate,
              let summary = daySummaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        else { return [] }
        return summary.entries
    }

    /// Fetches the last 7 days of intake entries from SwiftData and groups them into `daySummaries`.
    ///
    /// Days with no entries still appear in the chart (with `effectiveMl == 0`), so
    /// the bar chart always shows a full 7-day window.
    ///
    /// - Parameter context: The SwiftData context provided by `@Environment(\.modelContext)`.
    func load(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: today) else { return }

        let descriptor = FetchDescriptor<IntakeEntry>(
            predicate: #Predicate { $0.date >= sevenDaysAgo },
            sortBy: [SortDescriptor(\.date)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        goalMl = (try? context.fetch(settingsDescriptor))?.first?.dailyGoalMl ?? 2000

        // Build one summary per day for the last 7 days (including today)
        daySummaries = (0..<7).compactMap { offset -> DaySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: sevenDaysAgo) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let effectiveMl = dayEntries.reduce(0) { $0 + $1.effectiveMl }
            return DaySummary(date: day, effectiveMl: effectiveMl, entries: dayEntries)
        }
    }
}
