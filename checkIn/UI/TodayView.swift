import SwiftUI

struct TodayView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            PlanetAtmosphere()

            ScrollView {
                VStack(spacing: 18) {
                    pageHeader
                    heroCard
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

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("今日打卡")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
            Text(todayCaption)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var heroCard: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    PlanetTheme.elevatedSurface,
                    PlanetTheme.mutedSurface,
                    PlanetTheme.lavender.opacity(0.28)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Image("TodayHero")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(maxHeight: 248)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 58)
                .accessibilityHidden(true)

            progressSummary
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.45), lineWidth: 1)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.10), radius: 18, y: 8)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
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
