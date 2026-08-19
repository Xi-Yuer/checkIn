import Foundation

struct TaskScheduleService: Sendable {
    func plan(
        for task: TaskDTO,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TaskPlanRevision {
        let dayKey = DayKey(date: date, calendar: calendar).rawValue
        if let revision = task.planRevisions
            .filter({ $0.effectiveDayKey <= dayKey })
            .max(by: { $0.effectiveDayKey < $1.effectiveDayKey }) {
            return revision
        }

        return TaskPlanRevision(
            effectiveDayKey: task.createdDayKey ?? DayKey(date: task.createdAt, calendar: calendar).rawValue,
            schedule: task.schedule,
            dailyTarget: task.dailyTarget,
            startDayKey: task.startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            endDayKey: task.endDate.map { DayKey(date: $0, calendar: calendar).rawValue }
        )
    }

    func dailyTarget(
        for task: TaskDTO,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        max(1, plan(for: task, on: date, calendar: calendar).dailyTarget)
    }

    func isPaused(
        _ task: TaskDTO,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let dayKey = DayKey(date: date, calendar: calendar).rawValue
        if task.pauseIntervals.contains(where: { $0.contains(dayKey) }) {
            return true
        }
        // Legacy V2 rows have no interval data. Treat their last update day as
        // the start of the current pause instead of erasing all prior history.
        return task.isArchived && task.pauseIntervals.isEmpty &&
            dayKey >= DayKey(date: task.updatedAt, calendar: calendar).rawValue
    }

    func isScheduled(
        _ task: TaskDTO,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        excludingPaused: Bool = true
    ) -> Bool {
        if excludingPaused, isPaused(task, on: date, calendar: calendar) { return false }

        let day = calendar.startOfDay(for: date)
        let dayKey = DayKey(date: day, calendar: calendar).rawValue
        let revision = plan(for: task, on: day, calendar: calendar)
        let firstDayKey = revision.startDayKey ?? task.createdDayKey ??
            DayKey(date: task.createdAt, calendar: calendar).rawValue
        if dayKey < firstDayKey { return false }
        if let endDayKey = revision.endDayKey, dayKey > endDayKey { return false }

        let weekdayValue = calendar.component(.weekday, from: day)
        guard let weekday = Weekday(rawValue: Int16(weekdayValue)) else { return false }
        return revision.schedule.includes(weekday)
    }

    func nextScheduledDate(
        for task: TaskDTO,
        onOrAfter date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        excludingPaused: Bool = true
    ) -> Date? {
        var candidate = calendar.startOfDay(for: date)
        for _ in 0..<14 {
            if isScheduled(task, on: candidate, calendar: calendar, excludingPaused: excludingPaused) {
                return candidate
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = next
        }
        return nil
    }

    func previousScheduledDate(
        for task: TaskDTO,
        before date: Date,
        calendar: Calendar = .autoupdatingCurrent,
        excludingPaused: Bool = false
    ) -> Date? {
        var candidate = calendar.startOfDay(for: date)
        for _ in 0..<14 {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: candidate) else { return nil }
            candidate = previous
            if isScheduled(task, on: candidate, calendar: calendar, excludingPaused: excludingPaused) {
                return candidate
            }
        }
        return nil
    }
}
