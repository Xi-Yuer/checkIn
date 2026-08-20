import CoreData
import Foundation

final class CoreDataCheckInRepository: CheckInRepository, @unchecked Sendable {
    private let store: CoreDataStore
    private let calendar: Calendar

    init(store: CoreDataStore, calendar: Calendar = .autoupdatingCurrent) {
        self.store = store
        self.calendar = calendar
    }

    func checkIn(
        taskID: UUID,
        at date: Date,
        value: Int = 1,
        source: CheckInSource = .app
    ) async throws -> DailyProgress {
        guard value > 0 else { throw RepositoryError.invalidValue }
        let calendar = calendar
        return try await store.perform { context in
            guard let task = try CoreDataTaskRepository.fetchEntity(id: taskID, context: context) else {
                throw RepositoryError.taskNotFound
            }
            guard !task.isArchived else { throw RepositoryError.taskPaused }
            let taskDTO = task.makeDTO()
            guard TaskScheduleService().isScheduled(taskDTO, on: date, calendar: calendar) else {
                throw RepositoryError.notScheduled
            }

            let key = DayKey(date: date, calendar: calendar).rawValue
            let completed = try Self.total(taskID: taskID, dayKey: key, context: context)
            let target = TaskScheduleService().dailyTarget(for: taskDTO, on: date, calendar: calendar)
            guard completed < target else { throw RepositoryError.targetAlreadyReached }
            let acceptedValue = min(value, target - completed)

            let event = CheckInEntity(context: context)
            event.id = UUID()
            event.occurredAt = date
            event.dayKey = key
            event.value = Int16(acceptedValue)
            event.source = source.rawValue
            event.createdAt = date
            event.task = task
            task.lastCheckInAt = date
            task.updatedAt = date
            try context.save()

            return DailyProgress(
                taskID: taskID,
                date: date,
                completed: completed + acceptedValue,
                target: target
            )
        }
    }

    func undoLastCheckIn(taskID: UUID, on date: Date) async throws -> DailyProgress {
        let calendar = calendar
        return try await store.perform { context in
            guard let task = try CoreDataTaskRepository.fetchEntity(id: taskID, context: context) else {
                throw RepositoryError.taskNotFound
            }
            let key = DayKey(date: date, calendar: calendar).rawValue
            let request = CheckInEntity.fetchRequest()
            request.predicate = NSPredicate(format: "task.id == %@ AND dayKey == %@", taskID as CVarArg, key)
            request.sortDescriptors = [
                NSSortDescriptor(key: "occurredAt", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]
            request.fetchLimit = 1
            guard let event = try context.fetch(request).first else {
                throw RepositoryError.noCheckInToUndo
            }
            context.delete(event)

            let latestRequest = CheckInEntity.fetchRequest()
            latestRequest.predicate = NSPredicate(format: "task.id == %@", taskID as CVarArg)
            latestRequest.sortDescriptors = [NSSortDescriptor(key: "occurredAt", ascending: false)]
            latestRequest.fetchLimit = 2
            let remainingEvents = try context.fetch(latestRequest).filter { !$0.isDeleted }
            task.lastCheckInAt = remainingEvents.first?.occurredAt
            try context.save()

            let completed = try Self.total(taskID: taskID, dayKey: key, context: context)
            return DailyProgress(
                taskID: taskID,
                date: date,
                completed: completed,
                target: TaskScheduleService().dailyTarget(
                    for: task.makeDTO(),
                    on: date,
                    calendar: calendar
                )
            )
        }
    }

    func progress(taskID: UUID, on date: Date) async throws -> DailyProgress {
        let calendar = calendar
        return try await store.perform { context in
            guard let task = try CoreDataTaskRepository.fetchEntity(id: taskID, context: context) else {
                throw RepositoryError.taskNotFound
            }
            let key = DayKey(date: date, calendar: calendar).rawValue
            let taskDTO = task.makeDTO()
            return DailyProgress(
                taskID: taskID,
                date: date,
                completed: try Self.total(taskID: taskID, dayKey: key, context: context),
                target: TaskScheduleService().dailyTarget(for: taskDTO, on: date, calendar: calendar)
            )
        }
    }

    func progresses(taskIDs: [UUID], on date: Date) async throws -> [UUID: DailyProgress] {
        guard !taskIDs.isEmpty else { return [:] }
        let calendar = calendar
        return try await store.perform { context in
            let key = DayKey(date: date, calendar: calendar).rawValue
            let taskRequest = TaskEntity.fetchRequest()
            taskRequest.predicate = NSPredicate(format: "id IN %@", taskIDs)
            let tasks = try context.fetch(taskRequest)

            let eventRequest = CheckInEntity.fetchRequest()
            eventRequest.predicate = NSPredicate(format: "task.id IN %@ AND dayKey == %@", taskIDs, key)
            var totals: [UUID: Int] = [:]
            for event in try context.fetch(eventRequest) {
                guard let taskID = event.task?.id else { continue }
                totals[taskID, default: 0] += Int(event.value)
            }

            return Dictionary(uniqueKeysWithValues: tasks.map { task in
                let taskDTO = task.makeDTO()
                let progress = DailyProgress(
                    taskID: task.id,
                    date: date,
                    completed: totals[task.id, default: 0],
                    target: TaskScheduleService().dailyTarget(for: taskDTO, on: date, calendar: calendar)
                )
                return (task.id, progress)
            })
        }
    }

    func history(taskID: UUID, range: DateInterval) async throws -> [CheckInDTO] {
        try await store.perform { context in
            let request = CheckInEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "task.id == %@ AND occurredAt >= %@ AND occurredAt < %@",
                taskID as CVarArg,
                range.start as NSDate,
                range.end as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(key: "occurredAt", ascending: true)]
            return try context.fetch(request).compactMap { $0.makeDTO() }
        }
    }

