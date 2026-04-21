import Foundation
import UserNotifications

actor NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let reminderIdentifier = "water.reminder.next"

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Scheduling

    /// Calculates the next reminder fire date and schedules it, or cancels if goal is met / outside window.
    func scheduleNext(
        totalEffectiveMlToday: Double,
        goalMl: Double,
        windowStartMinutes: Int,
        windowEndMinutes: Int
    ) async {
        // Always cancel the previous pending reminder first.
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])

        let now = Date.now
        let calendar = Calendar.current
        let todayComponents = calendar.dateComponents([.year, .month, .day], from: now)

        func todayDate(hour: Int, minute: Int) -> Date? {
            var comps = todayComponents
            comps.hour = hour
            comps.minute = minute
            comps.second = 0
            return calendar.date(from: comps)
        }

        guard
            let windowEnd = todayDate(hour: windowEndMinutes / 60, minute: windowEndMinutes % 60)
        else { return }

        let hoursLeft = max(0, windowEnd.timeIntervalSince(now) / 3600)
        let remainingMl = goalMl - totalEffectiveMlToday

        guard hoursLeft > 0, remainingMl > 0 else { return }

        let totalWindowHours = Double(windowEndMinutes - windowStartMinutes) / 60.0
        guard totalWindowHours > 0 else { return }

        // Core formula from CLAUDE.md
        let intervalHours = remainingMl / (goalMl / totalWindowHours)
        // Cap between 30 minutes and 2 hours
        let clampedInterval = min(max(intervalHours, 0.5), 2.0)

        let fireDate = now.addingTimeInterval(clampedInterval * 3600)

        // Never schedule outside the active window
        guard fireDate <= windowEnd else { return }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let remaining = Int(remainingMl.rounded())
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to hydrate!")
        content.body = String(localized: "\(remaining) ml remaining to reach your daily goal.")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }

    /// Cancel the pending reminder without scheduling a new one.
    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    // MARK: - Pure scheduling logic (testable without UNUserNotificationCenter)

    /// Returns the interval in hours for the next reminder, or nil if no reminder should be scheduled.
    static func nextReminderInterval(
        totalEffectiveMlToday: Double,
        goalMl: Double,
        totalWindowHours: Double,
        hoursLeftInWindow: Double
    ) -> Double? {
        guard hoursLeftInWindow > 0, totalEffectiveMlToday < goalMl, goalMl > 0, totalWindowHours > 0 else {
            return nil
        }
        let remainingMl = goalMl - totalEffectiveMlToday
        let intervalHours = remainingMl / (goalMl / totalWindowHours)
        return min(max(intervalHours, 0.5), 2.0)
    }
}
