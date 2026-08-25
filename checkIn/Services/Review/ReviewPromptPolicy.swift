import Foundation

protocol ReviewPromptPolicy: Sendable {
    /// Records a successful manual check-in and atomically claims a review request when eligible.
    func recordSuccessfulManualCheckIn(
        completedDailyGoal: Bool,
        habitCreatedDates: [Date],
        now: Date,
        appVersion: String?
    ) -> Bool
}

struct UserDefaultsReviewPromptPolicy: ReviewPromptPolicy, @unchecked Sendable {
    private enum Key {
        static let successfulManualCheckIns = "review.successfulManualCheckIns.v1"
        static let lastRequestedVersion = "review.lastRequestedVersion.v1"
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let minimumCheckIns: Int
    private let minimumUsageDays: Int

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .autoupdatingCurrent,
        minimumCheckIns: Int = 10,
        minimumUsageDays: Int = 7
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.minimumCheckIns = minimumCheckIns
        self.minimumUsageDays = minimumUsageDays
    }

    func recordSuccessfulManualCheckIn(
        completedDailyGoal: Bool,
        habitCreatedDates: [Date],
        now: Date,
        appVersion: String?
    ) -> Bool {
        let checkInCount = defaults.integer(forKey: Key.successfulManualCheckIns) + 1
        defaults.set(checkInCount, forKey: Key.successfulManualCheckIns)

        guard completedDailyGoal,
              checkInCount >= minimumCheckIns,
              let version = appVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty,
              defaults.string(forKey: Key.lastRequestedVersion) != version,
              let firstHabitDate = habitCreatedDates.min()
        else { return false }

        let firstDay = calendar.startOfDay(for: firstHabitDate)
        let currentDay = calendar.startOfDay(for: now)
        guard currentDay >= firstDay,
              let elapsedDays = calendar.dateComponents([.day], from: firstDay, to: currentDay).day,
              elapsedDays >= minimumUsageDays
        else { return false }

        // Claim this version before the UI asks StoreKit so repeated check-ins cannot enqueue duplicates.
        defaults.set(version, forKey: Key.lastRequestedVersion)
        return true
    }
}

final class InMemoryReviewPromptPolicy: ReviewPromptPolicy, @unchecked Sendable {
    private let lock = NSLock()
    private var successfulManualCheckIns: Int
    private var lastRequestedVersion: String?
    private let calendar: Calendar
    private let minimumCheckIns: Int
    private let minimumUsageDays: Int

    init(
        successfulManualCheckIns: Int = 0,
        lastRequestedVersion: String? = nil,
        calendar: Calendar = .autoupdatingCurrent,
        minimumCheckIns: Int = 10,
        minimumUsageDays: Int = 7
    ) {
        self.successfulManualCheckIns = successfulManualCheckIns
        self.lastRequestedVersion = lastRequestedVersion
        self.calendar = calendar
        self.minimumCheckIns = minimumCheckIns
        self.minimumUsageDays = minimumUsageDays
    }

    func recordSuccessfulManualCheckIn(
        completedDailyGoal: Bool,
        habitCreatedDates: [Date],
        now: Date,
        appVersion: String?
    ) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        successfulManualCheckIns += 1
        guard completedDailyGoal,
              successfulManualCheckIns >= minimumCheckIns,
              let version = appVersion?.trimmingCharacters(in: .whitespacesAndNewlines),
              !version.isEmpty,
              lastRequestedVersion != version,
              let firstHabitDate = habitCreatedDates.min()
        else { return false }

        let firstDay = calendar.startOfDay(for: firstHabitDate)
        let currentDay = calendar.startOfDay(for: now)
        guard currentDay >= firstDay,
              let elapsedDays = calendar.dateComponents([.day], from: firstDay, to: currentDay).day,
              elapsedDays >= minimumUsageDays
        else { return false }

        lastRequestedVersion = version
        return true
    }
}
