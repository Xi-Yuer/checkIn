import CoreData
import Foundation

@objc(TaskEntity)
final class TaskEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var note: String?
    @NSManaged var category: Int16
    @NSManaged var iconKey: String
    @NSManaged var colorHex: String
    @NSManaged var priority: Int16
    @NSManaged var sortOrder: Int32
    @NSManaged var scheduleType: Int16
    @NSManaged var weekdaysMask: Int16
    @NSManaged var specificDatesData: Data?
    @NSManaged var countdownDays: Int16
    @NSManaged var dailyTarget: Int16
    @NSManaged var autoCheckInEnabled: Bool
    @NSManaged var autoCheckInStartDayKey: String?
    @NSManaged var autoCheckInLastProcessedDayKey: String?
    @NSManaged var fixedTimeEnabled: Bool
    @NSManaged var fixedTimeHour: NSNumber?
    @NSManaged var fixedTimeMinute: NSNumber?
    @NSManaged var fixedTimeToleranceMinutes: Int16
    @NSManaged var reminderEnabled: Bool
    @NSManaged var reminderHour: NSNumber?
    @NSManaged var reminderMinute: NSNumber?
    @NSManaged var startDate: Date?
    @NSManaged var endDate: Date?
    @NSManaged var createdAt: Date
    @NSManaged var createdDayKey: String?
    @NSManaged var updatedAt: Date
    @NSManaged var lastCheckInAt: Date?
    @NSManaged var isArchived: Bool
    @NSManaged var planRevisionsData: Data?
    @NSManaged var pauseIntervalsData: Data?
    @NSManaged var checkIns: Set<CheckInEntity>?
}

