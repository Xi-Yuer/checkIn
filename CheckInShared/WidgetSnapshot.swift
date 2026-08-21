import Foundation

public enum CheckInSharedConstants {
    public static let appGroupIdentifier = "group.com.xiaoyuer.checkIn"
    public static let widgetKind = "CheckInWidget"
    public static let focusedWidgetKind = "FocusedCheckInWidget"
    public static let snapshotFileName = "widget_snapshot_v1.json"
    public static let pendingActionsFileName = "widget_pending_checkins_v1.json"
    public static let carouselIndexKey = "widget.carouselIndex"
    public static let supportedSnapshotVersion = 1
    public static let maximumTaskCount = 200
    public static let maximumSnapshotBytes = 512 * 1_024
}

public enum WidgetFrequencyKind: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays
    case custom
}

public struct WidgetSchedule: Codable, Equatable, Sendable {
    public var kind: WidgetFrequencyKind
    public var weekdays: [Int]
    public var startDayKey: String?
    public var endDayKey: String?

    public init(
        kind: WidgetFrequencyKind,
        weekdays: [Int] = [],
        startDayKey: String? = nil,
        endDayKey: String? = nil
    ) {
        self.kind = kind
        self.weekdays = Array(Set(weekdays.filter { 1...7 ~= $0 })).sorted()
        self.startDayKey = startDayKey
        self.endDayKey = endDayKey
    }

    public func isScheduled(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Bool {
        let dayKey = WidgetDayKey.string(from: date, calendar: calendar)
        if let startDayKey, dayKey < startDayKey { return false }
        if let endDayKey, dayKey > endDayKey { return false }

        let weekday = calendar.component(.weekday, from: date)
        switch kind {
        case .daily:
            return true
        case .weekdays:
            return (2...6).contains(weekday)
        case .custom:
            return weekdays.contains(weekday)
        }
    }
}

public struct WidgetTaskSnapshot: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var symbolName: String
    public var colorHex: String
    public var sortOrder: Int
    public var dailyGoal: Int
    public var completedCount: Int
    public var isPaused: Bool
    public var schedule: WidgetSchedule
    public var currentStreak: Int

    public init(
        id: UUID,
        title: String,
        symbolName: String,
        colorHex: String,
        sortOrder: Int,
        dailyGoal: Int,
        completedCount: Int,
        isPaused: Bool = false,
        schedule: WidgetSchedule,
        currentStreak: Int = 0
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.dailyGoal = max(1, min(dailyGoal, 99))
        self.completedCount = max(0, completedCount)
        self.isPaused = isPaused
        self.schedule = schedule
        self.currentStreak = max(0, currentStreak)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        dailyGoal = try container.decode(Int.self, forKey: .dailyGoal)
        completedCount = try container.decode(Int.self, forKey: .completedCount)
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        schedule = try container.decode(WidgetSchedule.self, forKey: .schedule)
        currentStreak = try container.decodeIfPresent(Int.self, forKey: .currentStreak) ?? 0
    }

    public func count(on date: Date, snapshotDayKey: String, calendar: Calendar = .autoupdatingCurrent) -> Int {
        WidgetDayKey.string(from: date, calendar: calendar) == snapshotDayKey
            ? min(completedCount, dailyGoal)
            : 0
    }

    public func persistedDays(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> Int {
        guard let startKey = schedule.startDayKey,
              let start = WidgetDayKey.date(from: startKey, calendar: calendar) else {
            return 1
        }
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return max(1, days + 1)
    }
}

public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var version: Int
    public var generatedAt: Date
    public var usableThrough: Date
    public var dayKey: String
    public var tasks: [WidgetTaskSnapshot]

    public init(
        version: Int = CheckInSharedConstants.supportedSnapshotVersion,
        generatedAt: Date = Date(),
        usableThrough: Date,
        dayKey: String,
        tasks: [WidgetTaskSnapshot]
    ) {
        self.version = version
        self.generatedAt = generatedAt
        self.usableThrough = usableThrough
        self.dayKey = dayKey
        self.tasks = Array(tasks.prefix(CheckInSharedConstants.maximumTaskCount))
    }

