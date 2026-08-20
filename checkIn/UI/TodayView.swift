import SwiftUI

struct TodayView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void
    var onShowHabits: () -> Void = {}

    var body: some View {
        ZStack {
            PlanetBackground()

            ScrollView {
                LazyVStack(spacing: 0) {
                    heroSection
                    todayContent
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
            .refreshable { await store.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var heroSection: some View {
        VStack(spacing: 0) {
            pageHeader

            Image("TodayHero")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxWidth: 350)
                .padding(.horizontal, 22)
                .padding(.top, 2)
                .padding(.bottom, 2)
                .accessibilityHidden(true)

            progressSummary
        }
        .background(
            LinearGradient(
                colors: [PlanetTheme.surface.opacity(0.25), PlanetTheme.softViolet.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var pageHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("今日打卡")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(
                    store.today,
                    format: .dateTime
                        .month()
                        .day()
                        .weekday(.wide)
                        .locale(Locale(identifier: "zh_CN"))
                )
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }

            Spacer(minLength: 10)

            HStack(spacing: 4) {
                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PlanetTheme.lavender)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("刷新今日状态")

                Button(action: onShowHabits) {
                    Image(systemName: "square.grid.3x3")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("查看全部习惯")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var progressSummary: some View {
        HStack(spacing: 0) {
            metric(value: "\(store.completedTodayHabits.count)", label: "已打卡")
            metricDivider
            metric(value: "\(store.pendingTodayHabits.count)", label: "未打卡")
            metricDivider
            metric(value: completionPercentage, label: "完成率")
        }
        .padding(.vertical, 11)
        .background(PlanetTheme.mutedSurface.opacity(0.78))
        .accessibilityElement(children: .contain)
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(PlanetTheme.separator.opacity(0.55))
            .frame(width: 1, height: 38)
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
            .padding(.top, 20)
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
                            .overlay(PlanetTheme.separator.opacity(0.48))
                            .padding(.leading, 66)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(PlanetTheme.surface.opacity(0.93))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(PlanetTheme.separator.opacity(0.34), lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    private var completionPercentage: String {
        store.overallTodayProgress.formatted(
            .percent.precision(.fractionLength(0))
        )
    }
}
