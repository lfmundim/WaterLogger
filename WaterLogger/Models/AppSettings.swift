import Foundation
import SwiftData

@Model
final class AppSettings {
    var dailyGoalMl: Double
    /// Minutes from midnight for window start (e.g. 480 = 08:00).
    var windowStartMinutes: Int
    /// Minutes from midnight for window end (e.g. 1320 = 22:00).
    var windowEndMinutes: Int
    var containerPresets: [ContainerPreset]

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

    var windowStartDate: Date {
        Calendar.current.date(
            bySettingHour: windowStartMinutes / 60,
            minute: windowStartMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    var windowEndDate: Date {
        Calendar.current.date(
            bySettingHour: windowEndMinutes / 60,
            minute: windowEndMinutes % 60,
            second: 0,
            of: .now
        ) ?? .now
    }

    var totalWindowHours: Double {
        Double(windowEndMinutes - windowStartMinutes) / 60.0
    }
}

struct ContainerPreset: Codable, Equatable {
    var name: String
    var amountMl: Double

    static let defaults: [ContainerPreset] = [
        ContainerPreset(name: "Small cup", amountMl: 150),
        ContainerPreset(name: "Glass", amountMl: 250),
        ContainerPreset(name: "Large glass", amountMl: 350),
        ContainerPreset(name: "Bottle", amountMl: 500),
    ]
}
