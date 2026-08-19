import SwiftUI

private enum TodayFilter: String, CaseIterable, Identifiable {
    case pending
    case completed
    case all

    var id: String { rawValue }
    var title: String {
        switch self {
        case .pending: "待完成"
        case .completed: "已完成"
        case .all: "全部"
        }
    }
}

struct TodayView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    @State private var filter: TodayFilter = .pending

    private var displayedHabits: [TaskDTO] {
        switch filter {
        case .pending: store.pendingTodayHabits
        case .completed: store.completedTodayHabits
        case .all: store.todayHabits
        }
    }

    var body: some View {
        ZStack {
            PlanetBackground()
            ScrollView {
                LazyVStack(spacing: 20) {
                    greeting
                    progressHero

                    if store.todayHabits.isEmpty {
                        EmptyStateView(
                            mood: .ready,
                            title: "今天还没有计划",
                            message: "从一个轻松的小目标开始，让每天都有一点进步。",
                            actionTitle: "添加第一个习惯",
                            action: onAdd
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        filterBar
                        habitContent
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("今日打卡")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.body.weight(.bold))
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("添加习惯")
            }
        }
    }

    private var greeting: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(dayGreeting)
                    .font(.title2.weight(.heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(store.today, format: .dateTime.month().day().weekday(.wide))
                    .font(.subheadline)
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.title3.weight(.bold))
                .foregroundStyle(PlanetTheme.gold)
        }
    }

    private var progressHero: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.completedTodayHabits.isEmpty ? "点亮今天的第一颗星" : progressMessage)
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("已完成 \(store.completedTodayHabits.count) 项，还有 \(store.pendingTodayHabits.count) 项")
                        .font(.caption)
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                ProgressView(value: store.overallTodayProgress)
                    .tint(PlanetTheme.violet)
                    .accessibilityLabel("今日总体进度")
                Text(store.overallTodayProgress, format: .percent.precision(.fractionLength(0)))
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.violet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            MascotView(mood: store.pendingTodayHabits.isEmpty ? .celebrating : .resting, size: 116)
                .frame(width: 120)
        }
        .planetPanel(padding: 18)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TodayFilter.allCases) { item in
                    FilterPill(title: item.title, value: item, selection: $filter)
                }
            }
            .padding(.vertical, 1)
        }
        .accessibilityLabel("今日任务筛选")
    }

    @ViewBuilder
    private var habitContent: some View {
        if displayedHabits.isEmpty {
            EmptyStateView(
                mood: filter == .completed ? .reading : .celebrating,
                title: filter == .completed ? "还没有完成的习惯" : "这一组已经清空",
                message: filter == .completed ? "完成一次打卡后，星光会出现在这里。" : "做得很好，去看看今天的全部记录吧。"
            )
            .frame(maxWidth: .infinity)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(displayedHabits) { habit in
                    HabitListRow(
                        habit: habit,
                        progress: store.todayProgress[habit.id],
                        onCheckIn: { Task { await store.checkIn(habitID: habit.id) } }
                    )
                }
            }
        }
    }

    private var progressMessage: String {
        store.pendingTodayHabits.isEmpty ? "今日星光全部点亮" : "已经在轨道上了"
    }

    private var dayGreeting: String {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: store.today)
        switch hour {
        case 5..<11: return "早上好，小星球醒来了"
        case 11..<14: return "中午好，给自己一点光"
        case 14..<19: return "下午好，继续稳稳前进"
        default: return "晚上好，收好今天的星光"
        }
    }
}
