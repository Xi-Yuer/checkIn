import Foundation

struct CoreDataRepositories: Sendable {
    let tasks: any TaskRepository
    let checkIns: any CheckInRepository

    init(
        persistence: PersistenceController = .shared,
        dateProvider: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        let store = persistence.repositoryStore
        tasks = CoreDataTaskRepository(store: store, dateProvider: dateProvider, calendar: calendar)
        checkIns = CoreDataCheckInRepository(store: store, calendar: calendar)
    }
}
