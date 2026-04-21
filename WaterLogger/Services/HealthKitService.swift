import Foundation
import HealthKit
import SwiftData

actor HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    func requestAuthorizationIfNeeded() async {
        guard isAvailable else { return }
        let share: Set<HKSampleType> = [waterType]
        let read: Set<HKObjectType> = [waterType]
        try? await store.requestAuthorization(toShare: share, read: read)
    }

    // MARK: - Write

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
