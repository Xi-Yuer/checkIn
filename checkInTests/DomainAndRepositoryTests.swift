import CoreData
import UserNotifications
import XCTest
@testable import checkIn

@MainActor
final class DomainAndRepositoryTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        self.calendar = calendar
        now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 10))!
    }

    func testValidationTrimsTextAndRejectsEmptyCustomSchedule() throws {
        let validated = try TaskDraft(title: "  阅读  ", note: "  30 分钟  ").validated(calendar: calendar)
        XCTAssertEqual(validated.title, "阅读")
        XCTAssertEqual(validated.note, "30 分钟")

        XCTAssertThrowsError(
            try TaskDraft(title: "运动", schedule: .custom([])).validated(calendar: calendar)
        ) { error in
            XCTAssertEqual(error as? TaskValidationError, .emptyCustomSchedule)
        }
    }

    func testScheduleIncludesBoundsAndSkipsNonPlanDays() {
        let monday = date(2026, 8, 17)
        let friday = date(2026, 8, 21)
        let saturday = date(2026, 8, 22)
        let task = makeTask(schedule: .weekdays, startDate: monday, endDate: friday)
        let service = TaskScheduleService()

        XCTAssertTrue(service.isScheduled(task, on: monday, calendar: calendar))
        XCTAssertTrue(service.isScheduled(task, on: friday, calendar: calendar))
        XCTAssertFalse(service.isScheduled(task, on: saturday, calendar: calendar))
    }

    func testStreakSkipsWeekendsAndPendingTodayDoesNotBreakIt() {
        let task = makeTask(schedule: .weekdays, dailyTarget: 1, startDate: date(2026, 8, 13))
        let events = [
            makeCheckIn(task: task, date: date(2026, 8, 13)),
            makeCheckIn(task: task, date: date(2026, 8, 14)),
            makeCheckIn(task: task, date: date(2026, 8, 17)),
            makeCheckIn(task: task, date: date(2026, 8, 18))
        ]

        XCTAssertEqual(
            StreakCalculator().currentStreak(task: task, checkIns: events, through: now, calendar: calendar),
            4
        )
    }

    func testStatisticsUseCompletedPlannedTaskDays() {
        let task = makeTask(schedule: .daily, dailyTarget: 2, startDate: date(2026, 8, 17))
        let events = [
            makeCheckIn(task: task, date: date(2026, 8, 17)),
            makeCheckIn(task: task, date: date(2026, 8, 17)),
            makeCheckIn(task: task, date: date(2026, 8, 18)),
            makeCheckIn(task: task, date: date(2026, 8, 18)),
            makeCheckIn(task: task, date: date(2026, 8, 19))
        ]

        let summary = StatisticsCalculator().summary(
            tasks: [task],
            checkIns: events,
            period: .week,
            anchor: now,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(summary.plannedTaskDays, 3)
        XCTAssertEqual(summary.completedTaskDays, 2)
        XCTAssertEqual(summary.completionRate, 2.0 / 3.0, accuracy: 0.001)
    }

    func testChartPadsIncompleteWeekMonthAndYearFromPreviousPeriod() {
        let task = makeTask(schedule: .daily, dailyTarget: 1, startDate: date(2025, 1, 1))
        let calculator = StatisticsCalculator()

        let week = calculator.summary(
            tasks: [task],
            checkIns: [],
            period: .week,
            anchor: now,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(week.daily.map(\.dayKey), ["2026-08-17", "2026-08-18", "2026-08-19"])
        XCTAssertEqual(week.chartDaily.count, 7)
        XCTAssertEqual(week.chartDaily.first?.dayKey, "2026-08-13")
        XCTAssertEqual(week.chartDaily.last?.dayKey, "2026-08-19")

        let month = calculator.summary(
            tasks: [task],
            checkIns: [],
            period: .month,
            anchor: now,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(month.daily.count, 19)
        XCTAssertEqual(month.chartDaily.count, 31)
        XCTAssertEqual(month.chartDaily.first?.dayKey, "2026-07-20")
        XCTAssertEqual(month.chartDaily.last?.dayKey, "2026-08-19")

        let year = calculator.summary(
            tasks: [task],
            checkIns: [],
            period: .year,
            anchor: now,
            now: now,
            calendar: calendar
        )
        let yearMonths = Dictionary(grouping: year.chartDaily) {
            calendar.dateComponents([.year, .month], from: $0.date)
        }
        XCTAssertEqual(yearMonths.count, 12)
        XCTAssertEqual(year.chartDaily.first?.dayKey, "2025-09-01")
        XCTAssertEqual(year.chartDaily.last?.dayKey, "2026-08-19")
    }

    func testChartDoesNotPadCompletedPastWeek() {
        let task = makeTask(schedule: .daily, startDate: date(2026, 7, 1))
        let pastWeek = date(2026, 7, 15)
        let summary = StatisticsCalculator().summary(
            tasks: [task],
            checkIns: [],
            period: .week,
            anchor: pastWeek,
            now: now,
            calendar: calendar
        )
        XCTAssertEqual(summary.daily.count, 7)
        XCTAssertEqual(summary.chartDaily.count, 7)
        XCTAssertEqual(summary.daily.map(\.dayKey), summary.chartDaily.map(\.dayKey))
    }

    func testPlanRevisionsPreserveHistoricalTargetsAndExposePartialProgress() {
        var task = makeTask(schedule: .daily, dailyTarget: 1, startDate: date(2026, 8, 17))
        task.createdDayKey = "2026-08-17"
        task.planRevisions = [
            TaskPlanRevision(
                effectiveDayKey: "2026-08-17",
                schedule: .daily,
                dailyTarget: 1,
                startDayKey: "2026-08-17",
                endDayKey: nil
            ),
            TaskPlanRevision(
                effectiveDayKey: "2026-08-19",
                schedule: .weekdays,
                dailyTarget: 2,
                startDayKey: "2026-08-17",
                endDayKey: nil
            )
        ]
        let events = [
            makeCheckIn(task: task, date: date(2026, 8, 17)),
            makeCheckIn(task: task, date: date(2026, 8, 18)),
            makeCheckIn(task: task, date: date(2026, 8, 19))
        ]

        let summary = StatisticsCalculator().summary(
            tasks: [task],
            checkIns: events,
            period: .week,
            anchor: now,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.plannedTaskDays, 3)
        XCTAssertEqual(summary.completedTaskDays, 2)
        XCTAssertEqual(summary.daily.last?.progressedTaskCount, 1)
        XCTAssertEqual(summary.daily.last?.intensity, .partial)
    }

    func testPauseIntervalsSkipMissedDaysWithoutBreakingStreak() {
        var task = makeTask(schedule: .daily, startDate: date(2026, 8, 17))
        task.createdDayKey = "2026-08-17"
        task.pauseIntervals = [TaskPauseInterval(startDayKey: "2026-08-18", endDayKey: "2026-08-20")]
        let through = date(2026, 8, 20)
        let events = [
            makeCheckIn(task: task, date: date(2026, 8, 17)),
            makeCheckIn(task: task, date: through)
        ]

        XCTAssertEqual(
            StreakCalculator().currentStreak(task: task, checkIns: events, through: through, calendar: calendar),
            2
        )
        let summary = StatisticsCalculator().summary(
            tasks: [task],
            checkIns: events,
            period: .week,
            anchor: through,
            now: through,
            calendar: calendar
        )
        XCTAssertEqual(summary.plannedTaskDays, 2)
        XCTAssertEqual(summary.completedTaskDays, 2)
    }

    func testStoredCreatedDayKeyDoesNotMoveAcrossTimeZones() {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let created = shanghai.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 1))!
        var task = makeTask(schedule: .daily)
        task.createdAt = created
        task.createdDayKey = "2026-08-19"

        let august18 = losAngeles.date(from: DateComponents(year: 2026, month: 8, day: 18, hour: 12))!
        let august19 = losAngeles.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: 12))!
        let service = TaskScheduleService()
        XCTAssertFalse(service.isScheduled(task, on: august18, calendar: losAngeles))
        XCTAssertTrue(service.isScheduled(task, on: august19, calendar: losAngeles))
    }

    func testDayKeysRemainCivilDatesAcrossDSTTransition() {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        let before = newYork.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 1, minute: 30))!
        let nextDay = newYork.date(byAdding: .day, value: 1, to: before)!

        XCTAssertEqual(DayKey(date: before, calendar: newYork).rawValue, "2026-03-08")
        XCTAssertEqual(DayKey(date: nextDay, calendar: newYork).rawValue, "2026-03-09")
        XCTAssertEqual(newYork.component(.hour, from: nextDay), 1)
    }

    func testRepositoryLocksAtTargetAndUndoRemovesLatestEvent() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let id = try await repositories.tasks.create(TaskDraft(title: "喝水", dailyTarget: 2))

        let attempts = (0..<3).map { _ in
            Task { () -> Result<DailyProgress, Error> in
                do {
                    return .success(
                        try await repositories.checkIns.checkIn(
                            taskID: id,
                            at: now,
                            value: 1,
                            source: .app
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }
        }
        var results: [Result<DailyProgress, Error>] = []
        for attempt in attempts {
            results.append(await attempt.value)
        }

        XCTAssertEqual(results.compactMap { try? $0.get() }.count, 2)
        let completedProgress = try await repositories.checkIns.progress(taskID: id, on: now)
        XCTAssertEqual(completedProgress.completed, 2)
        let completedStreaks = try await repositories.checkIns.streaks(taskIDs: [id], through: now)
        XCTAssertEqual(completedStreaks[id], 1)
        let undoneProgress = try await repositories.checkIns.undoLastCheckIn(taskID: id, on: now)
        XCTAssertEqual(undoneProgress.completed, 1)
        let undoneStreaks = try await repositories.checkIns.streaks(taskIDs: [id], through: now)
        XCTAssertEqual(undoneStreaks[id], 0)
    }

    func testRepositoryTreatsWidgetEventIDAsIdempotencyKey() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let taskID = try await repositories.tasks.create(TaskDraft(title: "喝水", dailyTarget: 3))
        let eventID = UUID()

        _ = try await repositories.checkIns.checkIn(
            taskID: taskID,
            at: now,
            value: 1,
            source: .widget,
            eventID: eventID
        )
        _ = try await repositories.checkIns.checkIn(
            taskID: taskID,
            at: now,
            value: 1,
            source: .widget,
            eventID: eventID
        )

        let progress = try await repositories.checkIns.progress(taskID: taskID, on: now)
        let historyCount = try await repositories.checkIns.checkInCount(taskID: taskID)
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(historyCount, 1)
    }

    func testPauseResumeAndCascadeDelete() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let id = try await repositories.tasks.create(TaskDraft(title: "早起"))
        _ = try await repositories.checkIns.checkIn(taskID: id, at: now, value: 1, source: .app)

        try await repositories.tasks.archive(id: id)
        let pausedTask = try await repositories.tasks.get(id: id)
        XCTAssertEqual(pausedTask?.isArchived, true)
        try await repositories.tasks.unarchive(id: id)
        let resumedTask = try await repositories.tasks.get(id: id)
        XCTAssertEqual(resumedTask?.isArchived, false)
        let deletedHistoryCount = try await repositories.tasks.delete(id: id)
        XCTAssertEqual(deletedHistoryCount, 1)
        let deletedTask = try await repositories.tasks.get(id: id)
        XCTAssertNil(deletedTask)
        let interval = DateInterval(start: date(2026, 8, 18), end: date(2026, 8, 20))
        let remainingHistory = try await repositories.checkIns.history(taskID: id, range: interval)
        XCTAssertTrue(remainingHistory.isEmpty)
    }

    func testRepositoryPlanEditAndPauseHistoryRemainDateEffective() async throws {
        let persistence = PersistenceController(inMemory: true)
        let createdAt = date(2026, 8, 17)
        let initial = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(createdAt),
            calendar: calendar
        )
        let id = try await initial.tasks.create(TaskDraft(title: "复习", dailyTarget: 1))
        _ = try await initial.checkIns.checkIn(taskID: id, at: createdAt, value: 1, source: .app)

        let pauseDate = date(2026, 8, 18)
        let paused = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(pauseDate),
            calendar: calendar
        )
        try await paused.tasks.archive(id: id)

        let resumeDate = date(2026, 8, 20)
        let resumed = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(resumeDate),
            calendar: calendar
        )
        try await resumed.tasks.unarchive(id: id)
        try await resumed.tasks.update(id: id, draft: TaskDraft(title: "复习", dailyTarget: 2))
        _ = try await resumed.checkIns.checkIn(taskID: id, at: resumeDate, value: 1, source: .app)

        let historicalProgress = try await resumed.checkIns.progress(taskID: id, on: createdAt)
        let currentProgress = try await resumed.checkIns.progress(taskID: id, on: resumeDate)
        XCTAssertEqual(historicalProgress.target, 1)
        XCTAssertEqual(currentProgress.target, 2)
        let summary = try await resumed.checkIns.statistics(period: .week, anchor: resumeDate, now: resumeDate)
        XCTAssertEqual(summary.plannedTaskDays, 2)
        XCTAssertEqual(summary.completedTaskDays, 1)
    }

    func testTwoRepositoryFactoriesShareTargetLock() async throws {
        let persistence = PersistenceController(inMemory: true)
        let firstRepositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let secondRepositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let id = try await firstRepositories.tasks.create(TaskDraft(title: "喝水", dailyTarget: 2))
        let repositories = [firstRepositories, secondRepositories, firstRepositories]
        let attempts = repositories.map { repositories in
            Task { () -> Bool in
                (try? await repositories.checkIns.checkIn(
                    taskID: id,
                    at: now,
                    value: 1,
                    source: .app
                )) != nil
            }
        }
        var accepted = 0
        for attempt in attempts {
            if await attempt.value { accepted += 1 }
        }

        XCTAssertEqual(accepted, 2)
        let progress = try await firstRepositories.checkIns.progress(taskID: id, on: now)
        XCTAssertEqual(progress.completed, 2)
    }

    func testTemporarySQLiteUsesUniqueTaskIDsAndPersistsFiles() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("sqlite-tests-\(UUID().uuidString)", isDirectory: true)
        let persistence = PersistenceController.temporarySQLite(at: directory)
        let model = persistence.container.managedObjectModel
        let taskEntity = try XCTUnwrap(model.entitiesByName["TaskEntity"])
        XCTAssertEqual(taskEntity.uniquenessConstraints.first as? [String], ["id"])
        let indexedProperties = taskEntity.indexes
            .flatMap(\.elements)
            .compactMap { $0.property?.name }
        XCTAssertTrue(indexedProperties.contains("id"))

        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        _ = try await repositories.tasks.create(TaskDraft(title: "SQLite"))
        let storeURL = try XCTUnwrap(persistence.storeURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testV1StoreMigratesToV2WithDefaults() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("CheckIn.sqlite")
        let taskID = UUID()
        try createV1Store(at: storeURL, taskID: taskID)

        let migrated = PersistenceController(storeURL: storeURL)
        let context = migrated.container.viewContext
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", taskID as CVarArg)
        let task = try XCTUnwrap(context.fetch(request).first)
        XCTAssertEqual(task.category, HabitCategory.learning.rawValue)
        XCTAssertEqual(task.priority, TaskPriority.normal.rawValue)
        XCTAssertNil(task.planRevisionsData)
        XCTAssertNil(task.pauseIntervalsData)
    }

    func testDeepLinksAndWidgetSnapshotFailureModes() throws {
        let id = UUID()
        XCTAssertEqual(DeepLinkRouter().parse(URL(string: "checkin://today")!), .today)
        XCTAssertEqual(DeepLinkRouter().parse(URL(string: "checkin://task/\(id)")!), .task(id))
        XCTAssertNil(DeepLinkRouter().parse(URL(string: "https://example.com")!))

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = AppGroupWidgetSnapshotStore(containerURL: directory)
        XCTAssertEqual(store.load(now: now), .missing)

        let snapshot = WidgetSnapshot(
            generatedAt: now,
            usableThrough: calendar.date(byAdding: .day, value: 1, to: now)!,
            dayKey: WidgetDayKey.string(from: now, calendar: calendar),
            tasks: []
        )
        try store.save(snapshot)
        XCTAssertEqual(store.load(now: now), .available(snapshot))
        XCTAssertEqual(store.load(now: calendar.date(byAdding: .day, value: 2, to: now)!), .expired)
    }

    func testNotificationRequestIdentifiersAndWeekdaysAreStable() throws {
        var task = makeTask(schedule: .custom([.monday, .wednesday]))
        task.reminderEnabled = true
        task.reminderHour = 9
        task.reminderMinute = 15
        let requests = NotificationRequestFactory(calendar: calendar).requests(for: task)

        XCTAssertEqual(
            requests.map(\.identifier),
            ["task.\(task.id.uuidString).weekday.2", "task.\(task.id.uuidString).weekday.4"]
        )
        let triggers = try requests.map { request in
            try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
        }
        XCTAssertEqual(triggers.map { $0.dateComponents.hour }, [9, 9])
        XCTAssertEqual(triggers.map { $0.dateComponents.minute }, [15, 15])
        XCTAssertEqual(triggers.map { $0.dateComponents.weekday }, [2, 4])
        XCTAssertTrue(triggers.allSatisfy(\.repeats))
    }

    func testDailyNotificationUsesOneRepeatingRequest() throws {
        var task = makeTask(schedule: .daily)
        task.reminderEnabled = true
        task.reminderHour = 21
        task.reminderMinute = 5
        let request = try XCTUnwrap(NotificationRequestFactory(calendar: calendar).requests(for: task).first)
        let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)

        XCTAssertEqual(request.identifier, "task.\(task.id.uuidString).dailyReminder")
        XCTAssertEqual(trigger.dateComponents.hour, 21)
        XCTAssertEqual(trigger.dateComponents.minute, 5)
        XCTAssertNil(trigger.dateComponents.weekday)
        XCTAssertTrue(trigger.repeats)
    }

    func testWidgetSnapshotCapsTasksAndResetsCountsAcrossMidnight() {
        let tasks = (0..<24).map { index in
            WidgetTaskSnapshot(
                id: UUID(),
                title: "习惯 \(index) 🚀",
                symbolName: "star.fill",
                colorHex: "#7C3AED",
                sortOrder: index,
                dailyGoal: 2,
                completedCount: 2,
                schedule: WidgetSchedule(kind: .daily, startDayKey: "2026-08-01")
            )
        }
        let snapshot = WidgetSnapshot(
            generatedAt: now,
            usableThrough: date(2026, 8, 27),
            dayKey: "2026-08-19",
            tasks: tasks
        )
        XCTAssertEqual(snapshot.tasks.count, 24)
        XCTAssertEqual(snapshot.progress(on: now, calendar: calendar).completed, 48)
        XCTAssertEqual(snapshot.progress(on: date(2026, 8, 20), calendar: calendar).completed, 0)
        XCTAssertEqual(snapshot.progress(on: date(2026, 8, 20), calendar: calendar).goal, 48)
    }

    func testWidgetPendingCheckInStoreCapsDuplicatesAndRemovesConsumedActions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-actions-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = AppGroupWidgetPendingCheckInStore(containerURL: directory)
        let taskID = UUID()
        let first = WidgetPendingCheckIn(id: UUID(), taskID: taskID, occurredAt: now)
        let second = WidgetPendingCheckIn(id: UUID(), taskID: taskID, occurredAt: now)

        XCTAssertTrue(try store.enqueue(first, maximumPendingForTask: 1))
        XCTAssertFalse(try store.enqueue(first, maximumPendingForTask: 1))
        XCTAssertFalse(try store.enqueue(second, maximumPendingForTask: 1))
        XCTAssertEqual(try store.load(), [first])

        try store.remove(ids: [first.id])
        XCTAssertTrue(try store.load().isEmpty)
    }

    func testFocusedWidgetSelectionRequiresChoiceOnlyWhenMultipleHabitsExist() {
        let first = WidgetTaskSnapshot(
            id: UUID(),
            title: "阅读",
            symbolName: "book.fill",
            colorHex: "#7C3AED",
            sortOrder: 0,
            dailyGoal: 1,
            completedCount: 0,
            schedule: WidgetSchedule(kind: .daily)
        )
        var second = first
        second.id = UUID()
        second.title = "喝水"
        second.sortOrder = 1

        let empty = WidgetSnapshot(usableThrough: now, dayKey: "2026-08-19", tasks: [])
        let single = WidgetSnapshot(usableThrough: now, dayKey: "2026-08-19", tasks: [first])
        let multiple = WidgetSnapshot(usableThrough: now, dayKey: "2026-08-19", tasks: [first, second])

        XCTAssertEqual(empty.focusedTask(selectedIdentifier: nil), .noHabits)
        XCTAssertEqual(single.focusedTask(selectedIdentifier: nil), .task(first))
        XCTAssertEqual(multiple.focusedTask(selectedIdentifier: nil), .chooseHabit)
        XCTAssertEqual(multiple.focusedTask(selectedIdentifier: second.id.uuidString), .task(second))
        XCTAssertEqual(multiple.focusedTask(selectedIdentifier: UUID().uuidString), .invalidSelection)
    }

    func testWidgetTaskSnapshotDecodesMissingStreakAsZero() throws {
        let json = """
        {
          "id": "22F3BBD6-81B4-4874-977A-57BE2EFC8101",
          "title": "阅读",
          "symbolName": "book.fill",
          "colorHex": "#7C3AED",
          "sortOrder": 0,
          "dailyGoal": 1,
          "completedCount": 0,
          "isPaused": false,
          "schedule": { "kind": "daily", "weekdays": [] }
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(WidgetTaskSnapshot.self, from: json)
        XCTAssertEqual(decoded.currentStreak, 0)
        XCTAssertEqual(decoded.dailyGoal, 1)
    }

    func testWidgetTaskPersistedDaysCountsFromStartDayInclusive() {
        let task = WidgetTaskSnapshot(
            id: UUID(),
            title: "阅读",
            symbolName: "book.fill",
            colorHex: "#7C3AED",
            sortOrder: 0,
            dailyGoal: 1,
            completedCount: 0,
            schedule: WidgetSchedule(kind: .daily, startDayKey: "2026-08-01")
        )
        XCTAssertEqual(task.persistedDays(on: date(2026, 8, 1), calendar: calendar), 1)
        XCTAssertEqual(task.persistedDays(on: date(2026, 8, 21), calendar: calendar), 21)
    }

    func testAppImportsWidgetQueueOnceAndRemovesIt() async throws {
        let persistence = PersistenceController(inMemory: true)
        let repositories = CoreDataRepositories(
            persistence: persistence,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        let taskID = try await repositories.tasks.create(TaskDraft(title: "喝水", dailyTarget: 3))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-import-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pendingStore = AppGroupWidgetPendingCheckInStore(containerURL: directory)
        let action = WidgetPendingCheckIn(id: UUID(), taskID: taskID, occurredAt: now)
        XCTAssertTrue(try pendingStore.enqueue(action, maximumPendingForTask: 3))

        let store = AppStore(
            tasks: repositories.tasks,
            checkIns: repositories.checkIns,
            widgetPendingCheckIns: pendingStore,
            dateProvider: FixedDateProvider(now),
            calendar: calendar
        )
        await store.load()
        XCTAssertEqual(store.todayProgress[taskID]?.completed, 1)
        XCTAssertTrue(try pendingStore.load().isEmpty)

        XCTAssertTrue(try pendingStore.enqueue(action, maximumPendingForTask: 3))
        await store.load()
        XCTAssertEqual(store.todayProgress[taskID]?.completed, 1)
        XCTAssertTrue(try pendingStore.load().isEmpty)
    }

    func testWidgetSnapshotRejectsCorruptionAndFutureVersions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-corruption-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent(CheckInSharedConstants.snapshotFileName)
        let store = AppGroupWidgetSnapshotStore(containerURL: directory)

        try Data("not-json".utf8).write(to: fileURL)
        XCTAssertEqual(store.load(now: now), .corrupted)

        let futureJSON = "{\"version\":999}"
        try Data(futureJSON.utf8).write(to: fileURL)
        XCTAssertEqual(store.load(now: now), .unsupportedVersion)
    }

    private func makeTask(
        schedule: TaskSchedule,
        dailyTarget: Int = 1,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> TaskDTO {
        TaskDTO(
            id: UUID(),
            title: "测试习惯",
            note: "",
            category: .learning,
            iconKey: "star.fill",
            colorHex: "#7C3AED",
            priority: .normal,
            sortOrder: 0,
            schedule: schedule,
            dailyTarget: dailyTarget,
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            startDate: startDate,
            endDate: endDate,
            createdAt: startDate ?? date(2026, 1, 1),
            updatedAt: now,
            lastCheckInAt: nil,
            isArchived: false
        )
    }

    private func makeCheckIn(task: TaskDTO, date: Date, value: Int = 1) -> CheckInDTO {
        CheckInDTO(
            id: UUID(),
            taskID: task.id,
            occurredAt: date,
            dayKey: DayKey(date: date, calendar: calendar).rawValue,
            value: value,
            source: .app,
            createdAt: date
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 10))!
    }

    private func createV1Store(at storeURL: URL, taskID: UUID) throws {
        let model = PersistenceController.loadManagedObjectModel(version: "CheckInModelV1")
        let container = NSPersistentContainer(name: "CheckInModel", managedObjectModel: model)
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]
        var loadError: Error?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        let task = NSEntityDescription.insertNewObject(forEntityName: "TaskEntity", into: container.viewContext)
        task.setValue(taskID, forKey: "id")
        task.setValue("迁移任务", forKey: "title")
        task.setValue("#A788FA", forKey: "colorHex")
        task.setValue(now, forKey: "createdAt")
        task.setValue(1, forKey: "dailyTarget")
        task.setValue("star.fill", forKey: "iconKey")
        task.setValue(false, forKey: "isArchived")
        task.setValue(false, forKey: "reminderEnabled")
        task.setValue(TaskScheduleType.daily.rawValue, forKey: "scheduleType")
        task.setValue(0, forKey: "sortOrder")
        task.setValue(now, forKey: "updatedAt")
        task.setValue(127, forKey: "weekdaysMask")
        try container.viewContext.save()

        for store in container.persistentStoreCoordinator.persistentStores {
            try container.persistentStoreCoordinator.remove(store)
        }
    }
}
