import CoreData
import Foundation

final class CoreDataTaskRepository: TaskRepository, @unchecked Sendable {
    private let store: CoreDataStore
    private let dateProvider: any DateProvider
    private let calendar: Calendar

    init(
        store: CoreDataStore,
        dateProvider: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.store = store
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func fetch(_ query: TaskQuery) async throws -> [TaskDTO] {
        let calendar = calendar
        return try await store.perform { context in
            let request = TaskEntity.fetchRequest()
            request.returnsObjectsAsFaults = false
            let entities = try context.fetch(request)
            let allTasks = entities.map { $0.makeDTO() }
            let relevantEvents: [CheckInDTO]
            if query.sort == .streak || query.filter == .pendingToday || query.filter == .completedToday {
                relevantEvents = try context.fetch(CheckInEntity.fetchRequest()).compactMap { $0.makeDTO() }
            } else {
                relevantEvents = []
            }

            return Self.filterAndSort(
                allTasks,
                events: relevantEvents,
                query: query,
                calendar: calendar
            )
        }
    }

    func get(id: UUID) async throws -> TaskDTO? {
        try await store.perform { context in
            try Self.fetchEntity(id: id, context: context)?.makeDTO()
        }
    }

    func create(_ draft: TaskDraft) async throws -> UUID {
        let validated = try draft.validated(calendar: calendar)
        let now = dateProvider.now
        return try await store.perform { context in
            let maxOrderRequest = NSFetchRequest<NSDictionary>(entityName: "TaskEntity")
            maxOrderRequest.resultType = .dictionaryResultType
            let expression = NSExpressionDescription()
            expression.name = "maxOrder"
            expression.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "sortOrder")])
            expression.expressionResultType = .integer32AttributeType
            maxOrderRequest.propertiesToFetch = [expression]
            let currentMaximum = (try context.fetch(maxOrderRequest).first?["maxOrder"] as? NSNumber)?.int32Value ?? -1

            let entity = TaskEntity(context: context)
            entity.id = UUID()
            entity.createdAt = now
            entity.createdDayKey = DayKey(date: now, calendar: calendar).rawValue
            entity.updatedAt = now
            entity.sortOrder = currentMaximum + 1
            entity.isArchived = false
            entity.apply(validated, now: now, calendar: calendar, isNew: true)
            try context.save()
            return entity.id
        }
    }

    func update(id: UUID, patch: TaskPatch) async throws {
        let validated = try patch.draft.validated(calendar: calendar)
        let now = dateProvider.now
        try await store.perform { context in
            guard let entity = try Self.fetchEntity(id: id, context: context) else {
                throw RepositoryError.taskNotFound
            }
            entity.apply(validated, now: now, calendar: calendar)
            try context.save()
        }
    }

    func delete(id: UUID) async throws -> Int {
        try await store.perform { context in
            guard let entity = try Self.fetchEntity(id: id, context: context) else {
                throw RepositoryError.taskNotFound
            }
            let historyCount = entity.checkIns?.count ?? 0
            context.delete(entity)
            try context.save()
            return historyCount
        }
    }

    func archive(id: UUID) async throws {
        try await setArchived(true, id: id)
    }

    func unarchive(id: UUID) async throws {
        try await setArchived(false, id: id)
    }

    func updateManualOrder(_ orderedIDs: [UUID]) async throws {
        try await store.perform { context in
            let request = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", orderedIDs)
            let entities = try context.fetch(request)
            let orderByID = Dictionary(uniqueKeysWithValues: orderedIDs.enumerated().map { ($1, Int32($0)) })
            for entity in entities {
                if let newOrder = orderByID[entity.id] { entity.sortOrder = newOrder }
            }
            if context.hasChanges { try context.save() }
        }
    }

    private func setArchived(_ archived: Bool, id: UUID) async throws {
        let now = dateProvider.now
        try await store.perform { context in
            guard let entity = try Self.fetchEntity(id: id, context: context) else {
                throw RepositoryError.taskNotFound
            }
            guard entity.isArchived != archived else { return }
            if archived {
                entity.beginPause(on: now, calendar: calendar)
            } else {
                entity.finishPause(on: now, calendar: calendar)
            }
            entity.isArchived = archived
            entity.updatedAt = now
            try context.save()
        }
    }

    static func fetchEntity(id: UUID, context: NSManagedObjectContext) throws -> TaskEntity? {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func filterAndSort(
        _ tasks: [TaskDTO],
        events: [CheckInDTO],
        query: TaskQuery,
        calendar: Calendar
    ) -> [TaskDTO] {
        let day = calendar.startOfDay(for: query.date)
        let dayKey = DayKey(date: day, calendar: calendar).rawValue
        let totals = Dictionary(grouping: events.filter { $0.dayKey == dayKey }, by: \CheckInDTO.taskID)
            .mapValues { $0.reduce(0) { $0 + $1.value } }
        let schedule = TaskScheduleService()

        var result = tasks.filter { task in
            let matchesSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                task.title.localizedCaseInsensitiveContains(query.searchText) ||
                task.note.localizedCaseInsensitiveContains(query.searchText)
            guard matchesSearch else { return false }

            let hasEnded = task.endDate.map { calendar.startOfDay(for: $0) < day } ?? false
            switch query.filter {
            case .all:
                return true
            case .active:
                return !task.isArchived && !hasEnded
            case .ended:
                return !task.isArchived && hasEnded
            case .paused:
                return task.isArchived
            case .pendingToday:
                return !task.isArchived && schedule.isScheduled(task, on: day, calendar: calendar) &&
                    totals[task.id, default: 0] < schedule.dailyTarget(for: task, on: day, calendar: calendar)
            case .completedToday:
                return !task.isArchived && schedule.isScheduled(task, on: day, calendar: calendar) &&
                    totals[task.id, default: 0] >= schedule.dailyTarget(for: task, on: day, calendar: calendar)
            }
        }

        let streak = StreakCalculator()
        result.sort { lhs, rhs in
            switch query.sort {
            case .manual:
                return lhs.sortOrder == rhs.sortOrder ? lhs.createdAt < rhs.createdAt : lhs.sortOrder < rhs.sortOrder
            case .priority:
                return lhs.priority == rhs.priority ? lhs.sortOrder < rhs.sortOrder : lhs.priority.rawValue > rhs.priority.rawValue
            case .createdAt:
                return lhs.createdAt == rhs.createdAt ? lhs.sortOrder < rhs.sortOrder : lhs.createdAt > rhs.createdAt
            case .streak:
                let lhsValue = streak.currentStreak(task: lhs, checkIns: events, through: query.date, calendar: calendar)
                let rhsValue = streak.currentStreak(task: rhs, checkIns: events, through: query.date, calendar: calendar)
                return lhsValue == rhsValue ? lhs.sortOrder < rhs.sortOrder : lhsValue > rhsValue
            }
        }
        return result
    }
}
