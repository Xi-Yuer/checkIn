import Foundation

enum StatisticsPeriod: String, CaseIterable, Codable, Identifiable, Sendable {
    case week
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: L10n.text("周统计")
        case .month: L10n.text("月统计")
        case .year: L10n.text("年统计")
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
    let chartDaily: [DailyStatistic]

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
            daily: [],
            chartDaily: []
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
        case .system: L10n.text("跟随系统")
        case .light: L10n.text("浅色")
        case .dark: L10n.text("深色")
        }
    }
}

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: L10n.text("语言跟随系统")
        case .simplifiedChinese: L10n.text("简体中文")
        case .english: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }

    var localizationCode: String? {
        switch self {
        case .system: nil
        case .simplifiedChinese: "zh-Hans"
        case .english: "en"
        }
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var hapticsEnabled: Bool = true
    var appearance: AppAppearance = .system
    // Optional keeps settings saved by older app versions decodable.
    var language: AppLanguage? = nil
    // Optional keeps settings saved before the notification master switch decodable.
    var notificationsEnabled: Bool? = nil
    var taskFilter: TaskFilter = .all
    var taskSort: TaskSort = .manual

    static let `default` = AppSettings()

    var appLanguage: AppLanguage { language ?? .system }
    var areNotificationsEnabled: Bool { notificationsEnabled ?? true }
}
