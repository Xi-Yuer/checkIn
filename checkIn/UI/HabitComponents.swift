import SwiftUI

struct HabitListRow: View {
    let habit: TaskDTO
    let progress: DailyProgress?
    var showsAction = true
    let onCheckIn: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var color: Color { Color(hex: habit.colorHex) }
    private var completed: Int { progress?.completed ?? 0 }
    private var target: Int { progress?.target ?? habit.dailyTarget }
    private var isComplete: Bool { progress?.isComplete ?? false }

    var body: some View {
        HStack(spacing: 14) {
            NavigationLink(value: habit.id) {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(color.opacity(0.16))
                        Image(systemName: habit.iconKey)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(color)
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(habit.title)
                            .font(.body.weight(.bold))
                            .foregroundStyle(PlanetTheme.primaryText)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 1)

                        HStack(spacing: 8) {
                            Label(habit.schedule.compactTitle, systemImage: "calendar")
                            Text("\(completed)/\(target)")
                        }
                        .font(.caption)
                        .foregroundStyle(PlanetTheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            if habit.isArchived {
                Text("已暂停")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 32)
                    .background(PlanetTheme.elevatedSurface)
                    .clipShape(Capsule())
            } else if showsAction {
                Button(action: onCheckIn) {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isComplete ? PlanetTheme.mint : color.opacity(0.8))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(isComplete)
                .accessibilityLabel(isComplete ? "今日已完成" : "为\(habit.title)打卡")
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
        }
        .padding(14)
        .background(PlanetTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.75), lineWidth: 1)
        }
        .contentShape(Rectangle())
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
