import SwiftUI

struct HabitDetailView: View {
    @ObservedObject var store: AppStore
    let habitID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var historyCount = 0

    private let calendar = Calendar.autoupdatingCurrent
    private let scheduleService = TaskScheduleService()
    private let streakCalculator = StreakCalculator()

    private var habit: TaskDTO? { store.habit(id: habitID) }
    private var progress: DailyProgress? { store.todayProgress[habitID] }
    private var habitHistory: [CheckInDTO] { store.checkIns.filter { $0.taskID == habitID } }

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            if let habit {
                ScrollView {
                    VStack(spacing: 12) {
                        hero(habit)
                        info(habit)
                        todayAction(habit)
                        heatmap(habit)
                        if !habit.note.isEmpty { note(habit) }
                        badgeShelf
                    }
                    .frame(maxWidth: 720)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .refreshable { await store.loadHistory(for: habitID) }
            } else {
                EmptyStateView(
                    mood: .ready,
                    title: "这个习惯已不在轨道上",
                    message: "它可能已经被删除，返回习惯列表看看吧。"
                )
                .qCard()
                .padding(.horizontal, 16)
            }
        }
        .navigationTitle("习惯详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("编辑习惯", systemImage: "pencil")
                    }
                    if let habit {
                        Button {
                            Task {
                                if habit.isArchived {
                                    await store.resumeHabit(id: habit.id)
                                } else {
                                    await store.pauseHabit(id: habit.id)
                                }
                            }
                        } label: {
                            Label(habit.isArchived ? "恢复习惯" : "暂停习惯", systemImage: habit.isArchived ? "play.fill" : "pause.fill")
                        }
                        Button(role: .destructive) {
                            prepareDeletion()
                        } label: {
                            Label("删除习惯", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("更多操作")
            }
        }
        .task(id: habitID) {
            await store.loadHistory(for: habitID)
        }
        .sheet(isPresented: $showingEditor) {
            if let habit { HabitEditorView(store: store, habit: habit) }
        }
        .confirmationDialog(
            habit.map { "删除“\($0.title)”？" } ?? "删除习惯？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除习惯和 \(historyCount) 条记录", role: .destructive) {
                Task {
                    if await store.deleteHabit(id: habitID) { dismiss() }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复；暂停则会保留全部历史。")
        }
    }

    private func hero(_ habit: TaskDTO) -> some View {
        let streak = streakCalculator.currentStreak(
            task: habit,
            checkIns: habitHistory,
            through: store.today,
            calendar: calendar
        )
        let monthRate = monthlyCompletionRate(habit).formatted(.percent.precision(.fractionLength(0)))

        return HStack(alignment: .center, spacing: 14) {
            HabitIconBadge(habit: habit, size: 64)

            VStack(alignment: .leading, spacing: 5) {
                Text(habit.title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text("本月 \(monthRate)")
                    Text("·")
                    Text("累计 \(historyCountValue) 次")
                    if habit.isArchived {
                        Text("·")
                        Text("已暂停")
                            .foregroundStyle(PlanetTheme.gold)
                    }
                }
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 1) {
                Text("\(streak)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                    .monospacedDigit()
                Text("连续")
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("连续 \(streak) 天")
        }
        .qCard(padding: 14)
    }

    private func todayAction(_ habit: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今日目标")
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                    Text(todayStatusText(habit))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                Spacer()
                ProgressRing(
                    progress: progress?.fractionComplete ?? 0,
                    lineWidth: 7,
                    size: 66,
                    color: PlanetTheme.mint
                )
            }

            if habit.isArchived {
                Button {
                    Task { await store.resumeHabit(id: habit.id) }
                } label: {
                    Label("恢复这个习惯", systemImage: "play.fill")
                }
                .buttonStyle(QActionButtonStyle())
            } else if scheduleService.isScheduled(habit, on: store.today, calendar: calendar) {
                Button {
                    Task { await store.checkIn(habitID: habit.id) }
                } label: {
                    Label(
                        progress?.isComplete == true ? "今日已完成" : "完成一次打卡",
                        systemImage: progress?.isComplete == true ? "checkmark.circle.fill" : "sparkles"
                    )
                }
                .buttonStyle(QActionButtonStyle())
                .disabled(progress?.isComplete == true || store.processingHabitIDs.contains(habit.id))

                if (progress?.completed ?? 0) > 0 {
                    Button {
                        Task { await store.undoLastCheckIn(habitID: habit.id) }
                    } label: {
                        Label("撤销最近一次", systemImage: "arrow.uturn.backward")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(PlanetTheme.violet)
                }
            } else {
                Label("今天不是计划日", systemImage: "moon.stars.fill")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(PlanetTheme.mutedSurface)
                    .clipShape(Capsule())
            }
        }
        .qCard()
    }

    private func heatmap(_ habit: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("最近五周")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text("颜色越深，完成度越高")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 8) {
                ForEach(orderedWeekdays) { weekday in
                    Text(weekday.shortTitle)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                ForEach(recentDates, id: \.self) { date in
                    HabitHeatmapCell(
                        date: date,
                        fraction: completionFraction(on: date, habit: habit),
                        isScheduled: scheduleService.isScheduled(
                            habit,
                            on: date,
                            calendar: calendar,
                            excludingPaused: false
                        ) && date <= calendar.startOfDay(for: store.today),
                        isToday: calendar.isDateInToday(date)
                    )
                }
            }
        }
        .qCard()
    }

    private func note(_ habit: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("写给自己的话")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.primaryText)
            Text(habit.note)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(PlanetTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .qCard(padding: 14)
    }

    private func info(_ habit: TaskDTO) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("习惯信息")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.primaryText)
                .padding(.bottom, 4)

