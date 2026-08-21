import AppIntents
import Intents
import SwiftUI
import WidgetKit

private enum WidgetL10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(
            format: NSLocalizedString(key, comment: ""),
            locale: Locale.autoupdatingCurrent,
            arguments: arguments
        )
    }
}

@main
struct CheckInWidgetBundle: WidgetBundle {
    var body: some Widget {
        FocusedHabitWidget()
        CheckInWidget()
    }
}

struct CheckInWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: CheckInSharedConstants.widgetKind,
            provider: CheckInTimelineProvider()
        ) { entry in
            CheckInWidgetView(entry: entry)
        }
        .configurationDisplayName("打卡小星球")
        .description("查看今天的整体习惯进度。")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct CheckInTimelineEntry: TimelineEntry {
    let date: Date
    let state: CheckInWidgetState
    let carouselOffset: Int
}

enum CheckInWidgetState {
    case content(WidgetSnapshot)
    case unavailable
}

struct CheckInTimelineProvider: TimelineProvider {
    private let store = AppGroupWidgetSnapshotStore()

    func placeholder(in context: Context) -> CheckInTimelineEntry {
        CheckInTimelineEntry(date: Date(), state: .content(.preview), carouselOffset: 0)
    }

    func getSnapshot(in context: Context, completion: @escaping (CheckInTimelineEntry) -> Void) {
        completion(entry(at: Date(), offset: 0, allowPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CheckInTimelineEntry>) -> Void) {
        let start = Date()
        let interval: TimeInterval = 45 * 60
        let entries = (0..<8).map { offset in
            let date = start.addingTimeInterval(Double(offset) * interval)
            return entry(at: date, offset: offset, allowPreview: false)
        }
        completion(Timeline(entries: entries, policy: .after(start.addingTimeInterval(8 * interval))))
    }

    private func entry(at date: Date, offset: Int, allowPreview: Bool) -> CheckInTimelineEntry {
        let state: CheckInWidgetState
        switch store.load(now: date) {
        case .available(let snapshot):
            state = .content(snapshot)
        case .missing where allowPreview:
            state = .content(.preview)
        case .missing, .corrupted, .unsupportedVersion, .expired:
            state = .unavailable
        }
        return CheckInTimelineEntry(date: date, state: state, carouselOffset: offset)
    }
}

struct CheckInWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CheckInTimelineEntry

    var body: some View {
        Group {
            switch entry.state {
            case .content(let snapshot):
                content(snapshot)
            case .unavailable:
                unavailable
            }
        }
        .widgetURL(CheckInDeepLink.today.url)
        .checkInWidgetBackground()
    }

    @ViewBuilder
    private func content(_ snapshot: WidgetSnapshot) -> some View {
        let tasks = snapshot.scheduledTasks(on: entry.date)
        switch family {
        case .systemMedium:
            MediumCheckInWidget(
                snapshot: snapshot,
                tasks: tasks,
                date: entry.date,
                carouselOffset: entry.carouselOffset
            )
        case .systemLarge:
            LargeCheckInWidget(snapshot: snapshot, tasks: tasks, date: entry.date)
        default:
            MediumCheckInWidget(
                snapshot: snapshot,
                tasks: tasks,
                date: entry.date,
                carouselOffset: entry.carouselOffset
            )
        }
    }

    private var unavailable: some View {
        HStack(spacing: 12) {
            Image("WidgetMediumCatV2")
                .resizable()
                .scaledToFit()
                .frame(width: 142, height: 88, alignment: .trailing)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text("打开 App 更新今日习惯")
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                Text("数据仅保存在你的设备")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct FocusedHabitWidget: Widget {
    var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: CheckInSharedConstants.focusedWidgetKind,
            intent: FocusedHabitConfigurationIntent.self,
            provider: FocusedHabitTimelineProvider()
        ) { entry in
            FocusedHabitWidgetView(entry: entry)
        }
        .configurationDisplayName("重点打卡")
        .description("把最在乎的一个习惯放在桌面。")
        .supportedFamilies([.systemSmall])
    }
}

struct FocusedHabitTimelineEntry: TimelineEntry {
    let date: Date
    let state: FocusedHabitWidgetState
}

enum FocusedHabitWidgetState {
    case habit(WidgetSnapshot, WidgetTaskSnapshot)
    case chooseHabit
    case noHabits
    case invalidSelection
    case unavailable
}

struct FocusedHabitTimelineProvider: IntentTimelineProvider {
    typealias Intent = FocusedHabitConfigurationIntent
    typealias Entry = FocusedHabitTimelineEntry

