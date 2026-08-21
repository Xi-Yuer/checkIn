import Charts
import SwiftUI
import UIKit

struct StatisticsView: View {
    @ObservedObject var store: AppStore

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        ZStack {
            PlanetAtmosphere()

            ScrollView {
                VStack(spacing: 14) {
                    pageHeader
                    statisticsHero
                    trendPanel
                    heatmapPanel
                }
                .frame(maxWidth: 760)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.locale, chineseLocale)
        .task {
            await store.refreshStatistics()
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("统计")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(intervalTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            statsSticker("StatsMoon", height: 42)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var statisticsHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("星光进度")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.violet)
            Text(completionHeadline)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
            Text(completionMessage)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Capsule()
                .fill(PlanetTheme.mutedSurface)
                .frame(height: 8)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(PlanetTheme.mint)
                            .frame(width: max(8, geo.size.width * store.statistics.completionRate))
                    }
                }
                .clipShape(Capsule())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 96)
        .qCard(padding: 16)
        .overlay(alignment: .bottomTrailing) {
            statsSticker("StatsClipboard", height: 100)
                .offset(y: -8)
        }
        .padding(.horizontal, 16)
    }

    private var chineseLocale: Locale { Locale(identifier: "zh_CN") }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("完成趋势", symbol: "chart.bar.fill")

            Picker("统计周期", selection: periodBinding) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.shortTitle).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))

            HStack(spacing: 8) {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PlanetTheme.violet)
                .accessibilityLabel("上一个统计周期")

                Text(intervalTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.primaryText)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button {
                    movePeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 44, height: 36)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveForward ? PlanetTheme.violet : PlanetTheme.separator)
                .disabled(!canMoveForward)
                .accessibilityLabel("下一个统计周期")
            }

            if chartPoints.isEmpty {
                compactEmptyState("这个周期还没有计划数据", sticker: "StatsCheer")
            } else {
                trendChart
            }
        }
        .qCard(padding: 16)
        .padding(.horizontal, 16)
    }

    private var trendChart: some View {
        let plotWidth = CGFloat(max(chartPoints.count, 1)) * Self.trendSlotWidth

        return ZStack(alignment: .leading) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    trendBarChart
                        .frame(width: plotWidth, height: 200)
                        .padding(.leading, 36)
                        .overlay(alignment: .trailing) {
                            Color.clear.frame(width: 1, height: 1).id("trendEnd")
                        }
                }
                .onAppear { pinTrendChart(proxy) }
                .onChange(of: intervalTitle) { _ in
                    pinTrendChart(proxy)
                }
            }

            trendYAxisLabels
                .frame(width: 36, height: 168)
                .padding(.top, 4)
                .background(PlanetTheme.surface.opacity(0.94))
        }
        .frame(height: 200)
        .id("\(store.statistics.period.rawValue)-\(intervalTitle)-\(chartPoints.count)")
    }

    private func pinTrendChart(_ proxy: ScrollViewProxy) {
        guard store.statistics.period != .week else { return }
        proxy.scrollTo("trendEnd", anchor: .trailing)
    }

    private var trendYAxisLabels: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text("100%")
            Spacer()
            Text("50%")
            Spacer()
            Text("0%")
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(PlanetTheme.secondaryText)
        .accessibilityHidden(true)
    }

    private var trendBarChart: some View {
        Chart(chartPoints) { point in
            BarMark(
                x: .value("序号", point.index),
                y: .value("完成率", point.completionRate),
                width: .fixed(Self.trendBarWidth)
            )
            .foregroundStyle(
                point.completionRate >= 1
                    ? PlanetTheme.mint.gradient
                    : PlanetTheme.violet.gradient
            )
            .cornerRadius(8)
            .accessibilityLabel(point.accessibilityLabel)
            .accessibilityValue(
                Text(point.completionRate, format: .percent.precision(.fractionLength(0)))
            )
        }
        .chartXScale(domain: -0.5 ... Double(max(chartPoints.count, 1)) - 0.5)
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(PlanetTheme.separator)
            }
        }
        .chartXAxis {
            AxisMarks(values: chartPoints.map(\.index)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self),
                       let point = chartPoints.first(where: { $0.index == index }) {
                        Text(point.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                }
                .foregroundStyle(PlanetTheme.secondaryText)
            }
        }
    }

    private var heatmapPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                panelTitle("星光日历", symbol: "calendar")
                Spacer()
                heatmapLegend
            }

            if store.statistics.daily.isEmpty {
                compactEmptyState("有计划的日期会在这里留下星光", sticker: "StatsCloudPeek")
            } else if store.statisticsPeriod == .year {
                yearHeatmap
            } else {
                LazyVGrid(columns: heatmapColumns, spacing: 4) {
                    ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(PlanetTheme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(Array(heatmapCells.enumerated()), id: \.offset) { _, statistic in
                        if let statistic {
                            HeatmapDayView(
                                statistic: statistic,
                                showsDayNumber: true
                            )
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .qCard(padding: 16)
        .padding(.horizontal, 16)
    }

    private var periodBinding: Binding<StatisticsPeriod> {
        Binding(
            get: { store.statisticsPeriod },
            set: { period in
                Task { await store.refreshStatistics(period: period, anchor: store.statisticsAnchor) }
            }
        )
    }

    private static let trendBarWidth: CGFloat = 28
    private static let trendSlotWidth: CGFloat = 48

    private var chartPoints: [StatisticsChartPoint] {
        let points: [StatisticsChartPoint]
        if store.statistics.period == .year {
            let grouped = Dictionary(grouping: store.statistics.chartDaily) {
                calendar.dateComponents([.year, .month], from: $0.date)
            }
            points = grouped.compactMap { components, days in
                guard let date = calendar.date(from: components) else { return nil }
                return StatisticsChartPoint(
                    id: DayKey(date: date, calendar: calendar).rawValue,
                    index: 0,
                    label: "\(calendar.component(.month, from: date))月",
                    planned: days.reduce(0) { $0 + $1.plannedTaskCount },
                    completed: days.reduce(0) { $0 + $1.completedTaskCount }
                )
            }
            .sorted { $0.id < $1.id }
        } else {
            points = store.statistics.chartDaily.map { statistic in
                let label: String
                if store.statistics.period == .week {
                    label = statistic.date.formatted(.dateTime.weekday(.abbreviated).locale(chineseLocale))
                } else {
                    label = "\(calendar.component(.day, from: statistic.date))日"
                }
                return StatisticsChartPoint(
                    id: statistic.dayKey,
                    index: 0,
                    label: label,
                    planned: statistic.plannedTaskCount,
                    completed: statistic.completedTaskCount
                )
            }
        }

        return points.enumerated().map { offset, point in
            StatisticsChartPoint(
                id: point.id,
                index: offset,
                label: point.label,
                planned: point.planned,
                completed: point.completed
            )
        }
    }

    private var heatmapCells: [DailyStatistic?] {
        guard let first = store.statistics.daily.first else { return [] }
        let weekday = calendar.component(.weekday, from: first.date)
        let leadingEmptyCount = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leadingEmptyCount) + store.statistics.daily.map(Optional.some)
    }

    private var heatmapColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 18, maximum: 44), spacing: 5), count: 7)
    }

    private var yearHeatmap: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .top), count: 3),
            spacing: 14
        ) {
            ForEach(yearMonthSnapshots) { month in
                YearMonthHeatmapTile(month: month)
            }
        }
    }

    private var yearMonthSnapshots: [YearMonthSnapshot] {
        let today = calendar.startOfDay(for: store.today)
        let statsByKey = Dictionary(uniqueKeysWithValues: store.statistics.daily.map { ($0.dayKey, $0) })
        let start = store.statistics.interval.start

        return (0..<12).compactMap { offset in
            guard let monthDate = calendar.date(byAdding: .month, value: offset, to: start),
                  let monthInterval = calendar.dateInterval(of: .month, for: monthDate) else {
                return nil
            }

            let weekday = calendar.component(.weekday, from: monthInterval.start)
            let leadingEmpty = (weekday - calendar.firstWeekday + 7) % 7
            var cells: [YearMonthSnapshot.Cell] = Array(
                repeating: .padding,
                count: leadingEmpty
            )
            var plannedDays = 0
            var completedDays = 0
            var cursor = monthInterval.start

            while cursor < monthInterval.end {
                let key = DayKey(date: cursor, calendar: calendar).rawValue
                if cursor > today {
                    cells.append(.future)
                } else if let statistic = statsByKey[key] {
                    cells.append(.day(statistic))
                    if statistic.plannedTaskCount > 0 {
                        plannedDays += 1
                        if statistic.completedTaskCount >= statistic.plannedTaskCount {
                            completedDays += 1
                        }
                    }
                } else {
                    cells.append(.future)
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
                cursor = next
            }

            return YearMonthSnapshot(
                id: keyPrefix(for: monthDate),
                title: "\(calendar.component(.month, from: monthDate))月",
                cells: cells,
                plannedDays: plannedDays,
                completedDays: completedDays
            )
        }
    }

    private func keyPrefix(for month: Date) -> String {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)"
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var completionHeadline: String {
        store.statistics.plannedTaskDays == 0
            ? "等待第一颗星"
            : store.statistics.completionRate.formatted(.percent.precision(.fractionLength(0)).locale(chineseLocale))
    }

    private var completionMessage: String {
        guard store.statistics.plannedTaskDays > 0 else {
            return "建立一个习惯，开始记录属于你的轨迹。"
        }
        return "完成 \(store.statistics.completedTaskDays) / \(store.statistics.plannedTaskDays) 个计划任务日"
    }

    private var intervalTitle: String {
        let start = store.statistics.interval.start
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: store.statistics.interval.end)
            ?? store.statistics.interval.end
        switch store.statisticsPeriod {
        case .week:
            return "\(chineseDate(start, .dateTime.month().day())) – \(chineseDate(inclusiveEnd, .dateTime.month().day()))"
        case .month:
            return chineseDate(start, .dateTime.year().month(.wide))
        case .year:
            return chineseDate(start, .dateTime.year())
        }
    }

    private var canMoveForward: Bool {
        guard let next = shiftedAnchor(by: 1) else { return false }
        let component: Calendar.Component
        switch store.statisticsPeriod {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        guard let nextInterval = calendar.dateInterval(of: component, for: next),
              let currentInterval = calendar.dateInterval(of: component, for: store.today) else {
            return false
        }
        return nextInterval.start <= currentInterval.start
    }

    private func movePeriod(by value: Int) {
        guard let anchor = shiftedAnchor(by: value) else { return }
        Task { await store.refreshStatistics(anchor: anchor) }
    }

    private func shiftedAnchor(by value: Int) -> Date? {
        let component: Calendar.Component
        switch store.statisticsPeriod {
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.date(byAdding: component, value: value, to: store.statisticsAnchor)
    }

    private func chineseDate(_ date: Date, _ style: Date.FormatStyle) -> String {
        date.formatted(style.locale(chineseLocale))
    }

    private func panelTitle(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(PlanetTheme.primaryText)
            .symbolRenderingMode(.hierarchical)
    }

    private func statsSticker(_ name: String, height: CGFloat) -> some View {
        Image(name)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height)
            .accessibilityHidden(true)
    }

    private func compactEmptyState(_ message: String, sticker: String) -> some View {
        HStack(spacing: 12) {
            statsSticker(sticker, height: 64)
            Text(message)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var heatmapLegend: some View {
        HStack(spacing: 5) {
            Text("少")
            ForEach(CompletionIntensity.allCasesForDisplay, id: \.rawValue) { intensity in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(intensity.color)
                    .frame(width: 11, height: 11)
            }
            Text("多")
        }
        .font(.caption2)
        .foregroundStyle(PlanetTheme.secondaryText)
        .accessibilityHidden(true)
    }
}

struct ProfileView: View {
    @ObservedObject var store: AppStore
    var onManageHabits: () -> Void = {}

    var body: some View {
        SettingsView(store: store, onManageHabits: onManageHabits)
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore
    var onManageHabits: () -> Void = {}

    var body: some View {
        ZStack {
            PlanetAtmosphere()

            ScrollView {
                VStack(spacing: 16) {
                    pageHeader
                    profileHero
                    menuCard
                }
                .frame(maxWidth: 720)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.refreshNotifications()
            await store.refreshStatistics()
        }
    }

    private var pageHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("我的")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(profileSubtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Image("StatsMoon")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(height: 42)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    private var profileHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("小星星")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)

            Text("和这颗小星球一起慢慢变亮")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.secondaryText)

            HStack(spacing: 8) {
                profileChip(value: "\(activeHabitCount)", label: "习惯")
                profileChip(value: "\(currentStreak)", label: "连续")
                profileChip(value: "\(bestStreak)", label: "最佳")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 96)
        .qCard(padding: 16)
        .overlay(alignment: .bottomTrailing) {
            MascotView(mood: .ready, size: 118)
                .offset(x: 6, y: 12)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
    }

    private var menuCard: some View {
        VStack(spacing: 0) {
            Button(action: onManageHabits) {
                menuRow(title: "习惯管理", symbol: "square.grid.2x2", tint: PlanetTheme.violet)
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                ReminderSettingsView(store: store)
            } label: {
                menuRow(
                    title: "打卡提醒",
                    symbol: "bell.fill",
                    tint: PlanetTheme.gold,
                    value: reminderSummary
                )
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                ThemeSettingsView(store: store)
            } label: {
                menuRow(title: "主题设置", symbol: "paintpalette.fill", tint: PlanetTheme.lavender)
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                DataPrivacyView()
            } label: {
                menuRow(title: "数据备份", symbol: "archivebox.fill", tint: PlanetTheme.mint)
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                AboutCheckInView(onReplayOnboarding: store.showOnboardingAgain)
            } label: {
                menuRow(title: "关于我们", symbol: "sparkles", tint: PlanetTheme.sky)
            }
            .buttonStyle(.plain)
        }
        .qCard(padding: 8)
        .padding(.horizontal, 16)
    }

    private var activeHabitCount: Int {
        store.habits.filter { !$0.isArchived }.count
    }

    private var currentStreak: Int { store.statistics.currentStreak }
    private var bestStreak: Int { store.statistics.bestStreak }

    private var profileSubtitle: String {
        if currentStreak > 0 {
            return "坚持打卡第 \(currentStreak) 天"
        }
        if bestStreak > 0 {
            return "曾经连续 \(bestStreak) 天"
        }
        return "开始你的第一天打卡"
    }

    private var reminderSummary: String? {
        let times = store.habits
            .filter { !$0.isArchived && $0.reminderEnabled }
            .compactMap { habit -> String? in
                guard let hour = habit.reminderHour, let minute = habit.reminderMinute else { return nil }
                return String(format: "%02d:%02d", hour, minute)
            }
            .sorted()
        return times.first
    }

    private var menuDivider: some View {
        Divider()
            .overlay(PlanetTheme.separator.opacity(0.55))
            .padding(.leading, 66)
    }

    private func profileChip(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.primaryText)
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(PlanetTheme.mutedSurface)
        .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.chip, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    private func menuRow(title: String, symbol: String, tint: Color, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 40, height: 40)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.primaryText)

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(PlanetTheme.violet)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(PlanetTheme.softViolet)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PlanetTheme.separator)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

private struct ThemeSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            ScrollView {
                VStack(spacing: 0) {
                    Toggle(isOn: soundBinding) {
                        settingsLabel("打卡声音", symbol: "speaker.wave.2")
                    }
                    .tint(PlanetTheme.violet)
                    .frame(minHeight: 52)

                    Divider().overlay(PlanetTheme.separator.opacity(0.7))

                    Toggle(isOn: hapticsBinding) {
                        settingsLabel("触感反馈", symbol: "iphone.radiowaves.left.and.right")
                    }
                    .tint(PlanetTheme.violet)
                    .frame(minHeight: 52)

                    Divider().overlay(PlanetTheme.separator.opacity(0.7))

                    VStack(alignment: .leading, spacing: 10) {
                        settingsLabel("外观", symbol: "circle.lefthalf.filled")
                        Picker("外观", selection: appearanceBinding) {
                            ForEach(AppAppearance.allCases) { appearance in
                                Text(appearance.title).tag(appearance)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 12)
                }
                .qCard(padding: 14)
                .padding(16)
            }
        }
        .navigationTitle("主题设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var soundBinding: Binding<Bool> {
        Binding(get: { store.settings.soundEnabled }, set: store.setSoundEnabled)
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticsEnabled }, set: store.setHapticsEnabled)
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(get: { store.settings.appearance }, set: store.setAppearance)
    }

    private func settingsLabel(_ title: String, symbol: String) -> some View {
        Label {
            Text(title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(PlanetTheme.primaryText)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PlanetTheme.violet)
                .frame(width: 24)
        }
    }
}