    public func scheduledTasks(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> [WidgetTaskSnapshot] {
        tasks
            .filter { !$0.isPaused && $0.schedule.isScheduled(on: date, calendar: calendar) }
            .sorted { lhs, rhs in
                let lhsDone = lhs.count(on: date, snapshotDayKey: dayKey, calendar: calendar) >= lhs.dailyGoal
                let rhsDone = rhs.count(on: date, snapshotDayKey: dayKey, calendar: calendar) >= rhs.dailyGoal
                if lhsDone != rhsDone { return !lhsDone }
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    public func progress(on date: Date, calendar: Calendar = .autoupdatingCurrent) -> (completed: Int, goal: Int) {
        scheduledTasks(on: date, calendar: calendar).reduce(into: (0, 0)) { result, task in
            result.0 += task.count(on: date, snapshotDayKey: dayKey, calendar: calendar)
            result.1 += task.dailyGoal
        }
    }

    public func focusedTask(selectedIdentifier: String?) -> WidgetFocusedTaskResolution {
        let activeTasks = tasks
            .filter { !$0.isPaused }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        if let selectedIdentifier {
            guard let id = UUID(uuidString: selectedIdentifier),
                  let task = activeTasks.first(where: { $0.id == id }) else {
                return .invalidSelection
            }
            return .task(task)
        }
        if activeTasks.count == 1, let task = activeTasks.first { return .task(task) }
        return activeTasks.isEmpty ? .noHabits : .chooseHabit
    }
}

public enum WidgetFocusedTaskResolution: Equatable, Sendable {
    case task(WidgetTaskSnapshot)
    case chooseHabit
    case noHabits
    case invalidSelection
}

public enum WidgetSnapshotReadResult: Equatable, Sendable {
    case available(WidgetSnapshot)
    case missing
    case corrupted
    case unsupportedVersion
    case expired
}

public protocol WidgetSnapshotStore: Sendable {
    func load(now: Date) -> WidgetSnapshotReadResult
    func save(_ snapshot: WidgetSnapshot) throws
}

public enum WidgetSnapshotStoreError: Error, Equatable {
    case appGroupUnavailable
    case snapshotTooLarge
    case unsupportedVersion
}

public struct AppGroupWidgetSnapshotStore: WidgetSnapshotStore, Sendable {
    private struct VersionHeader: Decodable {
        let version: Int
    }

    private let containerURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(containerURL: URL? = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: CheckInSharedConstants.appGroupIdentifier
    )) {
        self.containerURL = containerURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load(now: Date = Date()) -> WidgetSnapshotReadResult {
        guard let fileURL else { return .missing }
        guard let data = try? Data(contentsOf: fileURL) else { return .missing }
        guard data.count <= CheckInSharedConstants.maximumSnapshotBytes else { return .corrupted }
        guard let header = try? decoder.decode(VersionHeader.self, from: data) else { return .corrupted }
        guard header.version == CheckInSharedConstants.supportedSnapshotVersion else {
            return .unsupportedVersion
        }
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else { return .corrupted }
        guard snapshot.usableThrough >= now else { return .expired }
        return .available(snapshot)
    }

    public func save(_ snapshot: WidgetSnapshot) throws {
        guard snapshot.version == CheckInSharedConstants.supportedSnapshotVersion else {
            throw WidgetSnapshotStoreError.unsupportedVersion
        }
        guard let fileURL else { throw WidgetSnapshotStoreError.appGroupUnavailable }

        var sanitized = snapshot
        sanitized.tasks = Array(snapshot.tasks.prefix(CheckInSharedConstants.maximumTaskCount))
        let data = try encoder.encode(sanitized)
        guard data.count <= CheckInSharedConstants.maximumSnapshotBytes else {
            throw WidgetSnapshotStoreError.snapshotTooLarge
        }
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    @discardableResult
    public func incrementCompletedCount(taskID: UUID, at date: Date) throws -> WidgetSnapshot? {
        guard let fileURL, let containerURL else { throw WidgetSnapshotStoreError.appGroupUnavailable }
        var result: Result<WidgetSnapshot?, Error>?
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: containerURL, options: .forMerging, error: &coordinationError) { _ in
            result = Result {
                guard let data = try? Data(contentsOf: fileURL),
                      var snapshot = try? decoder.decode(WidgetSnapshot.self, from: data),
                      snapshot.version == CheckInSharedConstants.supportedSnapshotVersion,
                      snapshot.dayKey == WidgetDayKey.string(from: date),
                      let index = snapshot.tasks.firstIndex(where: { $0.id == taskID }) else {
                    return nil
                }
                let task = snapshot.tasks[index]
                guard !task.isPaused,
                      task.schedule.isScheduled(on: date),
                      task.completedCount < task.dailyGoal else { return snapshot }
                snapshot.tasks[index].completedCount += 1
                if snapshot.tasks[index].completedCount >= task.dailyGoal {
                    snapshot.tasks[index].currentStreak += 1
                }
                let updatedData = try encoder.encode(snapshot)
                guard updatedData.count <= CheckInSharedConstants.maximumSnapshotBytes else {
                    throw WidgetSnapshotStoreError.snapshotTooLarge
                }
                try updatedData.write(
                    to: fileURL,
                    options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
                )
                return snapshot
            }
        }
        if coordinationError != nil { throw WidgetSnapshotStoreError.appGroupUnavailable }
        return try result?.get()
    }

    private var fileURL: URL? {
        containerURL?.appendingPathComponent(CheckInSharedConstants.snapshotFileName, isDirectory: false)
    }
}

public enum WidgetDayKey {
    public static func string(from date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    public static func date(from key: String, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

public enum CheckInDeepLink: Equatable, Sendable {
    case today
    case task(UUID)

    public var url: URL {
        switch self {
        case .today:
            return URL(string: "checkin://today")!
        case .task(let id):
            return URL(string: "checkin://task/\(id.uuidString)")!
        }
    }

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "checkin" else { return nil }
        switch url.host?.lowercased() {
        case "today":
            self = .today
        case "task":
            guard let rawID = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: rawID) else { return nil }
            self = .task(id)
        default:
            return nil
        }
    }
}
