import Foundation
import SwiftData
import Observation

struct DaySummary: Identifiable {
    let date: Date
    let effectiveMl: Double
    let entries: [IntakeEntry]

    var id: Date { date }
}

@Observable
final class HistoryViewModel {
    private(set) var daySummaries: [DaySummary] = []
    private(set) var goalMl: Double = 2000
    var selectedDate: Date?

    var selectedDayEntries: [IntakeEntry] {
        guard let date = selectedDate,
              let summary = daySummaries.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        else { return [] }
        return summary.entries
    }

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