private struct ReminderSettingsView: View {
    @ObservedObject var store: AppStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: notificationSymbol)
                            .foregroundStyle(notificationColor)
                            .frame(width: 24)
                        Text("通知权限")
                            .font(.system(.body, design: .rounded, weight: .medium))
                            .foregroundStyle(PlanetTheme.primaryText)
                        Spacer()
                        Text(notificationTitle)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(notificationColor)
                    }

                    Text(notificationMessage)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if store.notificationStatus == .denied {
                        Button {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            openURL(url)
                        } label: {
                            Text("前往系统设置")
                        }
                        .buttonStyle(QActionButtonStyle())
                    } else {
                        Button {
                            Task { await store.refreshNotifications() }
                        } label: {
                            Text("刷新通知状态")
                        }
                        .buttonStyle(QActionButtonStyle())
                    }
                }
                .qCard(padding: 16)
                .padding(16)
            }
        }
        .navigationTitle("打卡提醒")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshNotifications() }
    }

    private var notificationTitle: String {
        switch store.notificationStatus {
        case .notDetermined: "尚未开启"
        case .denied: "未授权"
        case .authorized: "已开启"
        case .provisional: "临时允许"
        case .ephemeral: "本次允许"
        }
    }

    private var notificationMessage: String {
        switch store.notificationStatus {
        case .notDetermined:
            "为习惯设置提醒时间后，系统会询问通知权限。"
        case .denied:
            "提醒意图会保留，但需要在系统设置中允许通知后才能送达。"
        case .authorized, .provisional, .ephemeral:
            "提醒只保存在这台设备上，可在习惯编辑页分别设置。"
        }
    }

    private var notificationColor: Color {
        switch store.notificationStatus {
        case .denied: PlanetTheme.coral
        case .authorized, .provisional, .ephemeral: PlanetTheme.mint
        case .notDetermined: PlanetTheme.gold
        }
    }

    private var notificationSymbol: String {
        switch store.notificationStatus {
        case .denied: "bell.slash"
        case .authorized, .provisional, .ephemeral: "bell.fill"
        case .notDetermined: "bell.badge"
        }
    }
}

