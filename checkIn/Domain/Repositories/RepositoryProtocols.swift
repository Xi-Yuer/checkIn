import Foundation

protocol DateProvider: Sendable {
    var now: Date { get }
}

struct SystemDateProvider: DateProvider {
    var now: Date { Date() }
}

struct FixedDateProvider: DateProvider {
    var now: Date

    init(_ now: Date) {
        self.now = now
    }
}

protocol TaskRepository: Sendable {
    func fetch(_ query: TaskQuery) async throws -> [TaskDTO]
    func get(id: UUID) async throws -> TaskDTO?
    func create(_ draft: TaskDraft) async throws -> UUID
    func update(id: UUID, patch: TaskPatch) async throws
    func delete(id: UUID) async throws -> Int
    func archive(id: UUID) async throws
    func unarchive(id: UUID) async throws
    func updateManualOrder(_ orderedIDs: [UUID]) async throws
}

extension TaskRepository {
    func update(id: UUID, draft: TaskDraft) async throws {
        try await update(id: id, patch: TaskPatch(draft: draft))
    }
}

protocol CheckInRepository: Sendable {
    func checkIn(
        taskID: UUID,
        at date: Date,
        value: Int,
        source: CheckInSource
    ) async throws -> DailyProgress

    func undoLastCheckIn(taskID: UUID, on date: Date) async throws -> DailyProgress
    func progress(taskID: UUID, on date: Date) async throws -> DailyProgress
    func progresses(taskIDs: [UUID], on date: Date) async throws -> [UUID: DailyProgress]
    func history(taskID: UUID, range: DateInterval) async throws -> [CheckInDTO]
    func checkInCount(taskID: UUID) async throws -> Int
    func streak(taskID: UUID, through date: Date) async throws -> Int
    func statistics(period: StatisticsPeriod, anchor: Date, now: Date) async throws -> StatisticsSummary
    func badges(through date: Date) async throws -> [EarnedBadge]
}
