import Foundation

struct BadgeCalculator: Sendable {
    private let streakCalculator = StreakCalculator()

    func earnedBadges(
        tasks: [TaskDTO],
        checkIns: [CheckInDTO],
        through date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [EarnedBadge] {
        let completionDatesByTask = tasks.reduce(into: [UUID: [Date]]()) { result, task in
            result[task.id] = streakCalculator.completionDates(
                task: task,
                checkIns: checkIns,
                calendar: calendar
            ).filter {
                DayKey(date: $0, calendar: calendar) <= DayKey(date: date, calendar: calendar)
            }
        }
        let allCompletionDates = completionDatesByTask.values.flatMap { $0 }.sorted()
        guard let first = allCompletionDates.first else { return [] }

        var result = [EarnedBadge(kind: .firstCompletion, earnedAt: first)]
        appendTotalBadge(.total10, threshold: 10, dates: allCompletionDates, into: &result)
        appendTotalBadge(.total50, threshold: 50, dates: allCompletionDates, into: &result)
        appendTotalBadge(.total100, threshold: 100, dates: allCompletionDates, into: &result)

        for (kind, threshold) in [(BadgeKind.streak3, 3), (.streak7, 7), (.streak30, 30)] {
            let earnedDates = tasks.compactMap { task -> Date? in
                streakAchievementDate(
                    task: task,
                    completionDates: completionDatesByTask[task.id] ?? [],
                    threshold: threshold,
                    calendar: calendar
                )
            }
            if let earnedAt = earnedDates.min() {
                result.append(EarnedBadge(kind: kind, earnedAt: earnedAt))
            }
        }

        return result.sorted { $0.earnedAt < $1.earnedAt }
    }

    private func appendTotalBadge(
        _ kind: BadgeKind,
        threshold: Int,
        dates: [Date],
        into result: inout [EarnedBadge]
    ) {
        guard dates.count >= threshold else { return }
        result.append(EarnedBadge(kind: kind, earnedAt: dates[threshold - 1]))
    }

    private func streakAchievementDate(
        task: TaskDTO,
        completionDates: [Date],
        threshold: Int,
        calendar: Calendar
    ) -> Date? {
        let completed = Set(completionDates.map { DayKey(date: $0, calendar: calendar).rawValue })
        var streak = 0
        let firstDayKey = task.createdDayKey ?? DayKey(date: task.createdAt, calendar: calendar).rawValue
        var cursor = DayKey(rawValue: firstDayKey).date(calendar: calendar) ?? calendar.startOfDay(for: task.createdAt)
        guard let last = completionDates.last else { return nil }

        for _ in 0..<36_600 where cursor <= last {
            if TaskScheduleService().isScheduled(task, on: cursor, calendar: calendar) {
                if completed.contains(DayKey(date: cursor, calendar: calendar).rawValue) {
                    streak += 1
                    if streak == threshold { return cursor }
                } else {
                    streak = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return nil
    }
}
