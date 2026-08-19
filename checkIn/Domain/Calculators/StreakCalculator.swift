import Foundation

struct StreakCalculator: Sendable {
    private let schedule = TaskScheduleService()

    func currentStreak(
        task: TaskDTO,
        checkIns: [CheckInDTO],
        through referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let completedDays = completedDayKeys(task: task, checkIns: checkIns, calendar: calendar)
        let today = calendar.startOfDay(for: referenceDate)
        var cursor = today
        var result = 0
        var firstScheduledDay = true

        for _ in 0..<36_600 {
            let lowerBoundKey = task.createdDayKey ?? DayKey(date: task.createdAt, calendar: calendar).rawValue
            if DayKey(date: cursor, calendar: calendar).rawValue < lowerBoundKey { break }

            if schedule.isScheduled(task, on: cursor, calendar: calendar) {
                let key = DayKey(date: cursor, calendar: calendar).rawValue
                if completedDays.contains(key) {
                    result += 1
                } else if firstScheduledDay && cursor == today {
                    // Today's pending target does not break a streak before the day is over.
                } else {
                    break
                }
                firstScheduledDay = false
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return result
    }

    func bestStreak(
        task: TaskDTO,
        checkIns: [CheckInDTO],
        through referenceDate: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        let completedDays = completedDayKeys(task: task, checkIns: checkIns, calendar: calendar)
        let firstDayKey = task.createdDayKey ?? DayKey(date: task.createdAt, calendar: calendar).rawValue
        var cursor = DayKey(rawValue: firstDayKey).date(calendar: calendar) ?? calendar.startOfDay(for: task.createdAt)
        let finalDay = calendar.startOfDay(for: referenceDate)
        var current = 0
        var best = 0

        for _ in 0..<36_600 where cursor <= finalDay {
            if schedule.isScheduled(task, on: cursor, calendar: calendar) {
                if completedDays.contains(DayKey(date: cursor, calendar: calendar).rawValue) {
                    current += 1
                    best = max(best, current)
                } else {
                    current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return best
    }

    func completionDates(
        task: TaskDTO,
        checkIns: [CheckInDTO],
        calendar: Calendar = .autoupdatingCurrent
    ) -> [Date] {
        completedDayKeys(task: task, checkIns: checkIns, calendar: calendar)
            .compactMap { DayKey(rawValue: $0).date(calendar: calendar) }
            .sorted()
    }

    private func completedDayKeys(
        task: TaskDTO,
        checkIns: [CheckInDTO],
        calendar: Calendar
    ) -> Set<String> {
        let totals = Dictionary(grouping: checkIns.filter { $0.taskID == task.id }, by: \CheckInDTO.dayKey)
            .mapValues { events in events.reduce(0) { $0 + $1.value } }
        return Set(totals.compactMap { dayKey, total in
            guard let date = DayKey(rawValue: dayKey).date(calendar: calendar),
                  schedule.isScheduled(task, on: date, calendar: calendar),
                  total >= schedule.dailyTarget(for: task, on: date, calendar: calendar) else {
                return nil
            }
            return dayKey
        })
    }
}
