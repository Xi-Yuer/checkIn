import Foundation

enum HabitCategory: Int16, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case learning
    case exercise
    case life
    case other

    var id: Int16 { rawValue }

    var title: String {
        switch self {
        case .learning: L10n.text("学习")
        case .exercise: L10n.text("运动")
        case .life: L10n.text("生活")
        case .other: L10n.text("其他")
        }
    }

    var symbolName: String {
        switch self {
        case .learning: "book.fill"
        case .exercise: "figure.run"
        case .life: "house.fill"
        case .other: "sparkles"
        }
    }
}

enum TaskPriority: Int16, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case low
    case normal
    case high
    case urgent

    var id: Int16 { rawValue }

    var title: String {
        switch self {
        case .low: L10n.text("低")
        case .normal: L10n.text("普通")
        case .high: L10n.text("高")
        case .urgent: L10n.text("紧急")
        }
    }
}

enum Weekday: Int16, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case sunday = 1
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday

    var id: Int16 { rawValue }

    var shortTitle: String {
        switch self {
        case .monday: L10n.text("周一缩写")
        case .tuesday: L10n.text("周二缩写")
        case .wednesday: L10n.text("周三缩写")
        case .thursday: L10n.text("周四缩写")
        case .friday: L10n.text("周五缩写")
        case .saturday: L10n.text("周六缩写")
        case .sunday: L10n.text("周日缩写")
        }
    }

    fileprivate var bit: Int16 { 1 << (rawValue - 1) }
}

enum TaskScheduleType: Int16, Codable, Sendable {
    case daily
    case weekdays
    case custom
    case specificDates
}

enum SpecificDateRecurrence: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case once
    case yearly

    var id: String { rawValue }
    var title: String { self == .once ? L10n.text("仅一次") : L10n.text("每年") }
}

struct TaskSpecificDate: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var dayKey: String
    var recurrence: SpecificDateRecurrence

    init(id: UUID = UUID(), date: Date, recurrence: SpecificDateRecurrence = .once, calendar: Calendar = .autoupdatingCurrent) {
        self.id = id
        dayKey = DayKey(date: date, calendar: calendar).rawValue
        self.recurrence = recurrence
    }
}

enum TaskSchedule: Codable, Hashable, Sendable {
    case daily
    case weekdays
    case custom(Set<Weekday>)
    case specificDates([TaskSpecificDate], countdownDays: Int)

    var type: TaskScheduleType {
        switch self {
        case .daily: .daily
        case .weekdays: .weekdays
        case .custom: .custom
        case .specificDates: .specificDates
        }
    }

    var weekdaysMask: Int16 {
        switch self {
        case .daily:
            Weekday.allCases.reduce(0) { $0 | $1.bit }
        case .weekdays:
            Set([Weekday.monday, .tuesday, .wednesday, .thursday, .friday])
                .reduce(0) { $0 | $1.bit }
        case let .custom(days):
            days.reduce(0) { $0 | $1.bit }
        case .specificDates:
            0
        }
    }

    var selectedWeekdays: Set<Weekday> {
        switch self {
        case .daily:
            Set(Weekday.allCases)
        case .weekdays:
            Set([.monday, .tuesday, .wednesday, .thursday, .friday])
        case let .custom(days):
            days
        case .specificDates:
            []
        }
    }

    init(type: TaskScheduleType, weekdaysMask: Int16, specificDates: [TaskSpecificDate] = [], countdownDays: Int = 7) {
        switch type {
        case .daily:
            self = .daily
        case .weekdays:
            self = .weekdays
        case .custom:
            self = .custom(Set(Weekday.allCases.filter { weekdaysMask & $0.bit != 0 }))
        case .specificDates:
            self = .specificDates(specificDates, countdownDays: max(1, min(30, countdownDays)))
        }
    }

    func includes(_ weekday: Weekday) -> Bool {
        selectedWeekdays.contains(weekday)
    }

    var specificDateEntries: [TaskSpecificDate] {
        guard case let .specificDates(entries, _) = self else { return [] }
        return entries
    }

    var countdownDays: Int {
        guard case let .specificDates(_, days) = self else { return 7 }
        return max(1, min(30, days))
    }
}

struct TaskPlanRevision: Codable, Hashable, Sendable {
    let effectiveDayKey: String
    let schedule: TaskSchedule
    let dailyTarget: Int
    let startDayKey: String?
    let endDayKey: String?
}

struct TaskPauseInterval: Codable, Hashable, Sendable {
    let startDayKey: String
    var endDayKey: String?

