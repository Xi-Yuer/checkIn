import Foundation

enum FixedTimeCheckInState: Equatable, Sendable {
    case unrestricted
    case notOpen(Date)
    case open(closesAt: Date)
    case missed
    case punctualComplete
    case lateComplete

    var allowsCheckIn: Bool {
        switch self {
        case .notOpen, .punctualComplete, .lateComplete: false
        case .unrestricted, .open, .missed: true
        }
    }
}

struct FixedTimeCheckInService: Sendable {
    let scheduleService = TaskScheduleService()

    func window(
        for task: TaskDTO,
        on date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval? {
        let plan = scheduleService.plan(for: task, on: date, calendar: calendar)
        guard plan.fixedTimeEnabled,
              let hour = plan.fixedTimeHour,
              let minute = plan.fixedTimeMinute else { return nil }
        let dayStart = calendar.startOfDay(for: date)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        var components = calendar.dateComponents([.year, .month, .day], from: dayStart)
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let target = calendar.date(from: components) else { return nil }
        let tolerance = TimeInterval(max(0, plan.fixedTimeToleranceMinutes) * 60)
        return DateInterval(
            start: max(dayStart, target.addingTimeInterval(-tolerance)),
            end: min(nextDay.addingTimeInterval(-0.001), target.addingTimeInterval(tolerance))
        )
    }

    func state(
        for task: TaskDTO,
        on day: Date,
        now: Date,
        progress: DailyProgress?,
        events: [CheckInDTO],
        calendar: Calendar = .autoupdatingCurrent
    ) -> FixedTimeCheckInState {
        guard let window = window(for: task, on: day, calendar: calendar) else { return .unrestricted }
        let complete = progress?.isComplete ?? false
        if complete {
            let key = DayKey(date: day, calendar: calendar).rawValue
            let dayEvents = events.filter { $0.taskID == task.id && $0.dayKey == key }
            return !dayEvents.isEmpty && dayEvents.allSatisfy {
                $0.occurredAt >= window.start && $0.occurredAt <= window.end
            }
                ? .punctualComplete : .lateComplete
        }
        if now < window.start { return .notOpen(window.start) }
        if now <= window.end { return .open(closesAt: window.end) }
        return .missed
    }

    func validateCheckIn(
        task: TaskDTO,
        scheduledDay: Date,
        occurredAt: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) throws {
        guard let window = window(for: task, on: scheduledDay, calendar: calendar) else { return }
        guard calendar.isDate(scheduledDay, inSameDayAs: occurredAt) else {
            throw RepositoryError.notScheduled
        }
        if occurredAt < window.start { throw RepositoryError.checkInWindowNotOpen }
    }
}
