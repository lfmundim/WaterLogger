import Foundation
import SwiftData
import UserNotifications
import Observation

/// View model for `TodayView` — drives the progress ring, entry list, and reminder display.
///
/// Marked with `@Observable` (the iOS 17+ macro), so SwiftUI automatically tracks
/// which properties a view reads and only re-renders when those specific properties change.
/// This is the modern replacement for `ObservableObject` + `@Published`.
@Observable
final class TodayViewModel {
    /// All intake entries logged today, sorted newest-first.
    private(set) var entries: [IntakeEntry] = []
    /// The user's current settings (goal, window, presets).
    private(set) var settings: AppSettings = AppSettings()
    /// The scheduled fire date of the next reminder, or `nil` if none is pending.
    private(set) var nextReminderDate: Date?

    /// Sum of `effectiveMl` across all of today's entries.
    ///
    /// `reduce(0) { $0 + $1.effectiveMl }` starts an accumulator at 0 and adds
    /// each entry's effective ml one by one — the Swift equivalent of `Array.sum()`.
    var totalEffectiveMl: Double {
        entries.reduce(0) { $0 + $1.effectiveMl }
    }

    /// Fraction of the daily goal completed, clamped to `[0, 1]`.
    ///
    /// Used directly as the progress value for the ring in `TodayView`.
    var progress: Double {
        guard settings.dailyGoalMl > 0 else { return 0 }
        return min(totalEffectiveMl / settings.dailyGoalMl, 1.0)
    }

    /// Millilitres still needed to reach the daily goal (never negative).
    var remainingMl: Double {
        max(settings.dailyGoalMl - totalEffectiveMl, 0)
    }

    // MARK: - Load

    /// Loads today's entries and settings from SwiftData, syncs with HealthKit,
    /// and schedules the next reminder.
    ///
    /// Call this from `TodayView.task {}` so it runs every time the view appears.
    /// `ModelContext` is passed in rather than stored on the view model because
    /// SwiftData contexts are not sendable across actor boundaries.
    ///
    /// - Parameter context: The SwiftData context provided by `@Environment(\.modelContext)`.
    func load(context: ModelContext) async {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let descriptor = FetchDescriptor<IntakeEntry>(
            predicate: #Predicate { $0.date >= startOfDay },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        entries = (try? context.fetch(descriptor)) ?? []

        let settingsDescriptor = FetchDescriptor<AppSettings>()
        if let existing = (try? context.fetch(settingsDescriptor))?.first {
            settings = existing
        } else {
            let newSettings = AppSettings()
            context.insert(newSettings)
            try? context.save()
            settings = newSettings
        }

        await syncHealthKit(context: context)
        await scheduleNextReminder()
    }

    // MARK: - Log intake

    /// Persists a new intake entry to SwiftData and HealthKit, then reschedules the reminder.
    ///
    /// The entry is inserted at the top of `entries` immediately so the UI updates
    /// before the async HealthKit write completes.
    ///
    /// - Parameters:
    ///   - amountMl: Raw volume entered by the user in millilitres.
    ///   - beverageType: The type of drink (determines `effectiveMl`).
    ///   - context: The SwiftData context used to persist the entry.
    func logIntake(date: Date, amountMl: Double, beverageType: BeverageType, context: ModelContext) async {
        let entry = IntakeEntry(date: date, amountMl: amountMl, beverageType: beverageType)
        context.insert(entry)
        entries.insert(entry, at: 0)

        // Write to HealthKit and store the returned UUID for future sync
        await HealthKitService.shared.requestAuthorizationIfNeeded()
        if let hkUUID = await HealthKitService.shared.saveEntry(entry) {
            entry.healthKitUUID = hkUUID
        }
        try? context.save()

        await scheduleNextReminder()
    }

    // MARK: - Delete intake

    /// Removes an entry from SwiftData and HealthKit, then reschedules the reminder.
    ///
    /// - Parameters:
    ///   - entry: The entry to delete.
    ///   - context: The SwiftData context used to persist the deletion.
    func deleteEntry(_ entry: IntakeEntry, context: ModelContext) async {
        if let hkUUID = entry.healthKitUUID {
            await HealthKitService.shared.deleteEntry(uuid: hkUUID)
        }
        context.delete(entry)
        entries.removeAll { $0.persistentModelID == entry.persistentModelID }
        try? context.save()
        await scheduleNextReminder()
    }

    // MARK: - Private

    /// Fetches today's HealthKit water samples and inserts any that are not already
    /// in the local SwiftData store (e.g. entries from Apple Watch or other apps).
    ///
    /// Deduplication is done by comparing `healthKitUUID` values — if the UUID is
    /// already present in `entries`, the sample is skipped.
    ///
    /// - Parameter context: The SwiftData context used to insert new entries.
    private func syncHealthKit(context: ModelContext) async {
        let hkEntries = await HealthKitService.shared.fetchTodayEntries()
        guard !hkEntries.isEmpty else { return }

        let existingUUIDs = Set(entries.compactMap { $0.healthKitUUID })
        var changed = false
        for hkEntry in hkEntries where !existingUUIDs.contains(hkEntry.uuid) {
            let entry = IntakeEntry(
                date: hkEntry.date,
                amountMl: hkEntry.amountMl,
                beverageType: .water,
                healthKitUUID: hkEntry.uuid
            )
            context.insert(entry)
            entries.append(entry)
            changed = true
        }
        if changed {
            try? context.save()
            entries.sort { $0.date > $1.date }
        }
    }

    /// Asks `NotificationService` to schedule (or cancel) the next reminder, then
    /// reads back the resulting pending trigger date to update `nextReminderDate`.
    ///
    /// `nextReminderDate` is displayed in `TodayView` as "next reminder at HH:mm".
    /// It is set to `nil` when no reminder is pending (goal met or window closed).
    private func scheduleNextReminder() async {
        await NotificationService.shared.requestAuthorizationIfNeeded()
        await NotificationService.shared.scheduleNext(
            totalEffectiveMlToday: totalEffectiveMl,
            goalMl: settings.dailyGoalMl,
            windowStartMinutes: settings.windowStartMinutes,
            windowEndMinutes: settings.windowEndMinutes
        )

        // Update the displayed next reminder time
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        if let trigger = pending.first?.trigger as? UNCalendarNotificationTrigger {
            nextReminderDate = trigger.nextTriggerDate()
        } else {
            nextReminderDate = nil
        }
    }
}
