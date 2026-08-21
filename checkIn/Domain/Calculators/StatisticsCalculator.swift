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
        let daily: [DailyStatistic] = days(
            from: requestedInterval.start,
            through: lastIncludedDay,
            tasks: tasks,
            totals: totals,
            calendar: calendar
        )
        let chartRange = chartRange(
            period: period,
            interval: requestedInterval,
            lastIncludedDay: lastIncludedDay,
            calendar: calendar
        )
        let chartDaily = days(
            from: chartRange.start,
            through: lastIncludedDay,
            tasks: tasks,
            totals: totals,
            calendar: calendar
        )

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
            daily: daily,
            chartDaily: chartDaily
        )
    }

    private func days(
        from start: Date,
        through end: Date,
        tasks: [TaskDTO],
        totals: [UUID: [String: Int]],
        calendar: Calendar
    ) -> [DailyStatistic] {
        var daily: [DailyStatistic] = []
        var cursor = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        guard cursor <= last else { return [] }

        for _ in 0..<400 where cursor <= last {
            daily.append(dayStatistic(on: cursor, tasks: tasks, totals: totals, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return daily
    }

    private func dayStatistic(
        on date: Date,
        tasks: [TaskDTO],
        totals: [UUID: [String: Int]],
        calendar: Calendar
    ) -> DailyStatistic {
        let key = DayKey(date: date, calendar: calendar).rawValue
        let planned = tasks.filter {
            schedule.isScheduled($0, on: date, calendar: calendar)
        }
        let completed = planned.reduce(into: 0) { count, task in
            let target = schedule.dailyTarget(for: task, on: date, calendar: calendar)
            if totals[task.id]?[key, default: 0] ?? 0 >= target { count += 1 }
        }
        let progressed = planned.reduce(into: 0) { count, task in
            if totals[task.id]?[key, default: 0] ?? 0 > 0 { count += 1 }
        }
        return DailyStatistic(
            dayKey: key,
            date: date,
            plannedTaskCount: planned.count,
            completedTaskCount: completed,
            progressedTaskCount: progressed
        )
    }

    private func chartRange(
        period: StatisticsPeriod,
        interval: DateInterval,
        lastIncludedDay: Date,
        calendar: Calendar
    ) -> DateInterval {
        let dayAfterLast = calendar.date(byAdding: .day, value: 1, to: lastIncludedDay) ?? lastIncludedDay
        let start: Date
        switch period {
        case .week:
            start = calendar.date(byAdding: .day, value: -6, to: lastIncludedDay) ?? interval.start
        case .month:
            let monthLength = calendar.range(of: .day, in: .month, for: interval.start)?.count ?? 30
            start = calendar.date(byAdding: .day, value: -(monthLength - 1), to: lastIncludedDay)
                ?? interval.start
        case .year:
            if let monthStart = calendar.dateInterval(of: .month, for: lastIncludedDay)?.start,
               let twelveMonthsAgo = calendar.date(byAdding: .month, value: -11, to: monthStart) {
                start = twelveMonthsAgo
            } else {
                start = interval.start
            }
        }
        return DateInterval(start: start, end: dayAfterLast)
    }

    private func eventTotals(_ checkIns: [CheckInDTO]) -> [UUID: [String: Int]] {
        var result: [UUID: [String: Int]] = [:]
        for event in checkIns {
            result[event.taskID, default: [:]][event.dayKey, default: 0] += event.value
        }
        return result
    }
}