extension TaskEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    func makeDTO() -> TaskDTO {
        TaskDTO(
            id: id,
            title: title,
            note: note ?? "",
            category: HabitCategory(rawValue: category) ?? .other,
            iconKey: iconKey,
            colorHex: colorHex,
            priority: TaskPriority(rawValue: priority) ?? .normal,
            sortOrder: Int(sortOrder),
            schedule: TaskSchedule(
                type: TaskScheduleType(rawValue: scheduleType) ?? .daily,
                weekdaysMask: weekdaysMask,
                specificDates: decoded([TaskSpecificDate].self, from: specificDatesData) ?? [],
                countdownDays: max(1, Int(countdownDays))
            ),
            dailyTarget: max(1, Int(dailyTarget)),
            autoCheckInEnabled: autoCheckInEnabled,
            autoCheckInStartDayKey: autoCheckInStartDayKey,
            autoCheckInLastProcessedDayKey: autoCheckInLastProcessedDayKey,
            fixedTimeEnabled: fixedTimeEnabled,
            fixedTimeHour: fixedTimeHour?.intValue,
            fixedTimeMinute: fixedTimeMinute?.intValue,
            fixedTimeToleranceMinutes: max(5, Int(fixedTimeToleranceMinutes)),
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour?.intValue,
            reminderMinute: reminderMinute?.intValue,
            startDate: startDate,
            endDate: endDate,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastCheckInAt: lastCheckInAt,
            isArchived: isArchived,
            createdDayKey: createdDayKey,
            planRevisions: decoded([TaskPlanRevision].self, from: planRevisionsData) ?? [],
            pauseIntervals: decoded([TaskPauseInterval].self, from: pauseIntervalsData) ?? []
        )
    }

    func apply(
        _ draft: TaskDraft,
        now: Date,
        calendar: Calendar,
        isNew: Bool = false
    ) {
        let effectiveDayKey = DayKey(date: now, calendar: calendar).rawValue
        let wasAutoCheckInEnabled = autoCheckInEnabled
        var revisions = decoded([TaskPlanRevision].self, from: planRevisionsData) ?? []
        let activeRevision = revisions
            .filter { $0.effectiveDayKey <= effectiveDayKey }
            .max { $0.effectiveDayKey < $1.effectiveDayKey }
        let previousFixedTimeEnabled = activeRevision?.fixedTimeEnabled ?? fixedTimeEnabled
        let previousFixedTimeHour = activeRevision?.fixedTimeHour ?? fixedTimeHour?.intValue
        let previousFixedTimeMinute = activeRevision?.fixedTimeMinute ?? fixedTimeMinute?.intValue
        let previousFixedTimeTolerance = activeRevision?.fixedTimeToleranceMinutes
            ?? max(5, Int(fixedTimeToleranceMinutes))
        let newFixedTimeStartsToday: Bool = {
            guard draft.fixedTimeEnabled,
                  let hour = draft.fixedTimeHour,
                  let minute = draft.fixedTimeMinute else { return false }
            var components = calendar.dateComponents([.year, .month, .day], from: now)
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let target = calendar.date(from: components) else { return false }
            return now < target
        }()
        if revisions.isEmpty, !isNew {
            revisions.append(
                TaskPlanRevision(
                    effectiveDayKey: createdDayKey ?? DayKey(date: createdAt, calendar: calendar).rawValue,
                    schedule: TaskSchedule(
                        type: TaskScheduleType(rawValue: scheduleType) ?? .daily,
                        weekdaysMask: weekdaysMask,
                        specificDates: decoded([TaskSpecificDate].self, from: specificDatesData) ?? [],
                        countdownDays: max(1, Int(countdownDays))
                    ),
                    dailyTarget: max(1, Int(dailyTarget)),
                    startDayKey: startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
                    endDayKey: endDate.map { DayKey(date: $0, calendar: calendar).rawValue },
                    fixedTimeEnabled: fixedTimeEnabled,
                    fixedTimeHour: fixedTimeHour?.intValue,
                    fixedTimeMinute: fixedTimeMinute?.intValue,
                    fixedTimeToleranceMinutes: max(5, Int(fixedTimeToleranceMinutes))
                )
            )
        }

        title = draft.title
        note = draft.note.isEmpty ? nil : draft.note
        category = draft.category.rawValue
        iconKey = draft.iconKey
        colorHex = draft.colorHex
        priority = draft.priority.rawValue
        scheduleType = draft.schedule.type.rawValue
        weekdaysMask = draft.schedule.weekdaysMask
        specificDatesData = encoded(draft.schedule.specificDateEntries)
        countdownDays = Int16(draft.schedule.countdownDays)
        dailyTarget = Int16(draft.dailyTarget)
        autoCheckInEnabled = draft.autoCheckInEnabled
        if draft.autoCheckInEnabled && !wasAutoCheckInEnabled {
            let today = calendar.startOfDay(for: now)
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            autoCheckInStartDayKey = effectiveDayKey
            autoCheckInLastProcessedDayKey = DayKey(date: yesterday, calendar: calendar).rawValue
        } else if !draft.autoCheckInEnabled {
            autoCheckInStartDayKey = nil
            autoCheckInLastProcessedDayKey = nil
        }
        fixedTimeEnabled = draft.fixedTimeEnabled
        fixedTimeHour = draft.fixedTimeHour.map(NSNumber.init(value:))
        fixedTimeMinute = draft.fixedTimeMinute.map(NSNumber.init(value:))
        fixedTimeToleranceMinutes = Int16(draft.fixedTimeToleranceMinutes)
        reminderEnabled = draft.reminderEnabled
        reminderHour = draft.reminderHour.map(NSNumber.init(value:))
        reminderMinute = draft.reminderMinute.map(NSNumber.init(value:))
        startDate = draft.startDate
        endDate = draft.endDate
        updatedAt = now

        let immediateRevision = TaskPlanRevision(
            effectiveDayKey: effectiveDayKey,
            schedule: draft.schedule,
            dailyTarget: draft.dailyTarget,
            startDayKey: draft.startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            endDayKey: draft.endDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            fixedTimeEnabled: newFixedTimeStartsToday ? draft.fixedTimeEnabled : (isNew ? false : previousFixedTimeEnabled),
            fixedTimeHour: newFixedTimeStartsToday ? draft.fixedTimeHour : (isNew ? nil : previousFixedTimeHour),
            fixedTimeMinute: newFixedTimeStartsToday ? draft.fixedTimeMinute : (isNew ? nil : previousFixedTimeMinute),
            fixedTimeToleranceMinutes: newFixedTimeStartsToday
                ? draft.fixedTimeToleranceMinutes
                : (isNew ? 15 : previousFixedTimeTolerance)
        )
        revisions.removeAll { $0.effectiveDayKey == effectiveDayKey }
        revisions.append(immediateRevision)

        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        let revision = TaskPlanRevision(
            effectiveDayKey: DayKey(date: tomorrow, calendar: calendar).rawValue,
            schedule: draft.schedule,
            dailyTarget: draft.dailyTarget,
            startDayKey: draft.startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            endDayKey: draft.endDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            fixedTimeEnabled: draft.fixedTimeEnabled,
            fixedTimeHour: draft.fixedTimeHour,
            fixedTimeMinute: draft.fixedTimeMinute,
            fixedTimeToleranceMinutes: draft.fixedTimeToleranceMinutes
        )
        revisions.removeAll { $0.effectiveDayKey == revision.effectiveDayKey }
        revisions.append(revision)
        revisions.sort { $0.effectiveDayKey < $1.effectiveDayKey }
        planRevisionsData = encoded(revisions)
    }

    func beginPause(on date: Date, calendar: Calendar) {
        var intervals = decoded([TaskPauseInterval].self, from: pauseIntervalsData) ?? []
        guard !intervals.contains(where: { $0.endDayKey == nil }) else { return }
        intervals.append(
            TaskPauseInterval(
                startDayKey: DayKey(date: date, calendar: calendar).rawValue,
                endDayKey: nil
            )
        )
        pauseIntervalsData = encoded(intervals)
    }

    func finishPause(on date: Date, calendar: Calendar) {
        var intervals = decoded([TaskPauseInterval].self, from: pauseIntervalsData) ?? []
        guard let index = intervals.lastIndex(where: { $0.endDayKey == nil }) else { return }
        let endDayKey = DayKey(date: date, calendar: calendar).rawValue
        if intervals[index].startDayKey == endDayKey {
            intervals.remove(at: index)
        } else {
            intervals[index].endDayKey = endDayKey
        }
        pauseIntervalsData = encoded(intervals)
    }

    private func decoded<Value: Decodable>(_ type: Value.Type, from data: Data?) -> Value? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encoded<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }
}

@objc(CheckInEntity)
final class CheckInEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var occurredAt: Date
    @NSManaged var dayKey: String
    @NSManaged var value: Int16
    @NSManaged var source: Int16
    @NSManaged var createdAt: Date
    @NSManaged var task: TaskEntity?
}

extension CheckInEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CheckInEntity> {
        NSFetchRequest<CheckInEntity>(entityName: "CheckInEntity")
    }

    func makeDTO() -> CheckInDTO? {
        guard let task else { return nil }
        return CheckInDTO(
            id: id,
            taskID: task.id,
            occurredAt: occurredAt,
            dayKey: dayKey,
            value: Int(value),
            source: CheckInSource(rawValue: source) ?? .app,
            createdAt: createdAt
        )
    }
}