            infoRow(symbol: "calendar", title: "重复计划", value: habit.schedule.compactTitle)
            infoDivider
            infoRow(symbol: "flag.fill", title: "每日目标", value: "\(habit.dailyTarget) 次")
            infoDivider
            infoRow(symbol: "bell.fill", title: "打卡提醒", value: reminderText(habit))
            if let startDate = habit.startDate {
                infoDivider
                infoRow(symbol: "play.circle.fill", title: "开始日期", value: formattedDate(startDate))
            }
            if let endDate = habit.endDate {
                infoDivider
                infoRow(symbol: "flag.checkered", title: "结束日期", value: formattedDate(endDate))
            }
            if habit.isArchived {
                infoDivider
                infoRow(symbol: "pause.fill", title: "状态", value: "已暂停")
            }
        }
        .qCard(padding: 14)
    }

    private func infoRow(symbol: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(PlanetTheme.violet)
                .frame(width: 18)
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private var infoDivider: some View {
        Rectangle()
            .fill(PlanetTheme.separator.opacity(0.4))
            .frame(height: 1)
    }

    private func reminderText(_ habit: TaskDTO) -> String {
        guard habit.reminderEnabled, let hour = habit.reminderHour, let minute = habit.reminderMinute else {
            return "未开启"
        }
        return String(format: "%02d:%02d", hour, minute)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var badgeShelf: some View {
        if !store.badges.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("星光徽章")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(store.badges) { badge in
                            VStack(spacing: 7) {
                                Image(systemName: badge.kind.symbolName)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(PlanetTheme.gold)
                                Text(badge.kind.title)
                                    .font(.system(.caption, design: .rounded, weight: .semibold))
                                    .foregroundStyle(PlanetTheme.primaryText)
                                    .lineLimit(1)
                            }
                            .frame(width: 108, height: 82)
                            .background(PlanetTheme.mutedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.nest, style: .continuous))
                        }
                    }
                }
            }
            .qCard()
        }
    }

    private var historyCountValue: Int {
        habitHistory.reduce(0) { $0 + $1.value }
    }

    private var recentDates: [Date] {
        let today = calendar.startOfDay(for: store.today)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let firstDate = calendar.date(byAdding: .weekOfYear, value: -4, to: weekStart) ?? weekStart
        return (0..<35).compactMap { calendar.date(byAdding: .day, value: $0, to: firstDate) }
    }

    private var orderedWeekdays: [Weekday] {
        let weekdays = Weekday.allCases
        let firstIndex = max(0, min(weekdays.count - 1, calendar.firstWeekday - 1))
        return Array(weekdays[firstIndex...] + weekdays[..<firstIndex])
    }

    private func completionFraction(on date: Date, habit: TaskDTO) -> Double {
        let key = DayKey(date: date, calendar: calendar).rawValue
        let total = habitHistory.filter { $0.dayKey == key }.reduce(0) { $0 + $1.value }
        return min(1, Double(total) / Double(max(1, habit.dailyTarget)))
    }

    private func monthlyCompletionRate(_ habit: TaskDTO) -> Double {
        guard let interval = calendar.dateInterval(of: .month, for: store.today) else { return 0 }
        let end = min(store.today, interval.end)
        var date = interval.start
        var planned = 0
        var completed = 0
        while date <= end {
            if scheduleService.isScheduled(habit, on: date, calendar: calendar, excludingPaused: false) {
                planned += 1
                if completionFraction(on: date, habit: habit) >= 1 { completed += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        guard planned > 0 else { return 0 }
        return Double(completed) / Double(planned)
    }

    private func todayStatusText(_ habit: TaskDTO) -> String {
        let completed = progress?.completed ?? 0
        let target = progress?.target ?? scheduleService.dailyTarget(for: habit, on: store.today, calendar: calendar)
        if progress?.isComplete == true { return "已完成 \(completed)/\(target)，星光点亮了" }
        return "已完成 \(completed)/\(target)，还差 \(max(0, target - completed)) 次"
    }

    private func prepareDeletion() {
        Task {
            historyCount = await store.historyCount(for: habitID)
            showingDeleteConfirmation = true
        }
    }
}

private struct HabitHeatmapCell: View {
    let date: Date
    let fraction: Double
    let isScheduled: Bool
    let isToday: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(fillColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isToday {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PlanetTheme.lavender, lineWidth: 2)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(date.formatted(.dateTime.month().day()))
            .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
    }

    private var fillColor: Color {
        guard isScheduled else { return PlanetTheme.separator.opacity(0.18) }
        if fraction >= 1 { return PlanetTheme.mint }
        if fraction > 0 { return PlanetTheme.mint.opacity(0.42) }
        return PlanetTheme.mutedSurface
    }
}