    func contains(_ dayKey: String) -> Bool {
        guard dayKey >= startDayKey else { return false }
        return endDayKey.map { dayKey < $0 } ?? true
    }
}

enum TaskFilter: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case all
    case active
    case ended
    case paused
    case pendingToday
    case completedToday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.text("全部")
        case .active: L10n.text("进行中")
        case .ended: L10n.text("已结束")
        case .paused: L10n.text("已暂停")
        case .pendingToday: L10n.text("待完成")
        case .completedToday: L10n.text("已完成")
        }
    }
}

enum TaskSort: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case manual
    case priority
    case createdAt
    case streak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: L10n.text("手动")
        case .priority: L10n.text("优先级")
        case .createdAt: L10n.text("创建时间")
        case .streak: L10n.text("连续天数")
        }
    }
}

enum CheckInSource: Int16, Codable, Hashable, Sendable {
    case app
    case widget
    case imported
    case automatic
}

struct TaskDraft: Equatable, Sendable {
    var title: String = ""
    var note: String = ""
    var category: HabitCategory = .learning
    var iconKey: String = HabitIconCatalog.defaultAssetName
    var colorHex: String = "#A788FA"
    var priority: TaskPriority = .normal
    var schedule: TaskSchedule = .daily
    var dailyTarget: Int = 1
    var autoCheckInEnabled: Bool = false
    var reminderEnabled: Bool = false
    var reminderHour: Int? = nil
    var reminderMinute: Int? = nil
    var startDate: Date? = nil
    var endDate: Date? = nil

    init(
        title: String = "",
        note: String = "",
        category: HabitCategory = .learning,
        iconKey: String = HabitIconCatalog.defaultAssetName,
        colorHex: String = "#A788FA",
        priority: TaskPriority = .normal,
        schedule: TaskSchedule = .daily,
        dailyTarget: Int = 1,
        autoCheckInEnabled: Bool = false,
        reminderEnabled: Bool = false,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) {
        self.title = title
        self.note = note
        self.category = category
        self.iconKey = iconKey
        self.colorHex = colorHex
        self.priority = priority
        self.schedule = schedule
        self.dailyTarget = dailyTarget
        self.autoCheckInEnabled = autoCheckInEnabled
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.startDate = startDate
        self.endDate = endDate
    }

    func validated(calendar: Calendar = .autoupdatingCurrent) throws -> TaskDraft {
        var copy = self
        copy.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.note = note.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !copy.title.isEmpty else { throw TaskValidationError.emptyTitle }
        guard copy.title.count <= 40 else { throw TaskValidationError.titleTooLong }
        guard copy.note.count <= 500 else { throw TaskValidationError.noteTooLong }
        guard (1...99).contains(copy.dailyTarget) else { throw TaskValidationError.invalidDailyTarget }
        guard !copy.iconKey.isEmpty else { throw TaskValidationError.emptyIcon }
        guard Self.isValidHexColor(copy.colorHex) else { throw TaskValidationError.invalidColor }

        if case let .custom(days) = copy.schedule, days.isEmpty {
            throw TaskValidationError.emptyCustomSchedule
        }
        if case let .specificDates(entries, countdownDays) = copy.schedule {
            guard !entries.isEmpty else { throw TaskValidationError.emptySpecificDates }
            guard entries.count <= 20 else { throw TaskValidationError.tooManySpecificDates }
            guard (1...30).contains(countdownDays) else { throw TaskValidationError.invalidSpecificDateCountdown }
            let keys = entries.map { entry in
                entry.recurrence == .once
                    ? "once:\(entry.dayKey)"
                    : "yearly:\(entry.dayKey.dropFirst(5))"
            }
            guard Set(keys).count == keys.count else { throw TaskValidationError.duplicateSpecificDates }
        }

        if let startDate = copy.startDate, let endDate = copy.endDate,
           calendar.startOfDay(for: endDate) < calendar.startOfDay(for: startDate) {
            throw TaskValidationError.endBeforeStart
        }

        if copy.reminderEnabled {
            guard let hour = copy.reminderHour, (0...23).contains(hour),
                  let minute = copy.reminderMinute, (0...59).contains(minute) else {
                throw TaskValidationError.invalidReminderTime
            }
        }

        copy.colorHex = copy.colorHex.uppercased()
        return copy
    }

