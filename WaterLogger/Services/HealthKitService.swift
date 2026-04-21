import Foundation
import HealthKit
import SwiftData

/// An `actor` that owns all interaction with HealthKit.
///
/// Using `actor` guarantees that concurrent calls from multiple async contexts
/// (e.g. app foreground sync + a log-intake action) never race on the underlying
/// `HKHealthStore`. All methods are `async` and safe to call from any Swift
/// concurrency context.
///
/// The app can function without HealthKit — every method guards on
/// `HKHealthStore.isHealthDataAvailable()` and returns gracefully when
/// HealthKit is unavailable or authorisation has been denied.
actor HealthKitService {
    /// The shared singleton. Use this everywhere instead of creating new instances.
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    /// Returns `true` when HealthKit is supported on the current device.
    ///
    /// HealthKit is unavailable on iPad and in simulators that have not been
    /// configured with health data.
    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    /// Requests HealthKit read/write authorisation for dietary water, if not already granted.
    ///
    /// This is called lazily (on the first log action) rather than at launch,
    /// as required by the App Store guidelines. If the user previously denied
    /// access, the system will not show the prompt again; the method returns
    /// silently and the app continues without HealthKit.
    func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        let share: Set<HKSampleType> = [waterType]
        let read: Set<HKObjectType> = [waterType]
        try? await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Write

    /// Writes a new `HKQuantitySample` for a logged intake entry.
    ///
    /// - Parameter entry: The `IntakeEntry` whose `amountMl` and `date` are written to HealthKit.
    /// - Returns: The UUID assigned to the new `HKQuantitySample`, or `nil` if
    ///   HealthKit is unavailable or the write fails. Store this UUID in
    ///   `IntakeEntry.healthKitUUID` to enable future deletion and deduplication.
    func saveEntry(_ entry: IntakeEntry) async -> UUID? {
        guard isAvailable else { return nil }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: entry.amountMl)
        let sample = HKQuantitySample(
            type: waterType,
            quantity: quantity,
            start: entry.date,
            end: entry.date
        )
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Deletes the `HKQuantitySample` identified by the given UUID from HealthKit.
    ///
    /// Called when the user swipes to delete an entry in `TodayView`. Failure is
    /// silently ignored — the entry is removed from SwiftData regardless.
    ///
    /// - Parameter uuid: The `healthKitUUID` stored on the `IntakeEntry` to delete.
    func deleteEntry(uuid: UUID) async {
        guard isAvailable else { return }
        let predicate = HKQuery.predicateForObjects(with: [uuid])
        do {
            let samples = try await querySamples(predicate: predicate, limit: 1)
            if let sample = samples.first {
                try await store.delete(sample)
            }
        } catch {
            // Silently ignore — HealthKit deletion failure is non-critical
        }
    }

    // MARK: - Read

    /// Fetch all dietaryWater samples for today and return them as (uuid, amountMl, date) tuples.
    ///
    /// Used during app foreground sync to import entries created by other apps
    /// (e.g. Apple Watch) that are not yet in the local SwiftData store.
    ///
    /// - Returns: An array of lightweight tuples — one per `HKQuantitySample`
    ///   written to HealthKit today. Returns an empty array if HealthKit is
    ///   unavailable or the query fails.
    func fetchTodayEntries() async -> [(uuid: UUID, amountMl: Double, date: Date)] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: .now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: .now)
        do {
            let samples = try await querySamples(predicate: predicate, limit: HKObjectQueryNoLimit)
            return samples.map { sample in
                let amount = sample.quantity.doubleValue(for: .literUnit(with: .milli))
                return (uuid: sample.uuid, amountMl: amount, date: sample.startDate)
            }
        } catch {
            return []
        }
    }

    // MARK: - Private helpers

    /// Executes an `HKSampleQuery` and bridges the callback-based API to Swift async/await.
    ///
    /// `HKSampleQuery` uses a completion handler, which is not natively async.
    /// `withCheckedThrowingContinuation` wraps it so callers can use `try await`
    /// instead of nesting callbacks. The continuation is resumed exactly once —
    /// either with the results or by throwing the HealthKit error.
    ///
    /// - Parameters:
    ///   - predicate: An `NSPredicate` that filters which samples are returned.
    ///   - limit: Maximum number of results (`HKObjectQueryNoLimit` for unlimited).
    /// - Returns: Matching `HKQuantitySample` objects sorted by ascending start date.
    /// - Throws: Any `Error` returned by `HKHealthStore`.
    private func querySamples(predicate: NSPredicate, limit: Int) async throws -> [HKQuantitySample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: waterType,
                predicate: predicate,
                limit: limit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }
}
