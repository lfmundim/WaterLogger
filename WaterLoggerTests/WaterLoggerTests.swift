import Testing
@testable import WaterLogger

// MARK: - BeverageType tests

struct BeverageTypeTests {

    @Test func waterHydrationCoefficient() {
        #expect(BeverageType.water.hydrationCoefficient == 1.0)
    }

    @Test func herbalTeaHydrationCoefficient() {
        #expect(BeverageType.herbalTea.hydrationCoefficient == 1.0)
    }

    @Test func juiceHydrationCoefficient() {
        #expect(BeverageType.juice.hydrationCoefficient == 0.9)
    }

    @Test func sodaHydrationCoefficient() {
        #expect(BeverageType.soda.hydrationCoefficient == 0.85)
    }

    @Test func coffeeHydrationCoefficient() {
        #expect(BeverageType.coffee.hydrationCoefficient == 0.8)
    }

    @Test func alcoholHydrationCoefficient() {
        #expect(BeverageType.alcohol.hydrationCoefficient == 0.0)
    }

    @Test func effectiveMlCalculation() {
        let entry = IntakeEntry(amountMl: 250, beverageType: .coffee)
        #expect(entry.effectiveMl == 200.0) // 250 * 0.8
    }

    @Test func alcoholEffectiveMlIsZero() {
        let entry = IntakeEntry(amountMl: 500, beverageType: .alcohol)
        #expect(entry.effectiveMl == 0.0)
    }
}

// MARK: - NotificationService scheduling logic tests

struct NotificationServiceSchedulingTests {

    @Test func noReminderWhenGoalMet() {
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 2000,
            goalMl: 2000,
            totalWindowHours: 14,
            hoursLeftInWindow: 3
        )
        #expect(result == nil)
    }

    @Test func noReminderWhenWindowClosed() {
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 500,
            goalMl: 2000,
            totalWindowHours: 14,
            hoursLeftInWindow: 0
        )
        #expect(result == nil)
    }

    @Test func intervalClampedToMinimum() {
        // Very small remaining amount → interval would be tiny → clamp to 30 min (0.5 h)
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 1990,
            goalMl: 2000,
            totalWindowHours: 14,
            hoursLeftInWindow: 5
        )
        #expect(result == 0.5)
    }

    @Test func intervalClampedToMaximum() {
        // Fresh start, lots of time left → interval would exceed 2 h → clamp to 2 h
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 0,
            goalMl: 2000,
            totalWindowHours: 14,
            hoursLeftInWindow: 14
        )
        // Formula: 2000 / (2000 / 14) = 14 h → clamped to 2 h
        #expect(result == 2.0)
    }

    @Test func normalIntervalCalculation() {
        // 1000 ml remaining, goal 2000, window 14 h → interval = 1000 / (2000/14) = 7 h → clamped to 2 h
        // Use a scenario that produces an unclamped value between 0.5 and 2.0
        // 500 ml remaining, goal 2000, window 4 h → interval = 500 / (2000/4) = 500/500 = 1.0 h
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 1500,
            goalMl: 2000,
            totalWindowHours: 4,
            hoursLeftInWindow: 2
        )
        #expect(result == 1.0)
    }

    @Test func noReminderWhenGoalIsZero() {
        let result = NotificationService.nextReminderInterval(
            totalEffectiveMlToday: 0,
            goalMl: 0,
            totalWindowHours: 14,
            hoursLeftInWindow: 5
        )
        #expect(result == nil)
    }
}
