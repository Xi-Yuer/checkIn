import Foundation

public struct WidgetPendingCheckIn: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let taskID: UUID
    public let occurredAt: Date

    public init(id: UUID = UUID(), taskID: UUID, occurredAt: Date = Date()) {
        self.id = id
        self.taskID = taskID
        self.occurredAt = occurredAt
    }
}

public enum WidgetPendingCheckInStoreError: Error, Equatable {
    case appGroupUnavailable
    case corrupted
    case coordinationFailed
}

public struct AppGroupWidgetPendingCheckInStore: @unchecked Sendable {
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

    public func load() throws -> [WidgetPendingCheckIn] {
        guard let fileURL else { throw WidgetPendingCheckInStoreError.appGroupUnavailable }
        var result: Result<[WidgetPendingCheckIn], Error> = .success([])
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { coordinatedURL in
            result = Result { try read(from: coordinatedURL) }
        }
        if coordinationError != nil { throw WidgetPendingCheckInStoreError.coordinationFailed }
        return try result.get()
    }

    @discardableResult
    public func enqueue(
        _ action: WidgetPendingCheckIn,
        maximumPendingForTask: Int
    ) throws -> Bool {
        guard maximumPendingForTask > 0 else { return false }
        return try mutate { actions in
            guard !actions.contains(where: { $0.id == action.id }) else { return false }
            let dayKey = WidgetDayKey.string(from: action.occurredAt)
            let pendingCount = actions.filter {
                $0.taskID == action.taskID && WidgetDayKey.string(from: $0.occurredAt) == dayKey
            }.count
            guard pendingCount < maximumPendingForTask else { return false }
            actions.append(action)
            return true
        }
    }

    public func remove(ids: Set<UUID>) throws {
        guard !ids.isEmpty else { return }
        _ = try mutate { actions in
            actions.removeAll { ids.contains($0.id) }
        }
    }

    public func pendingCount(taskID: UUID, on date: Date) throws -> Int {
        let dayKey = WidgetDayKey.string(from: date)
        return try load().filter {
            $0.taskID == taskID && WidgetDayKey.string(from: $0.occurredAt) == dayKey
        }.count
    }

    private func mutate<ResultValue>(
        _ change: (inout [WidgetPendingCheckIn]) throws -> ResultValue
    ) throws -> ResultValue {
        guard let fileURL, let containerURL else {
            throw WidgetPendingCheckInStoreError.appGroupUnavailable
        }
        var result: Result<ResultValue, Error>?
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        coordinator.coordinate(writingItemAt: containerURL, options: .forMerging, error: &coordinationError) { _ in
            result = Result {
                var actions = try read(from: fileURL)
                let value = try change(&actions)
                let data = try encoder.encode(actions)
                try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                return value
            }
        }
        if coordinationError != nil { throw WidgetPendingCheckInStoreError.coordinationFailed }
        guard let result else { throw WidgetPendingCheckInStoreError.coordinationFailed }
        return try result.get()
    }

    private func read(from url: URL) throws -> [WidgetPendingCheckIn] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard let actions = try? decoder.decode([WidgetPendingCheckIn].self, from: data) else {
            throw WidgetPendingCheckInStoreError.corrupted
        }
        return actions
    }

    private var fileURL: URL? {
        containerURL?.appendingPathComponent(CheckInSharedConstants.pendingActionsFileName)
    }
}