    private static func isValidHexColor(_ value: String) -> Bool {
        let pattern = "^#[0-9A-Fa-f]{6}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

enum TaskValidationError: LocalizedError, Equatable {
    case emptyTitle
    case titleTooLong
    case noteTooLong
    case invalidDailyTarget
    case emptyIcon
    case invalidColor
    case emptyCustomSchedule
    case endBeforeStart
    case invalidReminderTime
    case emptySpecificDates
    case tooManySpecificDates
    case duplicateSpecificDates
    case invalidSpecificDateCountdown

    var errorDescription: String? {
        switch self {
        case .emptyTitle: L10n.text("请输入习惯名称")
        case .titleTooLong: L10n.text("习惯名称不能超过 40 个字")
        case .noteTooLong: L10n.text("备注不能超过 500 个字")
        case .invalidDailyTarget: L10n.text("每日目标需在 1 到 99 之间")
        case .emptyIcon: L10n.text("请选择图标")
        case .invalidColor: L10n.text("请选择有效颜色")
        case .emptyCustomSchedule: L10n.text("自定义频率至少选择一天")
        case .endBeforeStart: L10n.text("结束日期不能早于开始日期")
        case .invalidReminderTime: L10n.text("请选择有效提醒时间")
        case .emptySpecificDates: L10n.text("请至少添加一个指定日期")
        case .tooManySpecificDates: L10n.text("每个计划最多添加 20 个指定日期")
        case .duplicateSpecificDates: L10n.text("指定日期不能重复")
        case .invalidSpecificDateCountdown: L10n.text("提前展示天数需在 1 到 30 天之间")
        }
    }
}

struct TaskPatch: Equatable, Sendable {
    var draft: TaskDraft

    init(draft: TaskDraft) {
        self.draft = draft
    }
}

struct TaskDTO: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var note: String
    var category: HabitCategory
    var iconKey: String
    var colorHex: String
    var priority: TaskPriority
    var sortOrder: Int
    var schedule: TaskSchedule
    var dailyTarget: Int
    var autoCheckInEnabled: Bool
    var autoCheckInStartDayKey: String?
    var autoCheckInLastProcessedDayKey: String?
    var reminderEnabled: Bool
    var reminderHour: Int?
    var reminderMinute: Int?
    var startDate: Date?
    var endDate: Date?
    var createdAt: Date
    var updatedAt: Date
    var lastCheckInAt: Date?
    var isArchived: Bool
    var createdDayKey: String? = nil
    var planRevisions: [TaskPlanRevision] = []
    var pauseIntervals: [TaskPauseInterval] = []

    var draft: TaskDraft {
        TaskDraft(
            title: title,
            note: note,
            category: category,
            iconKey: iconKey,
            colorHex: colorHex,
            priority: priority,
            schedule: schedule,
            dailyTarget: dailyTarget,
            autoCheckInEnabled: autoCheckInEnabled,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            startDate: startDate,
            endDate: endDate
        )
    }
}

struct CheckInDTO: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let taskID: UUID
    let occurredAt: Date
    let dayKey: String
    let value: Int
    let source: CheckInSource
    let createdAt: Date
}

struct DailyProgress: Codable, Equatable, Sendable {
    let taskID: UUID
    let date: Date
    let completed: Int
    let target: Int

    var isComplete: Bool { completed >= target }
    var remaining: Int { max(0, target - completed) }
    var fractionComplete: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(completed) / Double(target))
    }
}

struct TaskQuery: Sendable {
    var filter: TaskFilter
    var sort: TaskSort
    var date: Date
    var searchText: String

    init(
        filter: TaskFilter = .all,
        sort: TaskSort = .manual,
        date: Date = Date(),
        searchText: String = ""
    ) {
        self.filter = filter
        self.sort = sort
        self.date = date
        self.searchText = searchText
    }
}

enum RepositoryError: LocalizedError, Equatable {
    case taskNotFound
    case taskPaused
    case notScheduled
    case targetAlreadyReached
    case noCheckInToUndo
    case invalidValue
    case persistence(String)

    var errorDescription: String? {
        switch self {
        case .taskNotFound: L10n.text("这个习惯已不存在")
        case .taskPaused: L10n.text("已暂停的习惯不能打卡")
        case .notScheduled: L10n.text("今天不是这个习惯的计划日")
        case .targetAlreadyReached: L10n.text("今天的目标已经完成")
        case .noCheckInToUndo: L10n.text("今天没有可撤销的打卡")
        case .invalidValue: L10n.text("打卡数值必须大于零")
        case let .persistence(message): message
        }
    }
}