    func checkInCount(taskID: UUID) async throws -> Int {
        try await store.perform { context in
            let request = CheckInEntity.fetchRequest()
            request.predicate = NSPredicate(format: "task.id == %@", taskID as CVarArg)
            return try context.count(for: request)
        }
    }

    func streak(taskID: UUID, through date: Date) async throws -> Int {
        let calendar = calendar
        return try await store.perform { context in
            guard let task = try CoreDataTaskRepository.fetchEntity(id: taskID, context: context)?.makeDTO() else {
                throw RepositoryError.taskNotFound
            }
            let events = try Self.events(taskID: taskID, context: context)
            return StreakCalculator().currentStreak(
                task: task,
                checkIns: events,
                through: date,
                calendar: calendar
            )
        }
    }

    func streaks(taskIDs: [UUID], through date: Date) async throws -> [UUID: Int] {
        guard !taskIDs.isEmpty else { return [:] }
        let calendar = calendar
        return try await store.perform { context in
            let taskRequest = TaskEntity.fetchRequest()
            taskRequest.predicate = NSPredicate(format: "id IN %@", taskIDs)
            let tasks = try context.fetch(taskRequest).map { $0.makeDTO() }

            let eventRequest = CheckInEntity.fetchRequest()
            eventRequest.predicate = NSPredicate(format: "task.id IN %@", taskIDs)
            let groupedEvents = Dictionary(
                grouping: try context.fetch(eventRequest).compactMap { $0.makeDTO() },
                by: \.taskID
            )
            let calculator = StreakCalculator()

            return Dictionary(uniqueKeysWithValues: tasks.map { task in
                let value = calculator.currentStreak(
                    task: task,
                    checkIns: groupedEvents[task.id] ?? [],
                    through: date,
                    calendar: calendar
                )
                return (task.id, value)
            })
        }
    }

    func statistics(period: StatisticsPeriod, anchor: Date, now: Date) async throws -> StatisticsSummary {
        let calendar = calendar
        return try await store.perform { context in
            let tasks = try context.fetch(TaskEntity.fetchRequest()).map { $0.makeDTO() }
            let events = try context.fetch(CheckInEntity.fetchRequest()).compactMap { $0.makeDTO() }
            return StatisticsCalculator().summary(
                tasks: tasks,
                checkIns: events,
                period: period,
                anchor: anchor,
                now: now,
                calendar: calendar
            )
        }
    }

    func badges(through date: Date) async throws -> [EarnedBadge] {
        let calendar = calendar
        return try await store.perform { context in
            let tasks = try context.fetch(TaskEntity.fetchRequest()).map { $0.makeDTO() }
            let events = try context.fetch(CheckInEntity.fetchRequest()).compactMap { $0.makeDTO() }
            return BadgeCalculator().earnedBadges(
                tasks: tasks,
                checkIns: events,
                through: date,
                calendar: calendar
            )
        }
    }

    private static func total(
        taskID: UUID,
        dayKey: String,
        context: NSManagedObjectContext
    ) throws -> Int {
        let request = CheckInEntity.fetchRequest()
        request.predicate = NSPredicate(format: "task.id == %@ AND dayKey == %@", taskID as CVarArg, dayKey)
        return try context.fetch(request).reduce(0) { $0 + Int($1.value) }
    }

    private static func events(taskID: UUID, context: NSManagedObjectContext) throws -> [CheckInDTO] {
        let request = CheckInEntity.fetchRequest()
        request.predicate = NSPredicate(format: "task.id == %@", taskID as CVarArg)
        return try context.fetch(request).compactMap { $0.makeDTO() }
    }
}
