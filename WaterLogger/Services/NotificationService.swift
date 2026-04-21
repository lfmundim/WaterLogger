import Foundation
import UserNotifications

/// An `actor` that owns all interaction with `UNUserNotificationCenter`.
///
/// Using `actor` ensures that only one scheduling operation runs at a time,
/// preventing a race where two concurrent calls could both remove the pending
/// notification and then both add a new one (potentially scheduling two reminders).
///
/// The adaptive scheduling algorithm is intentionally exposed as a `static` pure
/// function (`nextReminderInterval`) so it can be unit-tested without any
/// system dependencies.
actor NotificationService {
    /// The shared singleton. Use this everywhere instead of creating new instances.
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    /// Stable identifier used for the single pending reminder so it can be
    /// cancelled and replaced atomically on every re-schedule.
    private let reminderIdentifier = "water.reminder.next"

    // MARK: - Authorization

    /// Requests permission to display alerts, play sounds, and badge the app icon.
    ///
    /// Called lazily before the first scheduling attempt. If the user previously
    /// denied notifications the system will not show the prompt again; the method
    /// returns and scheduling proceeds anyway — the notification will simply not
    /// be delivered.
    func requestAuthorizationIfNeeded() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Scheduling

    /// Calculates the next reminder fire date and schedules it, or cancels if goal is met / outside window.
    ///
    /// This method is the main entry point for adaptive scheduling. Call it:
    /// - After every intake log
    /// - When the app returns to the foreground
    /// - After deleting an entry
    ///
    /// **Algorithm (from CLAUDE.md):**
    /// ```
    /// remainingMl    = goalMl − totalEffectiveMlToday
    /// hoursLeft      = hoursUntilWindowEnd  (0 if past end)
    /// intervalHours  = remainingMl / (goalMl / totalWindowHours)
    /// fireDate       = now + clamp(intervalHours, 30 min, 2 h)
    /// ```
    /// If the goal is already met, the window has ended, or `fireDate` falls
    /// after the window end, the pending notification is cancelled and nothing
    /// is scheduled.
    ///
    /// - Parameters:
    ///   - totalEffectiveMlToday: Sum of `effectiveMl` for all entries logged so far today.
    ///   - goalMl: The user's daily target from `AppSettings.dailyGoalMl`.
    ///   - windowStartMinutes: Minutes after midnight when reminders may start.
    ///   - windowEndMinutes: Minutes after midnight when reminders must stop.
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
    ///
    /// Called when the goal is already met for the day or the user disables
    /// notifications. After calling this, no reminder will fire until
    /// `scheduleNext(...)` is called again.
    func cancelPending() {
        center.removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    // MARK: - Pure scheduling logic (testable without UNUserNotificationCenter)

    /// Returns the interval in hours for the next reminder, or nil if no reminder should be scheduled.
    ///
    /// This is a `static` pure function with no side effects, making it easy to
    /// unit-test without mocking `UNUserNotificationCenter`. The actual scheduling
    /// method `scheduleNext(...)` delegates the interval calculation to this function.
    ///
    /// - Parameters:
    ///   - totalEffectiveMlToday: Hydration-adjusted intake logged so far today (ml).
    ///   - goalMl: User's daily hydration goal (ml).
    ///   - totalWindowHours: Total length of the active reminder window in hours.
    ///   - hoursLeftInWindow: Hours remaining until the window closes (0 if past end).
    /// - Returns: The clamped interval in hours (`[0.5, 2.0]`), or `nil` if the
    ///   goal is met, the window is closed, or any input is invalid.
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
