import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    var dailyGoalMl: Double = 2000
    var windowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    var windowEnd: Date   = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now
    var containerPresets: [ContainerPreset] = ContainerPreset.defaults

    private var settingsModel: AppSettings?

    func load(context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>()
        let existing = (try? context.fetch(descriptor))?.first
        if let existing {
            settingsModel = existing
            dailyGoalMl = existing.dailyGoalMl
            windowStart = existing.windowStartDate
            windowEnd   = existing.windowEndDate
            containerPresets = existing.containerPresets
        } else {
            let newSettings = AppSettings()
            context.insert(newSettings)
            try? context.save()
            settingsModel = newSettings
        }
    }

    func save(context: ModelContext) {
        guard let model = settingsModel else { return }
        model.dailyGoalMl = dailyGoalMl

        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.hour, .minute], from: windowStart)
        let endComps   = calendar.dateComponents([.hour, .minute], from: windowEnd)
        model.windowStartMinutes = (startComps.hour ?? 8) * 60 + (startComps.minute ?? 0)
        model.windowEndMinutes   = (endComps.hour ?? 22) * 60 + (endComps.minute ?? 0)
        model.containerPresets = containerPresets
        try? context.save()
    }

    func addPreset(name: String, amountMl: Double) {
        containerPresets.append(ContainerPreset(name: name, amountMl: amountMl))
    }

    func deletePresets(at offsets: IndexSet) {
        containerPresets.remove(atOffsets: offsets)
    }
}
