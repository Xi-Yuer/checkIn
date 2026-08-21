import Combine
import Foundation

struct AppStoreError: Identifiable, Equatable, Sendable {
    let id = UUID()
    let message: String

    init(_ error: Error) {
        message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    init(message: String) {
        self.message = message
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var habits: [TaskDTO] = []
    @Published private(set) var todayProgress: [UUID: DailyProgress] = [:]
    @Published private(set) var habitStreaks: [UUID: Int] = [:]
    @Published private(set) var checkIns: [CheckInDTO] = []
    @Published private(set) var statistics: StatisticsSummary
    @Published private(set) var notificationStatus: NotificationAuthorizationStatus = .notDetermined
    @Published private(set) var isLoading = false
    @Published private(set) var processingHabitIDs: Set<UUID> = []
    @Published private(set) var error: AppStoreError?
    @Published var celebrationHabit: TaskDTO?
    @Published var route: DeepLinkDestination?
    @Published var searchText = ""
    @Published var habitFilter: TaskFilter
    @Published var habitSort: TaskSort
    @Published var statisticsPeriod: StatisticsPeriod = .week
    @Published var statisticsAnchor: Date
    @Published private(set) var settings: AppSettings

    private let tasks: any TaskRepository
    private let checkInRepository: any CheckInRepository
    private let notificationScheduler: any NotificationScheduling
    private let snapshotBuilder: any WidgetSnapshotBuilding
    private let settingsStore: any SettingsStoring
    private let dateProvider: any DateProvider
    private let calendar: Calendar
    private let deepLinkRouter = DeepLinkRouter()
    private let scheduleService = TaskScheduleService()

    var today: Date { dateProvider.now }

    var filteredHabits: [TaskDTO] {
        let day = calendar.startOfDay(for: today)
        let search = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return habits.filter { habit in
            let matchesSearch = search.isEmpty ||
                habit.title.localizedCaseInsensitiveContains(search) ||
                habit.note.localizedCaseInsensitiveContains(search)
            guard matchesSearch else { return false }
            let ended = habit.endDate.map { calendar.startOfDay(for: $0) < day } ?? false
            switch habitFilter {
            case .all: return true
            case .active: return !habit.isArchived && !ended
            case .ended: return !habit.isArchived && ended
            case .paused: return habit.isArchived
            case .pendingToday:
                return isScheduledToday(habit) && !(todayProgress[habit.id]?.isComplete ?? false)
            case .completedToday:
                return isScheduledToday(habit) && (todayProgress[habit.id]?.isComplete ?? false)
            }
        }
    }

    var todayHabits: [TaskDTO] {
        habits.filter(isScheduledToday)
    }

    var pendingTodayHabits: [TaskDTO] {
        todayHabits.filter { !(todayProgress[$0.id]?.isComplete ?? false) }
    }

    var completedTodayHabits: [TaskDTO] {
        todayHabits.filter { todayProgress[$0.id]?.isComplete ?? false }
    }

    var overallTodayProgress: Double {
        guard !todayHabits.isEmpty else { return 0 }
        let completed = completedTodayHabits.count
        return Double(completed) / Double(todayHabits.count)
    }

    convenience init() {
        let dateProvider = SystemDateProvider()
        let repositories = CoreDataRepositories(dateProvider: dateProvider)
        let settingsStore = UserDefaultsSettingsStore()
        let snapshotBuilder = DefaultWidgetSnapshotBuilder(
            tasks: repositories.tasks,
            checkIns: repositories.checkIns,
            store: AppGroupWidgetSnapshotStore(),
            sortProvider: { settingsStore.load().taskSort }
        )
        self.init(
            tasks: repositories.tasks,
            checkIns: repositories.checkIns,
            notificationScheduler: UserNotificationScheduler(),
            snapshotBuilder: snapshotBuilder,
            settingsStore: settingsStore,
            dateProvider: dateProvider
        )
    }

    init(
        tasks: any TaskRepository,
        checkIns: any CheckInRepository,
        notificationScheduler: any NotificationScheduling = DisabledNotificationScheduler(),
        snapshotBuilder: any WidgetSnapshotBuilding = DisabledWidgetSnapshotBuilder(),
        settingsStore: any SettingsStoring = InMemorySettingsStore(),
        dateProvider: any DateProvider = SystemDateProvider(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.tasks = tasks
        checkInRepository = checkIns
        self.notificationScheduler = notificationScheduler
        self.snapshotBuilder = snapshotBuilder
        self.settingsStore = settingsStore
        self.dateProvider = dateProvider
        self.calendar = calendar

        let loadedSettings = settingsStore.load()
        L10n.setLanguage(loadedSettings.appLanguage)
        settings = loadedSettings
        habitFilter = loadedSettings.taskFilter
        habitSort = loadedSettings.taskSort
        let now = dateProvider.now
        statisticsAnchor = now
        statistics = .empty(period: .week, date: now, calendar: calendar)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await reloadCoreState()
            notificationStatus = await notificationScheduler.authorizationStatus()
            try await notificationScheduler.reconcile(tasks: habits, now: today)
            await rebuildSnapshotIgnoringFailure()
        } catch {
            present(error)
        }
    }

    @discardableResult
    func saveHabit(_ draft: TaskDraft, id: UUID? = nil) async -> UUID? {
        do {
            let validated = try draft.validated(calendar: calendar)
            let taskID: UUID
            if let id {
                try await tasks.update(id: id, draft: validated)
                taskID = id
            } else {
                taskID = try await tasks.create(validated)
            }

            if validated.reminderEnabled {
                try await requestNotificationPermissionIfNeeded()
            }
            try await reloadCoreState()
            try await notificationScheduler.reconcile(tasks: habits, now: today)
            await rebuildSnapshotIgnoringFailure()
            return taskID
        } catch {
            present(error)
            return nil
        }
    }

    @discardableResult
    func createHabit(_ draft: TaskDraft) async -> UUID? {
        await saveHabit(draft)
    }

    func updateHabit(id: UUID, draft: TaskDraft) async {
        _ = await saveHabit(draft, id: id)
    }

    @discardableResult
    func checkIn(habitID: UUID) async -> DailyProgress? {
        guard !processingHabitIDs.contains(habitID) else { return nil }
        processingHabitIDs.insert(habitID)
        defer { processingHabitIDs.remove(habitID) }
        do {
            let progress = try await checkInRepository.checkIn(
                taskID: habitID,
                at: today,
                value: 1,
                source: .app
            )
            todayProgress[habitID] = progress
            if progress.isComplete {
                celebrationHabit = habits.first { $0.id == habitID }
            }
            await refreshStreak(for: habitID)
            try await reloadDerivedState()
            await rebuildSnapshotIgnoringFailure()
            return progress
        } catch RepositoryError.targetAlreadyReached {
            return todayProgress[habitID]
        } catch {
            present(error)
            return nil
        }
    }

    @discardableResult
    func undoLastCheckIn(habitID: UUID) async -> DailyProgress? {
        guard !processingHabitIDs.contains(habitID) else { return nil }
        processingHabitIDs.insert(habitID)
        defer { processingHabitIDs.remove(habitID) }
        do {
            let progress = try await checkInRepository.undoLastCheckIn(taskID: habitID, on: today)
            todayProgress[habitID] = progress
            celebrationHabit = nil
            await refreshStreak(for: habitID)
            try await reloadDerivedState()
            await rebuildSnapshotIgnoringFailure()
            return progress
        } catch {
            present(error)
            return nil
        }
    }

    func pauseHabit(id: UUID) async {
        do {
            try await tasks.archive(id: id)
            await notificationScheduler.remove(taskID: id)
            try await reloadCoreState()
            await rebuildSnapshotIgnoringFailure()
        } catch {
            present(error)
        }
    }

    func resumeHabit(id: UUID) async {
        do {
            try await tasks.unarchive(id: id)
            try await reloadCoreState()
            try await notificationScheduler.reconcile(tasks: habits, now: today)
            await rebuildSnapshotIgnoringFailure()
        } catch {
            present(error)
        }
    }

    @discardableResult
    func deleteHabit(id: UUID) async -> Bool {
        do {
            await notificationScheduler.remove(taskID: id)
            _ = try await tasks.delete(id: id)
            try await reloadCoreState()
            await rebuildSnapshotIgnoringFailure()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func historyCount(for habitID: UUID) async -> Int {
        do {
            return try await checkInRepository.checkInCount(taskID: habitID)
        } catch {
            present(error)
            return 0
        }
    }

    func loadHistory(for habitID: UUID, interval: DateInterval? = nil) async {
        let defaultStart = calendar.date(byAdding: .year, value: -10, to: today) ?? .distantPast
        let defaultEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? .distantFuture
        do {
            checkIns = try await checkInRepository.history(
                taskID: habitID,
                range: interval ?? DateInterval(start: defaultStart, end: defaultEnd)
            )
        } catch {
            present(error)
        }
    }

    func updateManualOrder(_ orderedIDs: [UUID]) async {
        do {
            try await tasks.updateManualOrder(orderedIDs)
            try await reloadCoreState()
            await rebuildSnapshotIgnoringFailure()
        } catch {
            present(error)
        }
    }

    func refreshStatistics(period: StatisticsPeriod? = nil, anchor: Date? = nil) async {
        if let period { statisticsPeriod = period }
        if let anchor { statisticsAnchor = anchor }
        do {
            statistics = try await checkInRepository.statistics(
                period: statisticsPeriod,
                anchor: statisticsAnchor,
                now: today
            )
        } catch {
            present(error)
        }
    }

    func refreshNotifications() async {
        do {
            notificationStatus = await notificationScheduler.authorizationStatus()
            try await notificationScheduler.reconcile(tasks: habits, now: today)
        } catch {
            present(error)
        }
    }

    func handle(url: URL) async {
        route = await deepLinkRouter.resolve(url, tasks: tasks)
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        persistSettings()
    }

    func showOnboardingAgain() {
        settings.hasCompletedOnboarding = false
        persistSettings()
    }

    func setAppearance(_ appearance: AppAppearance) {
        settings.appearance = appearance
        persistSettings()
    }

    func setSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
        persistSettings()
    }

    func setHapticsEnabled(_ enabled: Bool) {
        settings.hapticsEnabled = enabled
        persistSettings()
    }

    func setLanguage(_ language: AppLanguage) {
        L10n.setLanguage(language)
        settings.language = language
        persistSettings()
    }

    func setHabitFilter(_ filter: TaskFilter) {
        habitFilter = filter
        settings.taskFilter = filter
        persistSettings()
    }

    func setHabitSort(_ sort: TaskSort) async {
        habitSort = sort
        settings.taskSort = sort
        persistSettings()
        do {
            habits = try await tasks.fetch(TaskQuery(filter: .all, sort: sort, date: today))
            await rebuildSnapshotIgnoringFailure()
        } catch {
            present(error)
        }
    }

    func dismissCelebration() {
        celebrationHabit = nil
    }

    func clearError() {
        error = nil
    }

    func habit(id: UUID) -> TaskDTO? {
        habits.first { $0.id == id }
    }

    private func reloadCoreState() async throws {
        habits = try await tasks.fetch(TaskQuery(filter: .all, sort: habitSort, date: today))
        todayProgress = try await checkInRepository.progresses(taskIDs: habits.map(\.id), on: today)
        await reloadHabitStreaks()
        try await reloadDerivedState()
    }

    private func reloadHabitStreaks() async {
        habitStreaks = (try? await checkInRepository.streaks(
            taskIDs: habits.map(\.id),
            through: today
        )) ?? [:]
    }

    private func refreshStreak(for habitID: UUID) async {
        habitStreaks[habitID] = (try? await checkInRepository.streak(taskID: habitID, through: today)) ?? 0
    }

    private func reloadDerivedState() async throws {
        statistics = try await checkInRepository.statistics(
            period: statisticsPeriod,
            anchor: statisticsAnchor,
            now: today
        )
    }

    private func requestNotificationPermissionIfNeeded() async throws {
        let status = await notificationScheduler.authorizationStatus()
        if status == .notDetermined {
            _ = try await notificationScheduler.requestAuthorization()
        }
        notificationStatus = await notificationScheduler.authorizationStatus()
    }

    private func rebuildSnapshotIgnoringFailure() async {
        _ = try? await snapshotBuilder.rebuild(for: today)
    }

    private func isScheduledToday(_ habit: TaskDTO) -> Bool {
        scheduleService.isScheduled(habit, on: today, calendar: calendar)
    }

    private func persistSettings() {
        settingsStore.save(settings)
    }

    private func present(_ error: Error) {
        self.error = AppStoreError(error)
    }
}
