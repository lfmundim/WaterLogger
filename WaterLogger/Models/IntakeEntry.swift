import Foundation
import SwiftData

/// A single logged drink, persisted by SwiftData.
///
/// Each entry records what was consumed, how much, and when. The optional
/// `healthKitUUID` links the entry to its corresponding `HKQuantitySample`
/// so duplicates can be detected during HealthKit sync.
@Model
final class IntakeEntry {
    /// When the drink was consumed.
    var date: Date
    /// The raw volume logged by the user, in millilitres.
    var amountMl: Double
    /// The type of drink (affects the `effectiveMl` calculation).
    var beverageType: BeverageType
    /// UUID of the corresponding HKQuantitySample for upsert deduplication.
    var healthKitUUID: UUID?

    /// Creates a new intake entry.
    ///
    /// - Parameters:
    ///   - date: Timestamp of consumption. Defaults to now.
    ///   - amountMl: Raw volume in ml as entered by the user.
    ///   - beverageType: Category of the drink.
    ///   - healthKitUUID: The UUID of the matching `HKQuantitySample`, if one was written.
    init(date: Date = .now, amountMl: Double, beverageType: BeverageType, healthKitUUID: UUID? = nil) {
        self.date = date
        self.amountMl = amountMl
        self.beverageType = beverageType
        self.healthKitUUID = healthKitUUID
    }

    /// The hydration-adjusted volume in millilitres.
    ///
    /// Computed as `amountMl × beverageType.hydrationCoefficient`.
    /// This is the value that counts toward the daily goal, not the raw `amountMl`.
    var effectiveMl: Double {
        amountMl * beverageType.hydrationCoefficient
    }
}