private struct StatisticsChartPoint: Identifiable {
    let id: String
    let index: Int
    let label: String
    let planned: Int
    let completed: Int

    var completionRate: Double {
        guard planned > 0 else { return 0 }
        return Double(completed) / Double(planned)
    }

    var accessibilityLabel: String {
        "\(label)，完成 \(completed) / \(planned)"
    }
}

private struct YearMonthSnapshot: Identifiable {
    enum Cell: Equatable {
        case padding
        case future
        case day(DailyStatistic)
    }

    let id: String
    let title: String
    let cells: [Cell]
    let plannedDays: Int
    let completedDays: Int
}

private struct YearMonthHeatmapTile: View {
    let month: YearMonthSnapshot

    private let gap: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 2) {
                Text(month.title)
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(
                    month.plannedDays > 0
                        ? (Double(month.completedDays) / Double(month.plannedDays))
                            .formatted(.percent.precision(.fractionLength(0)))
                        : " "
                )
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.violet)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(month.plannedDays > 0 ? 1 : 0)
            }
            .frame(height: 18, alignment: .leading)

            VStack(spacing: gap) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: gap) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            yearDot(cell)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(month.title)
        .accessibilityValue(accessibilityValue)
    }

    private var rows: [[YearMonthSnapshot.Cell]] {
        stride(from: 0, to: month.cells.count, by: 7).map { start in
            let slice = Array(month.cells[start..<min(start + 7, month.cells.count)])
            return slice + Array(repeating: .padding, count: 7 - slice.count)
        }
    }

    private var accessibilityValue: String {
        guard month.plannedDays > 0 else { return "没有计划" }
        return "完成 \(month.completedDays) / \(month.plannedDays) 个计划日"
    }

    private func yearDot(_ cell: YearMonthSnapshot.Cell) -> some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(fill(for: cell))
    }

    private func fill(for cell: YearMonthSnapshot.Cell) -> Color {
        switch cell {
        case .padding:
            Color.clear
        case .future:
            PlanetTheme.separator.opacity(0.12)
        case .day(let statistic):
            statistic.plannedTaskCount == 0
                ? PlanetTheme.separator.opacity(0.14)
                : statistic.intensity.color
        }
    }
}

