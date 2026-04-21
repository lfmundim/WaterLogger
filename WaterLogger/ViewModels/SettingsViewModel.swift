import Foundation
import SwiftUI
import SwiftData
import Observation

/// View model for `SettingsView` — exposes editable copies of the user's settings.
///
/// The view binds directly to properties on this view model (e.g. `$vm.dailyGoalMl`).
/// Changes are only persisted to SwiftData when `save(context:)` is called, letting
/// the user cancel without unintended side-effects.
@Observable
final class SettingsViewModel {
    /// The user's daily hydration goal in ml, bound to the stepper/text field.
    var dailyGoalMl: Double = 2000
    /// The start of the active reminder window as a `Date` (only H:mm is used).
    var windowStart: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
    /// The end of the active reminder window as a `Date` (only H:mm is used).
    var windowEnd: Date   = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: .now) ?? .now
    /// The current list of quick-select container presets.
    var containerPresets: [ContainerPreset] = ContainerPreset.defaults

    /// A reference to the persisted `AppSettings` record, kept for writing back on save.
    private var settingsModel: AppSettings?

    /// Loads settings from SwiftData into the view model's editable properties.
    ///
    /// If no `AppSettings` record exists (first launch), a new one is created with
    /// defaults and inserted into the context.
    ///
    /// - Parameter context: The SwiftData context provided by `@Environment(\.modelContext)`.
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

    /// Writes the current view model state back to the `AppSettings` SwiftData record.
    ///
    /// The `windowStart`/`windowEnd` `Date` values are converted to minutes-since-midnight
    /// so they can be stored as plain `Int`s in `AppSettings` (avoiding timezone issues
    /// with storing a full `Date`).
    ///
    /// - Parameter context: The SwiftData context used to persist the changes.
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

    /// Appends a new container preset to the list.
    ///
    /// The change is reflected immediately in the UI but is not persisted until
    /// `save(context:)` is called.
    ///
    /// - Parameters:
    ///   - name: Display label for the preset button (e.g. "Travel mug").
    ///   - amountMl: Volume in ml (e.g. 400).
    func addPreset(name: String, amountMl: Double) {
        containerPresets.append(ContainerPreset(name: name, amountMl: amountMl))
    }

    /// Removes one or more presets at the given index set.
    ///
    /// Designed to be passed directly to `List.onDelete`, which provides an `IndexSet`
    /// of the rows the user swiped to delete.
    ///
    /// - Parameter offsets: The positions to remove from `containerPresets`.
    func deletePresets(at offsets: IndexSet) {
        containerPresets.remove(atOffsets: offsets)
    }
}
