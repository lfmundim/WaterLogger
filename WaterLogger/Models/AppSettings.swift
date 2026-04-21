import Foundation
import SwiftData

/// Persistent settings for the app, stored via SwiftData.
///
/// There is a single `AppSettings` record in the database. If none exists,
/// `TodayViewModel` (or `SettingsViewModel`) will create one with defaults.
@Model
final class AppSettings {
    /// The user's daily hydration goal in millilitres (default: 2000 ml).
    var dailyGoalMl: Double
    /// Minutes from midnight for window start (e.g. 480 = 08:00).
    var windowStartMinutes: Int
    /// Minutes from midnight for window end (e.g. 1320 = 22:00).
    var windowEndMinutes: Int
    /// User-defined container presets shown in the log-entry sheet.
    var containerPresets: [ContainerPreset]

    /// Creates a new settings record.
    ///
    /// - Parameters:
    ///   - dailyGoalMl: Target intake in ml. Defaults to 2000.
    ///   - windowStartMinutes: Minutes after midnight when the reminder window opens. Defaults to 480 (08:00).
    ///   - windowEndMinutes: Minutes after midnight when the reminder window closes. Defaults to 1320 (22:00).
    ///   - containerPresets: Quick-select amounts shown when logging intake.
    init(
        dailyGoalMl: Double = 2000,
        windowStartMinutes: Int = 8 * 60,
        windowEndMinutes: Int = 22 * 60,
        containerPresets: [ContainerPreset] = ContainerPreset.defaults
    ) {
        self.dailyGoalMl = dailyGoalMl
        self.windowStartMinutes = windowStartMinutes
        self.windowEndMinutes = windowEndMinutes
        self.containerPresets = containerPresets
    }

    /// A `Date` representing the window start time on the current calendar day.
    ///
    /// Derived from `windowStartMinutes` by splitting into hours and minutes and
    /// anchoring to today's date via `Calendar.current`.
    var windowStartDate: Date {
        Calendar.current.date(
            bySettingHour: windowStartMinutes / 60,
            minute: windowStartMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    /// A `Date` representing the window end time on the current calendar day.
    ///
    /// Derived from `windowEndMinutes` using the same approach as `windowStartDate`.
    var windowEndDate: Date {
        Calendar.current.date(
            bySettingHour: windowEndMinutes / 60,
            minute: windowEndMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    /// The total length of the reminder window in fractional hours.
    ///
    /// Used by `NotificationService` when computing adaptive reminder intervals.
    var totalWindowHours: Double {
        Double(windowEndMinutes - windowStartMinutes) / 60.0
    }
}

/// A named container size the user can quickly tap when logging intake.
///
/// `ContainerPreset` is stored as a `Codable` array inside `AppSettings`,
/// so it does not need its own SwiftData `@Model`.
struct ContainerPreset: Codable, Equatable {
    /// Human-readable label shown on the preset button (e.g. "Glass").
    var name: String
    /// Volume of the container in millilitres (e.g. 250).
    var amountMl: Double

    /// The four built-in presets shown to new users before any customisation.
    static let defaults: [ContainerPreset] = [
        ContainerPreset(name: "Small cup", amountMl: 150),
        ContainerPreset(name: "Glass", amountMl: 250),
        ContainerPreset(name: "Large glass", amountMl: 350),
        ContainerPreset(name: "Bottle", amountMl: 500),
    ]
}
