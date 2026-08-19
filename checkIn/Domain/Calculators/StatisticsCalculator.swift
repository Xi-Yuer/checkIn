import Foundation

struct StatisticsCalculator: Sendable {
    private let schedule = TaskScheduleService()
    private let streakCalculator = StreakCalculator()

    func interval(
        for period: StatisticsPeriod,
        anchor: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let component: Calendar.Component
        switch period {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        if let value = calendar.dateInterval(of: component, for: anchor) {
            return value
        }
        let day = calendar.startOfDay(for: anchor)
        return DateInterval(start: day, end: calendar.date(byAdding: .day, value: 1, to: day) ?? day)
    }

    func summary(
        tasks: [TaskDTO],
        checkIns: [CheckInDTO],
        period: StatisticsPeriod,
        anchor: Date,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> StatisticsSummary {
        let requestedInterval = interval(for: period, anchor: anchor, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        let lastIncludedDay = min(
            today,
            calendar.date(byAdding: .day, value: -1, to: requestedInterval.end) ?? requestedInterval.start
        )
        guard requestedInterval.start <= lastIncludedDay else {
            return StatisticsSummary.empty(period: period, date: anchor, calendar: calendar)
        }

        let totals = eventTotals(checkIns)
        var daily: [DailyStatistic] = []
        var cursor = requestedInterval.start

        for _ in 0..<400 where cursor <= lastIncludedDay {
            let key = DayKey(date: cursor, calendar: calendar).rawValue
            let planned = tasks.filter {
                schedule.isScheduled($0, on: cursor, calendar: calendar)
            }
            let completed = planned.reduce(into: 0) { count, task in
                let target = schedule.dailyTarget(for: task, on: cursor, calendar: calendar)
                if totals[task.id]?[key, default: 0] ?? 0 >= target { count += 1 }
            }
            let progressed = planned.reduce(into: 0) { count, task in
                if totals[task.id]?[key, default: 0] ?? 0 > 0 { count += 1 }
            }
            daily.append(
                DailyStatistic(
                    dayKey: key,
                    date: cursor,
                    plannedTaskCount: planned.count,
                    completedTaskCount: completed,
                    progressedTaskCount: progressed
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        let plannedCount = daily.reduce(0) { $0 + $1.plannedTaskCount }
        let completedCount = daily.reduce(0) { $0 + $1.completedTaskCount }
        let streaks = tasks.map {
            (
                streakCalculator.currentStreak(task: $0, checkIns: checkIns, through: now, calendar: calendar),
                streakCalculator.bestStreak(task: $0, checkIns: checkIns, through: now, calendar: calendar)
            )
        }

        return StatisticsSummary(
            period: period,
            interval: requestedInterval,
            plannedTaskDays: plannedCount,
            completedTaskDays: completedCount,
            currentStreak: streaks.map(\.0).max() ?? 0,
            bestStreak: streaks.map(\.1).max() ?? 0,
            daily: daily
        )
    }

    private func eventTotals(_ checkIns: [CheckInDTO]) -> [UUID: [String: Int]] {
        var result: [UUID: [String: Int]] = [:]
        for event in checkIns {
            result[event.taskID, default: [:]][event.dayKey, default: 0] += event.value
        }
        return result
    }
}
