import SwiftUI

struct TodayView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            PlanetAtmosphere()

            ScrollView {
                VStack(spacing: 18) {
                    heroSection
                    todayContent
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .refreshable { await store.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heroSection: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let period = HomeBannerPeriod.current(at: context.date)
            ZStack(alignment: .topLeading) {
                Color.clear
                    .aspectRatio(3 / 2, contentMode: .fit)
                    .overlay {
                        Image(period.assetName)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
                    .accessibilityHidden(true)
                    .id(period)

                LinearGradient(
                    colors: [
                        PlanetTheme.background.opacity(0.82),
                        PlanetTheme.background.opacity(0.28),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 128)
                .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 5) {
                    Text("今日打卡")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text(todayCaption)
                        .font(.system(.subheadline, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                .padding(.horizontal, 22)
                .padding(.top, 12)
            }
            .overlay(alignment: .bottom) {
                progressSummary
                    .padding(.horizontal, 16)
                    .offset(y: 18)
            }
            .padding(.bottom, 34)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("今日打卡，\(period.accessibilityLabel)")
        }
    }

    private var progressSummary: some View {
        HStack(spacing: 0) {
            metric(value: "\(store.completedTodayHabits.count)", label: "已打卡")
            metricDivider
            metric(value: "\(store.pendingTodayHabits.count)", label: "未打卡")
            metricDivider
            metric(value: completionPercentage, label: "完成率")
        }
        .padding(.vertical, 12)
        .background(PlanetTheme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.nest, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PlanetTheme.Radius.nest, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.08), radius: 10, y: 4)
        .accessibilityElement(children: .contain)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Capsule()
            .fill(PlanetTheme.separator.opacity(0.55))
            .frame(width: 3, height: 28)
    }

    @ViewBuilder
    private var todayContent: some View {
        if store.todayHabits.isEmpty {
            EmptyStateView(
                mood: .ready,
                title: "今天还没有计划",
                message: "从一个轻松的小目标开始，让每天都有一点进步。",
                actionTitle: "添加第一个习惯",
                action: onAdd
            )
            .frame(maxWidth: .infinity)
            .softCard(fill: PlanetTheme.surface.opacity(0.96), shadowOpacity: 0.08)
            .padding(.horizontal, 16)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.todayHabits.enumerated()), id: \.element.id) { index, habit in
                    TodayHabitRow(
                        habit: habit,
                        progress: store.todayProgress[habit.id],
                        isProcessing: store.processingHabitIDs.contains(habit.id),
                        onCheckIn: { Task { await store.checkIn(habitID: habit.id) } }
                    )

                    if index < store.todayHabits.count - 1 {
                        Divider()
                            .overlay(PlanetTheme.separator.opacity(0.36))
                            .padding(.leading, 102)
                    }
                }
            }
            .padding(.vertical, 8)
            .softCard(fill: PlanetTheme.surface.opacity(0.97), shadowOpacity: 0.08)
            .overlay {
                RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                    .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
            }
            .padding(.horizontal, 16)
        }
    }

    private var todayCaption: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: store.today)
    }

    private var completionPercentage: String {
        store.overallTodayProgress.formatted(
            .percent.precision(.fractionLength(0))
        )
    }
}

enum HomeBannerPeriod: CaseIterable {
    case morning
    case noon
    case afternoon
    case evening
    case night

    var assetName: String {
        switch self {
        case .morning: "BannerMorning"
        case .noon: "BannerNoon"
        case .afternoon: "BannerAfternoon"
        case .evening: "BannerEvening"
        case .night: "BannerNight"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .morning: "早晨插画"
        case .noon: "中午插画"
        case .afternoon: "下午插画"
        case .evening: "晚上插画"
        case .night: "深夜插画"
        }
    }

    static func current(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> HomeBannerPeriod {
        switch calendar.component(.hour, from: date) {
        case 6..<11: .morning
        case 11..<14: .noon
        case 14..<18: .afternoon
        case 18..<22: .evening
        default: .night
        }
    }
}
