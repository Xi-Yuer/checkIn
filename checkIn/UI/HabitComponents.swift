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
        HStack(spacing: 10) {
            NavigationLink(value: habit.id) {
                HStack(spacing: 12) {
                    HabitIconBadge(habit: habit, size: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(habit.title)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(PlanetTheme.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                        Text(subtitle)
                            .font(.system(.caption, design: .rounded))
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
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 29, weight: .semibold))
                        .foregroundStyle(isComplete ? PlanetTheme.mint : PlanetTheme.separator)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isComplete)
                .accessibilityLabel(isComplete ? "今日已完成" : "为\(habit.title)打卡")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 82 : 64)
    }

    private var subtitle: String {
        if target > 1 {
            return "\(habit.scheduleAndReminderTitle) · \(completed)/\(target)"
        }
        return habit.scheduleAndReminderTitle
    }
}

struct HabitSummaryRow: View {
    let habit: TaskDTO
    let streak: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                HabitIconBadge(habit: habit, size: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(habit.title)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(PlanetTheme.primaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                    Text(habit.scheduleAndReminderTitle)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(habit.isArchived ? "已暂停" : "连续")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("天")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
            }
            .frame(minWidth: 50, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(habit.isArchived ? "已暂停，曾连续 \(streak) 天" : "连续 \(streak) 天")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 94 : 84)
        .background(PlanetTheme.elevatedSurface.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .overlay {
            NavigationLink(value: habit.id) {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(0)
            .accessibilityLabel(habit.title)
        }
    }
}

struct HabitIconBadge: View {
    let habit: TaskDTO
    var size: CGFloat = 42

    private var color: Color { Color(hex: habit.colorHex) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.14))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 1)
            Image(systemName: habit.iconKey)
                .font(.system(size: size * 0.46, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(color)
        }
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
