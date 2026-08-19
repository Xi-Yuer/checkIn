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
    @NSManaged var dailyTarget: Int16
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
                weekdaysMask: weekdaysMask
            ),
            dailyTarget: max(1, Int(dailyTarget)),
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
        var revisions = decoded([TaskPlanRevision].self, from: planRevisionsData) ?? []
        if revisions.isEmpty, !isNew {
            revisions.append(
                TaskPlanRevision(
                    effectiveDayKey: createdDayKey ?? DayKey(date: createdAt, calendar: calendar).rawValue,
                    schedule: TaskSchedule(
                        type: TaskScheduleType(rawValue: scheduleType) ?? .daily,
                        weekdaysMask: weekdaysMask
                    ),
                    dailyTarget: max(1, Int(dailyTarget)),
                    startDayKey: startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
                    endDayKey: endDate.map { DayKey(date: $0, calendar: calendar).rawValue }
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
        dailyTarget = Int16(draft.dailyTarget)
        reminderEnabled = draft.reminderEnabled
        reminderHour = draft.reminderHour.map(NSNumber.init(value:))
        reminderMinute = draft.reminderMinute.map(NSNumber.init(value:))
        startDate = draft.startDate
        endDate = draft.endDate
        updatedAt = now

        let revision = TaskPlanRevision(
            effectiveDayKey: effectiveDayKey,
            schedule: draft.schedule,
            dailyTarget: draft.dailyTarget,
            startDayKey: draft.startDate.map { DayKey(date: $0, calendar: calendar).rawValue },
            endDayKey: draft.endDate.map { DayKey(date: $0, calendar: calendar).rawValue }
        )
        revisions.removeAll { $0.effectiveDayKey == effectiveDayKey }
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
