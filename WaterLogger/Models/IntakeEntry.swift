import Foundation
import SwiftData

@Model
final class IntakeEntry {
    var date: Date
    var amountMl: Double
    var beverageType: BeverageType
    /// UUID of the corresponding HKQuantitySample for upsert deduplication.
    var healthKitUUID: UUID?

    init(date: Date = .now, amountMl: Double, beverageType: BeverageType, healthKitUUID: UUID? = nil) {
        self.date = date
        self.amountMl = amountMl
        self.beverageType = beverageType
        self.healthKitUUID = healthKitUUID
    }

    var effectiveMl: Double {
        amountMl * beverageType.hydrationCoefficient
    }
}
