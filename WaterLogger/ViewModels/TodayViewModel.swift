import Foundation
import SwiftData
import UserNotifications
import Observation

@Observable
final class TodayViewModel {
    private(set) var entries: [IntakeEntry] = []
    private(set) var settings: AppSettings = AppSettings()
    private(set) var nextReminderDate: Date?

    var totalEffectiveMl: Double {
        entries.reduce(0) { $0 + $1.effectiveMl }
    }

    var progress: Double {
        guard settings.dailyGoalMl > 0 else { return 0 }
        return min(totalEffectiveMl / settings.dailyGoalMl, 1.0)
    }

    var remainingMl: Double {
        max(settings.dailyGoalMl - totalEffectiveMl, 0)
    }

    // MARK: - Load

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

    func logIntake(amountMl: Double, beverageType: BeverageType, context: ModelContext) async {
        let entry = IntakeEntry(amountMl: amountMl, beverageType: beverageType)
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
