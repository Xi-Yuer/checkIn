import Foundation

struct TaskScheduleService: Sendable {
    struct SpecificDateOccurrence: Identifiable, Hashable, Sendable {
        let entryID: UUID
        let date: Date
        let dayKey: String
        let daysRemaining: Int
        var id: String { "\(entryID.uuidString).\(dayKey)" }
    }

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
            endDayKey: task.endDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            fixedTimeEnabled: task.fixedTimeEnabled,
            fixedTimeHour: task.fixedTimeHour,
            fixedTimeMinute: task.fixedTimeMinute,
            fixedTimeToleranceMinutes: task.fixedTimeToleranceMinutes
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

        if case let .specificDates(entries, _) = revision.schedule {
            return entries.contains { entry in
                if entry.recurrence == .once {
                    return entry.dayKey == dayKey
                }
                return occurrenceDate(for: entry, year: calendar.component(.year, from: day), calendar: calendar)
                    .map { calendar.isDate($0, inSameDayAs: day) } ?? false
            }
        }

        let weekdayValue = calendar.component(.weekday, from: day)
        guard let weekday = Weekday(rawValue: Int16(weekdayValue)) else { return false }
        return revision.schedule.includes(weekday)
    }

    func upcomingOccurrences(
        for task: TaskDTO,
        from date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [SpecificDateOccurrence] {
        guard !task.isArchived else { return [] }
        let today = calendar.startOfDay(for: date)
        let plan = plan(for: task, on: today, calendar: calendar)
        guard case let .specificDates(entries, countdownDays) = plan.schedule else { return [] }
        return entries.compactMap { entry in
            guard let occurrence = nextOccurrence(for: entry, onOrAfter: today, calendar: calendar) else { return nil }
            let remaining = calendar.dateComponents([.day], from: today, to: occurrence).day ?? Int.max
            guard (0...countdownDays).contains(remaining) else { return nil }
            return SpecificDateOccurrence(
                entryID: entry.id,
                date: occurrence,
                dayKey: DayKey(date: occurrence, calendar: calendar).rawValue,
                daysRemaining: remaining
            )
        }
        .sorted { $0.date == $1.date ? $0.entryID.uuidString < $1.entryID.uuidString : $0.date < $1.date }
    }

    func nextOccurrence(
        for entry: TaskSpecificDate,
        onOrAfter date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date? {
        let day = calendar.startOfDay(for: date)
        guard let original = DayKey(rawValue: entry.dayKey).date(calendar: calendar) else { return nil }
        if entry.recurrence == .once {
            return original >= day ? original : nil
        }
        let year = calendar.component(.year, from: day)
        if let current = occurrenceDate(for: entry, year: year, calendar: calendar), current >= day {
            return current
        }
        return occurrenceDate(for: entry, year: year + 1, calendar: calendar)
    }

    private func occurrenceDate(for entry: TaskSpecificDate, year: Int, calendar: Calendar) -> Date? {
        guard let original = DayKey(rawValue: entry.dayKey).date(calendar: calendar) else { return nil }
        let parts = calendar.dateComponents([.month, .day], from: original)
        var components = DateComponents(year: year, month: parts.month, day: parts.day)
        if let exact = calendar.date(from: components),
           calendar.component(.month, from: exact) == parts.month,
           calendar.component(.day, from: exact) == parts.day {
            return calendar.startOfDay(for: exact)
        }
        if parts.month == 2, parts.day == 29 {
            components.day = 28
            return calendar.date(from: components).map(calendar.startOfDay(for:))
        }
        return nil
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
