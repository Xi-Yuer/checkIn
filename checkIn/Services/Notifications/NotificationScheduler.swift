import Foundation
import UserNotifications

enum NotificationAuthorizationStatus: String, Codable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized: self = .authorized
        case .provisional: self = .provisional
        case .ephemeral: self = .ephemeral
        @unknown default: self = .notDetermined
        }
    }

    var canSchedule: Bool {
        self == .authorized || self == .provisional || self == .ephemeral
    }
}

protocol NotificationScheduling: Sendable {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func reconcile(tasks: [TaskDTO], completedDayKeys: [UUID: Set<String>], now: Date) async throws
    func remove(taskID: UUID) async
    func removeAll() async
}

final class UserNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let identifierPrefix = "task."

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .autoupdatingCurrent
    ) {
        self.center = center
        self.calendar = calendar
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        return NotificationAuthorizationStatus(settings.authorizationStatus)
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func reconcile(tasks: [TaskDTO], completedDayKeys: [UUID: Set<String>], now: Date) async throws {
        let pending = await center.pendingNotificationRequests()
        let existingAppIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existingAppIDs)

        guard await authorizationStatus().canSchedule else { return }

        let factory = NotificationRequestFactory(calendar: calendar)
        let eligible = tasks.filter { shouldSchedule($0, now: now) }
        let recurring = eligible.filter { $0.schedule.type != .specificDates }.flatMap {
            factory.requests(for: $0, completedDayKeys: completedDayKeys[$0.id] ?? [], now: now)
        }
        let dated = eligible.filter { $0.schedule.type == .specificDates }.flatMap {
            factory.requests(for: $0, completedDayKeys: completedDayKeys[$0.id] ?? [], now: now)
        }.sorted {
            ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture <
            ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
        }
        for request in Array((recurring + dated).prefix(64)) {
            try await center.add(request)
        }
    }

    func remove(taskID: UUID) async {
        let prefix = identifierPrefix + taskID.uuidString + "."
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    func removeAll() async {
        let pending = await center.pendingNotificationRequests()
        let pendingIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)

        let delivered = await center.deliveredNotifications()
        let deliveredIDs = delivered.map { $0.request.identifier }.filter { $0.hasPrefix(identifierPrefix) }
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }

    private func shouldSchedule(_ task: TaskDTO, now: Date) -> Bool {
        guard task.reminderEnabled, !task.isArchived,
              task.reminderHour != nil, task.reminderMinute != nil else { return false }
        if let endDate = task.endDate,
           calendar.startOfDay(for: endDate) < calendar.startOfDay(for: now) {
            return false
        }
        return true
    }

}

struct NotificationRequestFactory: Sendable {
    private static let reminderSoundName = UNNotificationSoundName("PlanReminder.caf")

    let calendar: Calendar

    func requests(
        for task: TaskDTO,
        completedDayKeys: Set<String> = [],
        now: Date = Date()
    ) -> [UNNotificationRequest] {
        guard let hour = task.reminderHour, let minute = task.reminderMinute else { return [] }
        let content = UNMutableNotificationContent()
        content.title = L10n.text("今天也来点亮一颗星吧")
        content.body = task.title
        content.sound = UNNotificationSound(named: Self.reminderSoundName)
        content.userInfo = ["taskID": task.id.uuidString]

        let baseID = "task." + task.id.uuidString
        switch task.schedule {
        case .daily:
            let components = DateComponents(hour: hour, minute: minute)
            return [
                UNNotificationRequest(
                    identifier: baseID + ".dailyReminder",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
            ]
        case .weekdays, .custom:
            return task.schedule.selectedWeekdays.sorted { $0.rawValue < $1.rawValue }.map { weekday in
                let components = DateComponents(
                    calendar: calendar,
                    timeZone: calendar.timeZone,
                    hour: hour,
                    minute: minute,
                    weekday: Int(weekday.rawValue)
                )
                return UNNotificationRequest(
                    identifier: baseID + ".weekday.\(weekday.rawValue)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                )
            }
        case let .specificDates(entries, countdownDays):
            let service = TaskScheduleService()
            let today = calendar.startOfDay(for: now)
            return entries.flatMap { entry -> [UNNotificationRequest] in
                guard let occurrence = service.nextOccurrence(for: entry, onOrAfter: today, calendar: calendar) else {
                    return []
                }
                let key = DayKey(date: occurrence, calendar: calendar).rawValue
                guard !completedDayKeys.contains(key) else { return [] }
                let occurrenceID = baseID + ".specific.\(entry.id.uuidString).\(key)"
                var targetComponents = calendar.dateComponents([.year, .month, .day], from: occurrence)
                targetComponents.calendar = calendar
                targetComponents.timeZone = calendar.timeZone
                targetComponents.hour = hour
                targetComponents.minute = minute
                var result = [UNNotificationRequest(
                    identifier: occurrenceID + ".target",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: targetComponents, repeats: false)
                )]
                if let countdownDate = calendar.date(byAdding: .day, value: -countdownDays, to: occurrence),
                   countdownDate >= today {
                    var countdownComponents = calendar.dateComponents([.year, .month, .day], from: countdownDate)
                    countdownComponents.calendar = calendar
                    countdownComponents.timeZone = calendar.timeZone
                    countdownComponents.hour = hour
                    countdownComponents.minute = minute
                    result.append(UNNotificationRequest(
                        identifier: occurrenceID + ".countdown",
                        content: content,
                        trigger: UNCalendarNotificationTrigger(dateMatching: countdownComponents, repeats: false)
                    ))
                }
                return result
            }
        }
    }
}

struct DisabledNotificationScheduler: NotificationScheduling {
    func authorizationStatus() async -> NotificationAuthorizationStatus { .denied }
    func requestAuthorization() async throws -> Bool { false }
    func reconcile(tasks: [TaskDTO], completedDayKeys: [UUID: Set<String>], now: Date) async throws {}
    func remove(taskID: UUID) async {}
    func removeAll() async {}
}