    private let store = AppGroupWidgetSnapshotStore()

    func placeholder(in context: Context) -> Entry {
        let snapshot = WidgetSnapshot.preview
        return Entry(date: Date(), state: .habit(snapshot, snapshot.tasks[1]))
    }

    func getSnapshot(
        for configuration: FocusedHabitConfigurationIntent,
        in context: Context,
        completion: @escaping (Entry) -> Void
    ) {
        completion(entry(at: Date(), configuration: configuration, allowPreview: context.isPreview))
    }

    func getTimeline(
        for configuration: FocusedHabitConfigurationIntent,
        in context: Context,
        completion: @escaping (Timeline<Entry>) -> Void
    ) {
        let start = Date()
        let entries = (0..<8).map { offset in
            let date = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: offset * 3, to: start) ?? start
            return entry(at: date, configuration: configuration, allowPreview: false)
        }
        completion(Timeline(entries: entries, policy: .after(entries.last?.date ?? start)))
    }

    private func entry(
        at date: Date,
        configuration: FocusedHabitConfigurationIntent,
        allowPreview: Bool
    ) -> Entry {
        let snapshot: WidgetSnapshot
        switch store.load(now: date) {
        case .available(let value):
            snapshot = value
        case .missing where allowPreview:
            snapshot = .preview
        case .missing, .corrupted, .unsupportedVersion, .expired:
            return Entry(date: date, state: .unavailable)
        }

        switch snapshot.focusedTask(selectedIdentifier: configuration.habit?.identifier) {
        case .task(let task):
            return Entry(date: date, state: .habit(snapshot, task))
        case .chooseHabit:
            return Entry(date: date, state: .chooseHabit)
        case .noHabits:
            return Entry(date: date, state: .noHabits)
        case .invalidSelection:
            return Entry(date: date, state: .invalidSelection)
        }
    }
}

private struct FocusedHabitWidgetView: View {
    let entry: FocusedHabitTimelineEntry

    var body: some View {
        Group {
            switch entry.state {
            case .habit(let snapshot, let task):
                habitContent(snapshot: snapshot, task: task)
            case .chooseHabit:
                messageState(title: "选择一个目标", detail: "长按小组件进行编辑")
            case .noHabits:
                Link(destination: CheckInDeepLink.today.url) {
                    messageState(title: "添加第一个目标", detail: "从一个小目标开始")
                }
                .buttonStyle(.plain)
            case .invalidSelection:
                messageState(title: "请重新选择目标", detail: "长按小组件进行编辑")
            case .unavailable:
                Link(destination: CheckInDeepLink.today.url) {
                    messageState(title: "打开 App 更新", detail: "数据仅保存在你的设备")
                }
                .buttonStyle(.plain)
            }
        }
        .checkInWidgetBackground()
    }

