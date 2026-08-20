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
                    CheckInProgressGauge(progress: fraction, isComplete: isComplete)
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
            return "今日已完成"
        }
        if target > 1 {
            return "为\(habit.title)打卡，已完成 \(completed)/\(target)"
        }
        return "为\(habit.title)打卡"
    }

    private var subtitle: String {
        if target > 1 {
            return "\(habit.scheduleAndReminderTitle) · \(completed)/\(target)"
        }
        return habit.scheduleAndReminderTitle
    }
}

private struct CheckInProgressGauge: View {
    let progress: Double
    let isComplete: Bool

    private let size: CGFloat = 28

    var body: some View {
        let fill = CGFloat(min(1, max(0, progress)))

        ZStack {
            Circle()
                .stroke(
                    progress > 0 ? PlanetTheme.mint : PlanetTheme.lavender.opacity(0.55),
                    lineWidth: 2
                )

            Circle()
                .fill(PlanetTheme.mint)
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: size * fill)
                }

            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Color.white)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: isComplete ? PlanetTheme.mint.opacity(0.28) : .clear, radius: 6, y: 2)
        .accessibilityHidden(true)
    }
}

struct HabitSummaryRow: View {
    let habit: TaskDTO
    let streak: Int

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

            VStack(alignment: .trailing, spacing: 1) {
                Text(habit.isArchived ? "已暂停" : "连续")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("天")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
            }
            .frame(minWidth: 44, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(habit.isArchived ? "已暂停，曾连续 \(streak) 天" : "连续 \(streak) 天")
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
            Text(title)
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
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(PlanetTheme.primaryText)
            if let subtitle {
                Text(subtitle)
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
            return "每天"
        case .weekdays:
            return "工作日"
        case let .custom(days):
            let ordered = Weekday.allCases.filter(days.contains)
            return ordered.map(\.shortTitle).joined(separator: " · ")
        }
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
