import Foundation
import SwiftUI

struct TodayHabitRow: View {
    let habit: TaskDTO
    let progress: DailyProgress?
    let isProcessing: Bool
    let onCheckIn: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var completed: Int { progress?.completed ?? 0 }
    private var target: Int { progress?.target ?? habit.dailyTarget }
    private var isComplete: Bool { progress?.isComplete ?? false }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: habit.id) {
                HStack(spacing: 14) {
                    HabitIconBadge(habit: habit, size: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(PlanetTheme.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                        Text(subtitle)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(PlanetTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            if isProcessing {
                ProgressView()
                    .tint(PlanetTheme.violet)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("正在打卡")
            } else {
                Button(action: onCheckIn) {
                    CheckInProgressGauge(
                        progress: fraction,
                        isComplete: isComplete,
                        showsLiquidWave: target > 1
                    )
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isComplete)
                .accessibilityLabel(checkAccessibilityLabel)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 104 : 88)
    }

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(completed) / Double(target))
    }

    private var checkAccessibilityLabel: String {
        if isComplete {
            return L10n.text("今日已完成")
        }
        if target > 1 {
            return L10n.format("为%@打卡，已完成 %d/%d", habit.title, completed, target)
        }
        return L10n.format("为%@打卡", habit.title)
    }

    private var subtitle: String {
        if target > 1 {
            return "\(habit.scheduleAndReminderTitle) · \(completed)/\(target)"
        }
        return habit.scheduleAndReminderTitle
    }
}

struct UpcomingSpecificDateRow: View {
    let item: UpcomingSpecificDateItem
    let isProcessing: Bool
    let onCheckIn: () -> Void
    let onUndo: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: item.habit.id) {
                HStack(spacing: 14) {
                    HabitIconBadge(habit: item.habit, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.habit.title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(PlanetTheme.primaryText)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(item.progress.isComplete ? PlanetTheme.mint : PlanetTheme.secondaryText)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isProcessing {
                ProgressView().tint(PlanetTheme.violet).frame(width: 44, height: 44)
            } else if item.progress.isComplete {
                Button(action: onUndo) {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PlanetTheme.mint)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("撤销提前打卡")
            } else {
                Button(action: onCheckIn) {
                    CheckInProgressGauge(
                        progress: item.progress.fractionComplete,
                        isComplete: false,
                        showsLiquidWave: item.progress.target > 1
                    )
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("提前打卡")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .frame(minHeight: 88)
    }

    private var subtitle: String {
        if item.progress.isComplete { return L10n.text("已提前完成") }
        let date = item.occurrence.date.formatted(.dateTime.month().day().locale(locale))
        let countdown = L10n.format("还有 %d 天", item.occurrence.daysRemaining)
        if item.progress.target > 1 {
            return "\(date) · \(countdown) · \(item.progress.completed)/\(item.progress.target)"
        }
        return "\(date) · \(countdown)"
    }
}

private struct CheckInProgressGauge: View {
    let progress: Double
    let isComplete: Bool
    let showsLiquidWave: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 32

    var body: some View {
        let fill = CGFloat(min(1, max(0, progress)))

        ZStack {
            Circle()
                .fill(PlanetTheme.mint.opacity(0.08))

            if showsLiquidWave && !isComplete {
                liquid(fill: fill)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(PlanetTheme.mint)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: size * fill)
                    }
            }

            Circle()
                .stroke(
                    progress > 0 ? PlanetTheme.mint : PlanetTheme.lavender.opacity(0.55),
                    lineWidth: 2
                )

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: isComplete ? PlanetTheme.mint.opacity(0.28) : .clear, radius: 6, y: 2)
        .animation(.spring(response: 0.48, dampingFraction: 0.72), value: fill)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func liquid(fill: CGFloat) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0 : seconds * 2.2

            ZStack {
                LiquidWave(fill: fill, phase: phase, amplitude: 1.8)
                    .fill(PlanetTheme.mint.opacity(0.48))
                    .offset(x: -1)

                LiquidWave(fill: fill, phase: -phase * 0.82 + 1.4, amplitude: 1.35)
                    .fill(PlanetTheme.mint.opacity(0.92))
                    .offset(y: 1.4)
            }
        }
    }
}

private struct LiquidWave: Shape {
    var fill: CGFloat
    var phase: Double
    var amplitude: CGFloat

    var animatableData: CGFloat {
        get { fill }
        set { fill = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clampedFill = min(1, max(0, fill))
        let surfaceY = rect.maxY - rect.height * clampedFill
        let wavelength = max(rect.width * 0.72, 1)

        path.move(to: CGPoint(x: rect.minX, y: surfaceY))
        stride(from: rect.minX, through: rect.maxX + 1, by: 1).forEach { x in
            let angle = ((x - rect.minX) / wavelength) * (2 * CGFloat.pi) + CGFloat(phase)
            let y = surfaceY + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct HabitSummaryRow: View {
    let habit: TaskDTO
    let streak: Int
    let completedDays: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: habit.id) {
                HStack(spacing: 14) {
                    HabitIconBadge(habit: habit, size: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(PlanetTheme.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                        Text(habit.scheduleAndReminderTitle)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(PlanetTheme.secondaryText)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(completedDays)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                        .monospacedDigit()
                    Text(L10n.text("天"))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }

                Text(
                    habit.isArchived
                        ? L10n.format("已暂停，曾连续 %d 天", streak)
                        : L10n.format("连续 %d 天", streak)
                )
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
                .lineLimit(1)
            }
            .frame(minWidth: 72, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                habit.isArchived
                    ? L10n.format("已暂停，曾连续 %d 天，累计打卡 %d 天", streak, completedDays)
                    : L10n.format("连续 %d 天，累计打卡 %d 天", streak, completedDays)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 104 : 88)
    }

}

struct HabitIconBadge: View {
    let habit: TaskDTO
    var size: CGFloat = 42

    var body: some View {
        HabitArtwork(iconKey: habit.iconKey)
            .padding(HabitIconCatalog.contains(habit.iconKey) ? 0 : size * 0.18)
            .foregroundStyle(Color(hex: habit.colorHex))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

struct FilterPill<Value: Hashable>: View {
    let title: String
    let value: Value
    @Binding var selection: Value

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(L10n.text(title))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selection == value ? Color.white : PlanetTheme.secondaryText)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(selection == value ? PlanetTheme.violet : PlanetTheme.surface)
                .clipShape(Capsule())
                .overlay {
                    if selection != value {
                        Capsule().stroke(PlanetTheme.separator, lineWidth: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

struct SectionTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.text(title))
                .font(.title3.weight(.heavy))
                .foregroundStyle(PlanetTheme.primaryText)
            if let subtitle {
                Text(L10n.text(subtitle))
                    .font(.caption)
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension TaskSchedule {
    var compactTitle: String {
        switch self {
        case .daily:
            return L10n.text("每天")
        case .weekdays:
            return L10n.text("工作日")
        case let .custom(days):
            let ordered = Weekday.allCases.filter(days.contains)
            return ordered.map(\.shortTitle).joined(separator: " · ")
        case let .specificDates(entries, _):
            return Self.nearestSpecificDateTitle(entries)
        }
    }

    private static func nearestSpecificDateTitle(_ entries: [TaskSpecificDate]) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: Date())
        let scheduler = TaskScheduleService()
        let nextDate = entries
            .compactMap { scheduler.nextOccurrence(for: $0, onOrAfter: today, calendar: calendar) }
            .min()

        // An expired one-time plan can still appear in history. Keep its actual
        // date visible there instead of falling back to a generic item count.
        let fallbackDate = entries
            .compactMap { DayKey(rawValue: $0.dayKey).date(calendar: calendar) }
            .max()

        guard let date = nextDate ?? fallbackDate else {
            return L10n.text("尚未选择日期")
        }

        if calendar.component(.year, from: date) == calendar.component(.year, from: today) {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.year().month().day())
    }
}

extension TaskDTO {
    var scheduleAndReminderTitle: String {
        guard reminderEnabled, let reminderHour, let reminderMinute else {
            return schedule.compactTitle
        }
        return "\(schedule.compactTitle) \(String(format: "%02d:%02d", reminderHour, reminderMinute))"
    }
}

extension TaskPriority {
    var color: Color {
        switch self {
        case .low: PlanetTheme.sky
        case .normal: PlanetTheme.mint
        case .high: PlanetTheme.gold
        case .urgent: PlanetTheme.coral
        }
    }
}
