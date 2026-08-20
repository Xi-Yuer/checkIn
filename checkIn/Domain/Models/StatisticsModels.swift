import Foundation

enum StatisticsPeriod: String, CaseIterable, Codable, Identifiable, Sendable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "周统计"
        case .month: "月统计"
        case .year: "年统计"
        }
    }
}

enum CompletionIntensity: Int, Codable, Comparable, Sendable {
    case none
    case partial
    case complete

    static func < (lhs: CompletionIntensity, rhs: CompletionIntensity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct DailyStatistic: Identifiable, Codable, Equatable, Sendable {
    var id: String { dayKey }
    let dayKey: String
    let date: Date
    let plannedTaskCount: Int
    let completedTaskCount: Int
    let progressedTaskCount: Int

    var completionRate: Double {
        guard plannedTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(plannedTaskCount)
    }

    var intensity: CompletionIntensity {
        if completedTaskCount == 0, progressedTaskCount == 0 { return .none }
        return completedTaskCount >= plannedTaskCount ? .complete : .partial
    }
}

struct StatisticsSummary: Codable, Equatable, Sendable {
    let period: StatisticsPeriod
    let interval: DateInterval
    let plannedTaskDays: Int
    let completedTaskDays: Int
    let currentStreak: Int
    let bestStreak: Int
    let daily: [DailyStatistic]

    var completionRate: Double {
        guard plannedTaskDays > 0 else { return 0 }
        return Double(completedTaskDays) / Double(plannedTaskDays)
    }

    static func empty(period: StatisticsPeriod, date: Date, calendar: Calendar = .autoupdatingCurrent) -> StatisticsSummary {
        let day = calendar.startOfDay(for: date)
        return StatisticsSummary(
            period: period,
            interval: DateInterval(start: day, end: day),
            plannedTaskDays: 0,
            completedTaskDays: 0,
            currentStreak: 0,
            bestStreak: 0,
            daily: []
        )
    }
}

enum AppAppearance: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var hasCompletedOnboarding: Bool = false
    var soundEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var appearance: AppAppearance = .system
    var taskFilter: TaskFilter = .all
    var taskSort: TaskSort = .manual

    static let `default` = AppSettings()
}
