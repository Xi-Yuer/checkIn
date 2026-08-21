import Foundation
import WidgetKit

protocol WidgetSnapshotBuilding: Sendable {
    @discardableResult
    func rebuild(for date: Date) async throws -> WidgetSnapshot
}

final class DefaultWidgetSnapshotBuilder: WidgetSnapshotBuilding, @unchecked Sendable {
    private let tasks: any TaskRepository
    private let checkIns: any CheckInRepository
    private let store: any WidgetSnapshotStore
    private let calendar: Calendar
    private let sortProvider: @Sendable () -> TaskSort

    init(
        tasks: any TaskRepository,
        checkIns: any CheckInRepository,
        store: any WidgetSnapshotStore,
        calendar: Calendar = .autoupdatingCurrent,
        sortProvider: @escaping @Sendable () -> TaskSort = { .manual }
    ) {
        self.tasks = tasks
        self.checkIns = checkIns
        self.store = store
        self.calendar = calendar
        self.sortProvider = sortProvider
    }

    func rebuild(for date: Date) async throws -> WidgetSnapshot {
        let fetchedTasks = try await tasks.fetch(
            TaskQuery(filter: .active, sort: sortProvider(), date: date)
        )
        let limitedTasks = Array(fetchedTasks.prefix(CheckInSharedConstants.maximumTaskCount))
        let progresses = try await checkIns.progresses(taskIDs: limitedTasks.map(\.id), on: date)
        let streaks = try await checkIns.streaks(taskIDs: limitedTasks.map(\.id), through: date)
        let scheduleService = TaskScheduleService()

        var taskSnapshots: [WidgetTaskSnapshot] = []
        for (index, task) in limitedTasks.enumerated() {
            let progress = progresses[task.id]
            let plan = scheduleService.plan(for: task, on: date, calendar: calendar)
            taskSnapshots.append(
                WidgetTaskSnapshot(
                    id: task.id,
                    title: task.title,
                    symbolName: task.iconKey,
                    colorHex: task.colorHex,
                    sortOrder: index,
                    dailyGoal: plan.dailyTarget,
                    completedCount: progress?.completed ?? 0,
                    isPaused: task.isArchived,
                    schedule: WidgetSchedule(
                        kind: plan.schedule.widgetKind,
                        weekdays: plan.schedule.selectedWeekdays.map { Int($0.rawValue) },
                        startDayKey: plan.startDayKey ?? task.createdDayKey,
                        endDayKey: plan.endDayKey
                    ),
                    currentStreak: streaks[task.id] ?? 0
                )
            )
        }

        let ordered = taskSnapshots.sorted {
            let lhsComplete = $0.completedCount >= $0.dailyGoal
            let rhsComplete = $1.completedCount >= $1.dailyGoal
            if lhsComplete != rhsComplete { return !lhsComplete }
            return $0.sortOrder < $1.sortOrder
        }
        let snapshot = WidgetSnapshot(
            version: CheckInSharedConstants.supportedSnapshotVersion,
            generatedAt: date,
            usableThrough: calendar.date(byAdding: .day, value: 8, to: date) ?? date,
            dayKey: WidgetDayKey.string(from: date, calendar: calendar),
            tasks: ordered
        )
        try store.save(snapshot)
        WidgetCenter.shared.reloadTimelines(ofKind: CheckInSharedConstants.widgetKind)
        WidgetCenter.shared.reloadTimelines(ofKind: CheckInSharedConstants.focusedWidgetKind)
        return snapshot
    }
}

struct DisabledWidgetSnapshotBuilder: WidgetSnapshotBuilding {
    func rebuild(for date: Date) async throws -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: date,
            usableThrough: date,
            dayKey: WidgetDayKey.string(from: date),
            tasks: []
        )
    }
}

private extension TaskSchedule {
    var widgetKind: WidgetFrequencyKind {
        switch self {
        case .daily: .daily
        case .weekdays: .weekdays
        case .custom: .custom
        }
    }
}
