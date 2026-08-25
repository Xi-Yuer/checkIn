import CoreData
import Foundation
import XCTest
@testable import checkIn

@MainActor
final class NotificationMasterSwitchTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 10))!
    }

    func testOlderSettingsDecodeWithNotificationsEnabled() throws {
        let data = Data(#"{"hapticsEnabled":false,"appearance":"dark","taskFilter":"active","taskSort":"priority"}"#.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertFalse(settings.hapticsEnabled)
        XCTAssertEqual(settings.appearance, .dark)
        XCTAssertEqual(settings.taskFilter, .active)
        XCTAssertEqual(settings.taskSort, .priority)
        XCTAssertTrue(settings.areNotificationsEnabled)
    }

    func testDisablingRemovesNotificationsAndPreventsReconciliation() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let taskID = try await repositories.tasks.create(reminderDraft)
        let scheduler = NotificationSchedulerSpy(status: .authorized)
        let settingsStore = InMemorySettingsStore()
        let store = makeStore(
            repositories: repositories,
            scheduler: scheduler,
            settingsStore: settingsStore
        )
        await store.load()
        let reconciliationsBeforeDisable = await scheduler.snapshot().reconciledTaskIDs.count

        await store.setNotificationsEnabled(false)
        await store.refreshNotifications()

        let snapshot = await scheduler.snapshot()
        let persistedTask = try await repositories.tasks.get(id: taskID)
        XCTAssertFalse(store.settings.areNotificationsEnabled)
        XCTAssertFalse(settingsStore.load().areNotificationsEnabled)
        XCTAssertGreaterThanOrEqual(snapshot.removeAllCount, 2)
        XCTAssertEqual(snapshot.reconciledTaskIDs.count, reconciliationsBeforeDisable)
        XCTAssertTrue(persistedTask?.reminderEnabled == true)
    }

    func testReenablingRequestsPermissionAndRestoresReminderSchedule() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let taskID = try await repositories.tasks.create(reminderDraft)
        let scheduler = NotificationSchedulerSpy(status: .notDetermined)
        let settingsStore = InMemorySettingsStore(AppSettings(notificationsEnabled: false))
        let store = makeStore(
            repositories: repositories,
            scheduler: scheduler,
            settingsStore: settingsStore
        )
        await store.load()

        await store.setNotificationsEnabled(true)

        let snapshot = await scheduler.snapshot()
        XCTAssertTrue(store.settings.areNotificationsEnabled)
        XCTAssertEqual(snapshot.authorizationRequests, 1)
        XCTAssertTrue(snapshot.reconciledTaskIDs.last?.contains(taskID) == true)
    }

    private var reminderDraft: TaskDraft {
        TaskDraft(
            title: "阅读",
            reminderEnabled: true,
            reminderHour: 20,
            reminderMinute: 30
        )
    }

    private func makeStore(
        repositories: CoreDataRepositories,
        scheduler: NotificationSchedulerSpy,
        settingsStore: InMemorySettingsStore
    ) -> AppStore {
        AppStore(
            tasks: repositories.tasks,
            checkIns: repositories.checkIns,
            notificationScheduler: scheduler,
            settingsStore: settingsStore,
            dateProvider: FixedDateProvider(now),
            calendar: calendar,
            reviewPromptPolicy: InMemoryReviewPromptPolicy(),
            appVersionProvider: { "1.0" }
        )
    }
}

private actor NotificationSchedulerSpy: NotificationScheduling {
    struct Snapshot: Sendable {
        let authorizationRequests: Int
        let reconciledTaskIDs: [[UUID]]
        let removeAllCount: Int
    }

    private var status: NotificationAuthorizationStatus
    private var authorizationRequests = 0
    private var reconciledTaskIDs: [[UUID]] = []
    private var removeAllCount = 0

    init(status: NotificationAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus { status }

    func requestAuthorization() async throws -> Bool {
        authorizationRequests += 1
        status = .authorized
        return true
    }

    func reconcile(
        tasks: [TaskDTO],
        completedDayKeys: [UUID: Set<String>],
        now: Date
    ) async throws {
        reconciledTaskIDs.append(tasks.map(\.id))
    }

    func remove(taskID: UUID) async {}

    func removeAll() async {
        removeAllCount += 1
    }

    func snapshot() -> Snapshot {
        Snapshot(
            authorizationRequests: authorizationRequests,
            reconciledTaskIDs: reconciledTaskIDs,
            removeAllCount: removeAllCount
        )
    }
}
