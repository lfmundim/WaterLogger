import Foundation
import SwiftData
import Observation
import SwiftUI

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
    /// Summaries for the displayed 7 calendar days, ordered oldest-first.
    private(set) var daySummaries: [DaySummary] = []
    /// The user's daily goal in ml, loaded from `AppSettings`. Used to draw the goal line on the chart.
    private(set) var goalMl: Double = 2000
    /// Mirror of `AppSettings.emojiMode` — forwarded to beverage breakdown dots.
    private(set) var emojiMode: Bool = false
    /// The day the user tapped on the chart, used to show that day's entry list.
    var selectedDate: Date?
    /// Week offset from the current week. 0 = this week, -1 = last week, etc.
    private(set) var weekOffset: Int = 0

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

    func stepWeek(by delta: Int, context: ModelContext) async {
        weekOffset += delta
        selectedDate = nil
        await load(context: context)
    }

    /// Fetches 7 days of intake entries from SwiftData for the current `weekOffset` window.
    ///
    /// Also syncs historical HealthKit data for the window so entries from other apps
    /// (e.g. Apple Watch, third-party trackers) are included before building summaries.
    ///
    /// Days with no entries still appear in the chart (with `effectiveMl == 0`), so
    /// the bar chart always shows a full 7-day window.
    ///
    /// - Parameter context: The SwiftData context provided by `@Environment(\.modelContext)`.
    func load(context: ModelContext) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Shift the window end by weekOffset weeks; clamp so we can't go into the future.
        let clampedOffset = min(weekOffset, 0)
        guard let windowEnd = calendar.date(byAdding: .day, value: clampedOffset * 7, to: today),
              let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: windowEnd) else { return }
        weekOffset = clampedOffset

        // Sync HealthKit history before reading SwiftData so imported entries are included.
        await syncHealthKitHistory(from: sevenDaysAgo, to: windowEnd, context: context)

        // windowEnd is start-of-day; include everything up to end of that day.
        guard let windowEndInclusive = calendar.date(byAdding: .day, value: 1, to: windowEnd) else { return }

        let descriptor = FetchDescriptor<IntakeEntry>(
            predicate: #Predicate { $0.date >= sevenDaysAgo && $0.date < windowEndInclusive },
            sortBy: [SortDescriptor(\.date)]
        )
        let entries = (try? context.fetch(descriptor)) ?? []

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = (try? context.fetch(settingsDescriptor))?.first
        goalMl    = settings?.dailyGoalMl ?? 2000
        emojiMode = settings?.emojiMode   ?? false

        // Build one summary per day for the 7-day window
        daySummaries = (0..<7).compactMap { offset -> DaySummary? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: sevenDaysAgo) else { return nil }
            let dayEntries = entries.filter { calendar.isDate($0.date, inSameDayAs: day) }
            let effectiveMl = dayEntries.reduce(0) { $0 + $1.effectiveMl }
            return DaySummary(date: day, effectiveMl: effectiveMl, entries: dayEntries)
        }
    }

    /// Imports HealthKit water samples for the given range that are not yet in SwiftData.
    ///
    /// Deduplication is keyed on `healthKitUUID` — existing entries are never duplicated.
    /// All imported entries default to `.water` since HealthKit has no beverage-type metadata.
    private func syncHealthKitHistory(from start: Date, to end: Date = .now, context: ModelContext) async {
        await HealthKitService.shared.requestAuthorizationIfNeeded()
        let hkEntries = await HealthKitService.shared.fetchEntries(from: start, to: end)
        guard !hkEntries.isEmpty else { return }

        // Fetch existing UUIDs once to avoid per-entry queries.
        let existingDescriptor = FetchDescriptor<IntakeEntry>(
            predicate: #Predicate { $0.date >= start }
        )
        let existing = (try? context.fetch(existingDescriptor)) ?? []
        let existingUUIDs = Set(existing.compactMap { $0.healthKitUUID })

        var changed = false
        for hkEntry in hkEntries where !existingUUIDs.contains(hkEntry.uuid) {
            let entry = IntakeEntry(
                date: hkEntry.date,
                amountMl: hkEntry.amountMl,
                beverageType: .water,
                healthKitUUID: hkEntry.uuid
            )
            context.insert(entry)
            changed = true
        }
        if changed { try? context.save() }
    }
}