    private func habitContent(snapshot: WidgetSnapshot, task: WidgetTaskSnapshot) -> some View {
        let count = task.count(on: entry.date, snapshotDayKey: snapshot.dayKey)
        let isScheduled = task.schedule.isScheduled(on: entry.date)
        let isComplete = count >= task.dailyGoal

        return VStack(alignment: .leading, spacing: 0) {
            Link(destination: CheckInDeepLink.task(task.id).url) {
                Text(task.title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34, alignment: .topLeading)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 4)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(task.persistedDays(on: entry.date))")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                Text("天")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 4)

                if task.dailyGoal > 1 {
                    Text("\(count)/\(task.dailyGoal)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(CheckInWidgetPalette.button)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(CheckInWidgetPalette.button.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text("连续 \(task.currentStreak) 天")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 5)

            if !isScheduled {
                statusButton("今天休息", background: Color.secondary.opacity(0.18), foreground: .secondary)
            } else if isComplete {
                statusButton("今天完成啦", background: CheckInWidgetPalette.mint, foreground: .white)
            } else if #available(iOSApplicationExtension 17.0, *) {
                Button(intent: RecordFocusedCheckInIntent(taskID: task.id)) {
                    statusButton("打卡 +1", background: CheckInWidgetPalette.button, foreground: .white)
                }
                .buttonStyle(.plain)
            } else {
                Link(destination: CheckInDeepLink.task(task.id).url) {
                    statusButton("打开打卡", background: CheckInWidgetPalette.button, foreground: .white)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(task: task, count: count))
    }

    private func accessibilityText(task: WidgetTaskSnapshot, count: Int) -> String {
        var parts = [
            task.title,
            "已坚持 \(task.persistedDays(on: entry.date)) 天",
            "连续 \(task.currentStreak) 天"
        ]
        if task.dailyGoal > 1 {
            parts.append("\(count)/\(task.dailyGoal)")
        }
        return parts.joined(separator: "，")
    }

    private func messageState(title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        VStack(spacing: 6) {
            Image("WidgetMediumCatV2")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 72, alignment: .trailing)
                .accessibilityHidden(true)
            VStack(spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusButton(
        _ title: LocalizedStringKey,
        background: Color,
        foreground: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

@available(iOS 17.0, *)
struct RecordFocusedCheckInIntent: AppIntent {
    static var title: LocalizedStringResource = "重点习惯打卡"
    static var description = IntentDescription("为重点习惯完成一次打卡。")
    static var openAppWhenRun = false

    @Parameter(title: "习惯 ID")
    var taskID: String

    init() {}

    init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { return .result() }
        let snapshotStore = AppGroupWidgetSnapshotStore()
        guard case .available(let snapshot) = snapshotStore.load(now: Date()),
              let task = snapshot.tasks.first(where: { $0.id == id }),
              !task.isPaused,
              task.schedule.isScheduled(on: Date()),
              task.count(on: Date(), snapshotDayKey: snapshot.dayKey) < task.dailyGoal else {
            return .result()
        }

        let action = WidgetPendingCheckIn(taskID: id)
        let actionStore = AppGroupWidgetPendingCheckInStore()
        if try actionStore.enqueue(action, maximumPendingForTask: task.dailyGoal) {
            _ = try? snapshotStore.incrementCompletedCount(taskID: id, at: action.occurredAt)
            WidgetCenter.shared.reloadTimelines(ofKind: CheckInSharedConstants.focusedWidgetKind)
            WidgetCenter.shared.reloadTimelines(ofKind: CheckInSharedConstants.widgetKind)
        }
        return .result()
    }
}

private struct MediumCheckInWidget: View {
    let snapshot: WidgetSnapshot
    let tasks: [WidgetTaskSnapshot]
    let date: Date
    let carouselOffset: Int

    var body: some View {
        Group {
            if tasks.isEmpty {
                HStack(spacing: 12) {
                    Image("WidgetMediumCatV2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 116)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今天完成啦")
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                        Text("所有计划都已完成")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                taskContent(currentTask)
            }
        }
    }

    private func taskContent(_ task: WidgetTaskSnapshot) -> some View {
        let count = task.count(on: date, snapshotDayKey: snapshot.dayKey)
        let isComplete = count >= task.dailyGoal

        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: CheckInDeepLink.task(task.id).url) {
                    HStack(spacing: 9) {
                        HabitArtwork(iconKey: task.symbolName)
                            .frame(width: 38, height: 38)
                        Text(task.title)
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                Spacer(minLength: 2)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(task.currentStreak)")
                        .font(.system(size: 42, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text("连续天数")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 2)

                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: AdvanceWidgetTaskIntent()) {
                        Label("下一条计划", systemImage: "arrow.right")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(CheckInWidgetPalette.button)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(CheckInWidgetPalette.button.opacity(0.11))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Divider()

            VStack(spacing: 7) {
                MediumScheduleGrid(task: task, date: date, isCompleteToday: isComplete)

                Spacer(minLength: 0)

                if isComplete {
                    mediumActionButton("今日已完成", systemImage: "checkmark", background: CheckInWidgetPalette.mint)
                } else if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: RecordFocusedCheckInIntent(taskID: task.id)) {
                        mediumActionButton("打卡", systemImage: "plus", background: CheckInWidgetPalette.button)
                    }
                    .buttonStyle(.plain)
                } else {
                    Link(destination: CheckInDeepLink.task(task.id).url) {
                        mediumActionButton("打开打卡", systemImage: "plus", background: CheckInWidgetPalette.button)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 135)
        }
        .accessibilityElement(children: .contain)
    }

    private func mediumActionButton(
        _ title: LocalizedStringKey,
        systemImage: String,
        background: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(background)
            .clipShape(Capsule())
    }

    private var currentTask: WidgetTaskSnapshot {
        let savedIndex = UserDefaults(suiteName: CheckInSharedConstants.appGroupIdentifier)?
            .integer(forKey: CheckInSharedConstants.carouselIndexKey) ?? 0
        return tasks[positiveModulo(savedIndex + carouselOffset, tasks.count)]
    }

    private func positiveModulo(_ value: Int, _ divisor: Int) -> Int {
        guard divisor > 0 else { return 0 }
        return ((value % divisor) + divisor) % divisor
    }
}

private struct MediumScheduleGrid: View {
    let task: WidgetTaskSnapshot
    let date: Date
    let isCompleteToday: Bool

    private let columns = Array(repeating: GridItem(.fixed(16), spacing: 3), count: 7)
    private let weekdayLabels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(weekdayLabels, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(Array(scheduleDays.enumerated()), id: \.offset) { index, day in
                    let scheduled = task.schedule.isScheduled(on: day)
                    let isToday = Calendar.autoupdatingCurrent.isDate(day, inSameDayAs: date)

                    ZStack {
                        Circle()
                            .fill(dotColor(scheduled: scheduled, isToday: isToday))
                            .frame(width: 16, height: 16)
                        if isToday {
                            Image(systemName: isCompleteToday ? "checkmark" : "star.fill")
                                .font(.system(size: 7, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }
                    .accessibilityLabel(dotAccessibilityLabel(index: index, scheduled: scheduled, isToday: isToday))
                }
            }
        }
    }

    private var scheduleDays: [Date] {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) ?? today
        return (0..<21).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private func dotColor(scheduled: Bool, isToday: Bool) -> Color {
        if isToday { return isCompleteToday ? CheckInWidgetPalette.mint : CheckInWidgetPalette.sun }
        return scheduled ? Color.secondary.opacity(0.20) : Color.secondary.opacity(0.07)
    }

    private func dotAccessibilityLabel(index: Int, scheduled: Bool, isToday: Bool) -> String {
        let prefix = isToday ? "今天" : "第 \(index + 1) 天"
        return "\(prefix)，\(scheduled ? "计划日" : "休息日")"
    }
}

private enum WidgetChineseDate {
    static let locale = Locale(identifier: "zh_CN")

    static func line(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().weekday(.abbreviated).locale(locale))
    }
}

private struct WidgetCompactTaskRow: View {
    let task: WidgetTaskSnapshot
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let count = task.count(on: date, snapshotDayKey: snapshot.dayKey)
        let done = count >= task.dailyGoal
        HStack(spacing: 8) {
            HabitArtwork(iconKey: task.symbolName)
                .frame(width: 26, height: 26)
            Text(task.title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text("\(count)/\(task.dailyGoal)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(done ? CheckInWidgetPalette.mint : .secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

private struct LargeCheckInWidget: View {
    let snapshot: WidgetSnapshot
    let tasks: [WidgetTaskSnapshot]
    let date: Date

    var body: some View {
        let progress = snapshot.progress(on: date)
        let finished = tasks.filter { $0.count(on: date, snapshotDayKey: snapshot.dayKey) >= $0.dailyGoal }.count

        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(WidgetChineseDate.line(date))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text("\(progress.completed)/\(progress.goal)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                    Text(tasks.isEmpty ? "今天完成啦" : "已完成 \(finished)/\(tasks.count) 项")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Image("WidgetLargeHeroV2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 92, height: 72)
                    .accessibilityHidden(true)
            }

            if tasks.isEmpty {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 2) {
                    ForEach(Array(tasks.prefix(5))) { task in
                        Link(destination: CheckInDeepLink.task(task.id).url) {
                            WidgetCompactTaskRow(task: task, snapshot: snapshot, date: date)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
struct AdvanceWidgetTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "下一项习惯"
    static var description = IntentDescription("在小组件中显示下一项习惯。")
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: CheckInSharedConstants.appGroupIdentifier) {
            let current = defaults.integer(forKey: CheckInSharedConstants.carouselIndexKey)
            defaults.set(current == Int.max ? 0 : current + 1, forKey: CheckInSharedConstants.carouselIndexKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: CheckInSharedConstants.widgetKind)
        return .result()
    }
}

private enum CheckInWidgetPalette {
    static let button = Color(checkInHex: "6D4AFF")
    static let mint = Color(checkInHex: "34D399")
    static let sun = Color(checkInHex: "FFB800")
}

private extension View {
    @ViewBuilder
    func checkInWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            padding()
                .background(Color.clear)
        }
    }
}

private extension Color {
    init(checkInHex value: String) {
        let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let parsed = UInt64(cleaned, radix: 16) ?? 0x7C3AED
        let red: Double
        let green: Double
        let blue: Double
        if cleaned.count == 3 {
            red = Double((parsed >> 8) & 0xF) / 15
            green = Double((parsed >> 4) & 0xF) / 15
            blue = Double(parsed & 0xF) / 15
        } else {
            red = Double((parsed >> 16) & 0xFF) / 255
            green = Double((parsed >> 8) & 0xFF) / 255
            blue = Double(parsed & 0xFF) / 255
        }
        self.init(red: red, green: green, blue: blue)
    }
}

private extension WidgetSnapshot {
    static var preview: WidgetSnapshot {
        let now = Date()
        return WidgetSnapshot(
            generatedAt: now,
            usableThrough: now.addingTimeInterval(7 * 24 * 60 * 60),
            dayKey: WidgetDayKey.string(from: now),
            tasks: [
                WidgetTaskSnapshot(
                    id: UUID(uuidString: "22F3BBD6-81B4-4874-977A-57BE2EFC8101")!,
                    title: WidgetL10n.text("读书 30 分钟"),
                    symbolName: "book.closed.fill",
                    colorHex: "7C3AED",
                    sortOrder: 0,
                    dailyGoal: 1,
                    completedCount: 1,
                    schedule: WidgetSchedule(kind: .daily),
                    currentStreak: 5
                ),
                WidgetTaskSnapshot(
                    id: UUID(uuidString: "22F3BBD6-81B4-4874-977A-57BE2EFC8102")!,
                    title: WidgetL10n.text("喝水 2000ml"),
                    symbolName: "waterbottle.fill",
                    colorHex: "38BDF8",
                    sortOrder: 1,
                    dailyGoal: 8,
                    completedCount: 5,
                    schedule: WidgetSchedule(kind: .daily),
                    currentStreak: 12
                ),
                WidgetTaskSnapshot(
                    id: UUID(uuidString: "22F3BBD6-81B4-4874-977A-57BE2EFC8103")!,
                    title: WidgetL10n.text("跑步 5 公里"),
                    symbolName: "figure.run",
                    colorHex: "F87171",
                    sortOrder: 2,
                    dailyGoal: 1,
                    completedCount: 0,
                    schedule: WidgetSchedule(kind: .weekdays)
                )
            ]
        )
    }
}
