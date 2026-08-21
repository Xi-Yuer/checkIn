import AppIntents
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
        .description("查看今天的习惯进度和下一项任务。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
        case .systemSmall:
            SmallCheckInWidget(snapshot: snapshot, tasks: tasks, date: entry.date)
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
            SmallCheckInWidget(snapshot: snapshot, tasks: tasks, date: entry.date)
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("打卡小星球", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(CheckInWidgetPalette.brand)
            Spacer(minLength: 0)
            Text("打开 App 更新今日习惯")
                .font(.subheadline.weight(.semibold))
            Text("数据仅保存在你的设备")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct SmallCheckInWidget: View {
    let snapshot: WidgetSnapshot
    let tasks: [WidgetTaskSnapshot]
    let date: Date

    var body: some View {
        let progress = snapshot.progress(on: date)
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(CheckInWidgetPalette.sun)
                Text("今日打卡")
                    .font(.headline)
                Spacer(minLength: 0)
                Text(progressText(progress))
                    .font(.caption.bold())
                    .foregroundStyle(CheckInWidgetPalette.brand)
            }

            ProgressView(value: Double(progress.completed), total: Double(max(progress.goal, 1)))
                .tint(CheckInWidgetPalette.mint)

            Spacer(minLength: 0)

            if let task = tasks.first(where: { task in
                task.count(on: date, snapshotDayKey: snapshot.dayKey) < task.dailyGoal
            }) ?? tasks.first {
                Link(destination: CheckInDeepLink.task(task.id).url) {
                    WidgetTaskLabel(task: task, snapshot: snapshot, date: date, compact: true)
                }
                .buttonStyle(.plain)
            } else {
                CompleteState()
            }
        }
    }

    private func progressText(_ progress: (completed: Int, goal: Int)) -> String {
        progress.goal == 0 ? "0/0" : "\(progress.completed)/\(progress.goal)"
    }
}

private struct MediumCheckInWidget: View {
    let snapshot: WidgetSnapshot
    let tasks: [WidgetTaskSnapshot]
    let date: Date
    let carouselOffset: Int

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("打卡小星球", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(CheckInWidgetPalette.brand)
                Spacer(minLength: 0)
                if tasks.isEmpty {
                    CompleteState()
                } else {
                    Link(destination: CheckInDeepLink.task(currentTask.id).url) {
                        WidgetTaskLabel(task: currentTask, snapshot: snapshot, date: date, compact: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 9) {
                OverallProgress(snapshot: snapshot, date: date)
                if #available(iOSApplicationExtension 17.0, *) {
                    Button(intent: AdvanceWidgetTaskIntent()) {
                        Label("下一项", systemImage: "chevron.right")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(CheckInWidgetPalette.brand)
                } else {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(CheckInWidgetPalette.brand.opacity(0.8))
                        .accessibilityLabel("打开 App 查看下一项")
                }
            }
            .frame(width: 84)
        }
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

private struct LargeCheckInWidget: View {
    let snapshot: WidgetSnapshot
    let tasks: [WidgetTaskSnapshot]
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("打卡小星球", systemImage: "sparkles")
                    .font(.title3.bold())
                    .foregroundStyle(CheckInWidgetPalette.brand)
                Spacer()
                OverallProgress(snapshot: snapshot, date: date)
                    .frame(width: 92)
            }

            Divider()

            if tasks.isEmpty {
                Spacer(minLength: 0)
                CompleteState()
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 0)
            } else {
                ForEach(Array(tasks.prefix(3))) { task in
                    Link(destination: CheckInDeepLink.task(task.id).url) {
                        WidgetTaskLabel(task: task, snapshot: snapshot, date: date, compact: false)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }

            Text("继续保持，每天进步一点点")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct WidgetTaskLabel: View {
    let task: WidgetTaskSnapshot
    let snapshot: WidgetSnapshot
    let date: Date
    let compact: Bool

    var body: some View {
        let count = task.count(on: date, snapshotDayKey: snapshot.dayKey)
        HStack(spacing: 9) {
            HabitArtwork(iconKey: task.symbolName)
                .padding(HabitIconCatalog.contains(task.symbolName) ? 0 : 6)
                .foregroundStyle(Color(checkInHex: task.colorHex))
                .frame(width: compact ? 36 : 44, height: compact ? 36 : 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(compact ? .caption.bold() : .subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(count) / \(task.dailyGoal)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: count >= task.dailyGoal ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(count >= task.dailyGoal ? CheckInWidgetPalette.mint : .secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            WidgetL10n.format("%@，已完成 %d 次，目标 %d 次", task.title, count, task.dailyGoal)
        )
    }
}

private struct OverallProgress: View {
    let snapshot: WidgetSnapshot
    let date: Date

    var body: some View {
        let progress = snapshot.progress(on: date)
        let ratio = progress.goal == 0 ? 0 : Double(progress.completed) / Double(progress.goal)
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(CheckInWidgetPalette.brand.opacity(0.14), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(max(ratio, 0), 1))
                    .stroke(CheckInWidgetPalette.brand, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(.caption2.bold())
            }
            .frame(width: 54, height: 54)
            Text("今日进度")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CompleteState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("今天完成啦", systemImage: "star.fill")
                .font(.subheadline.bold())
                .foregroundStyle(CheckInWidgetPalette.sun)
            Text("去收获一颗小星星")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
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
    static let brand = Color(checkInHex: "7C3AED")
    static let mint = Color(checkInHex: "34D399")
    static let sun = Color(checkInHex: "FDBA74")
    static let background = Color(checkInHex: "F7F3FF")
}

private extension View {
    @ViewBuilder
    func checkInWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                CheckInWidgetPalette.background
            }
        } else {
            padding()
                .background(CheckInWidgetPalette.background)
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
                    schedule: WidgetSchedule(kind: .daily)
                ),
                WidgetTaskSnapshot(
                    id: UUID(uuidString: "22F3BBD6-81B4-4874-977A-57BE2EFC8102")!,
                    title: WidgetL10n.text("喝水 2000ml"),
                    symbolName: "waterbottle.fill",
                    colorHex: "38BDF8",
                    sortOrder: 1,
                    dailyGoal: 8,
                    completedCount: 5,
                    schedule: WidgetSchedule(kind: .daily)
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