private struct HeatmapDayView: View {
    let statistic: DailyStatistic
    let showsDayNumber: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(statistic.plannedTaskCount == 0 ? PlanetTheme.separator.opacity(0.14) : statistic.intensity.color)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if showsDayNumber {
                    Text("\(Calendar.autoupdatingCurrent.component(.day, from: statistic.date))")
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(statistic.intensity == .complete ? Color.white : PlanetTheme.primaryText)
                        .minimumScaleFactor(0.7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statistic.date.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))
            .accessibilityValue(
                statistic.plannedTaskCount == 0
                    ? "没有计划"
                    : "完成 \(statistic.completedTaskCount) / \(statistic.plannedTaskCount)"
            )
    }
}

private struct DataPrivacyView: View {
    var body: some View {
        ZStack {
            PlanetBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MascotView(mood: .resting, size: 112)
                        .frame(maxWidth: .infinity)
                    informationBlock(
                        title: "只在本机保存",
                        message: "习惯与打卡记录保存在这台设备的应用数据中，不会上传到我们的服务器。",
                        symbol: "iphone"
                    )
                    informationBlock(
                        title: "跟随系统备份",
                        message: "数据可能随你的设备系统备份保存；是否备份由系统设置决定。",
                        symbol: "externaldrive.fill"
                    )
                    informationBlock(
                        title: "没有云同步",
                        message: "当前版本不提供账号、跨设备同步、广告追踪或数据分析。",
                        symbol: "icloud.slash.fill"
                    )
                }
                .frame(maxWidth: 620)
                .padding(16)
            }
        }
        .navigationTitle("数据备份")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func informationBlock(title: String, message: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(PlanetTheme.violet)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .planetPanel()
    }
}

private struct AboutCheckInView: View {
    var onReplayOnboarding: () -> Void = {}

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            VStack(spacing: 18) {
                MascotView(mood: .ready, size: 144)
                VStack(spacing: 7) {
                    Text("打卡小星球")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("养成好习惯，每天进步一点点")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                Text("版本 \(appVersion)")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(PlanetTheme.secondaryText)

                Button("重看新手引导", action: onReplayOnboarding)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.violet)
                    .padding(.top, 8)
            }
            .frame(maxWidth: 420)
            .padding(28)
        }
        .navigationTitle("关于我们")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
}

private extension StatisticsPeriod {
    var shortTitle: String {
        switch self {
        case .week: "周"
        case .month: "月"
        case .year: "年"
        }
    }
}

private extension CompletionIntensity {
    static var allCasesForDisplay: [CompletionIntensity] { [.none, .partial, .complete] }

    var color: Color {
        switch self {
        case .none: PlanetTheme.separator.opacity(0.42)
        case .partial: PlanetTheme.lavender.opacity(0.68)
        case .complete: PlanetTheme.mint
        }
    }
}
