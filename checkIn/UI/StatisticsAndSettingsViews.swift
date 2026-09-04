import Charts
import StoreKit
import SwiftUI
import UIKit

struct StatisticsView: View {
    @ObservedObject var store: AppStore

    @Environment(\.locale) private var locale

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
                    label: date.formatted(.dateTime.month(.abbreviated).locale(locale)),
                    planned: days.reduce(0) { $0 + $1.plannedTaskCount },
                    completed: days.reduce(0) { $0 + $1.completedTaskCount }
                )
            }
            .sorted { $0.id < $1.id }
        } else {
            points = store.statistics.chartDaily.map { statistic in
                let label: String
                if store.statistics.period == .week {
                    label = statistic.date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
                } else {
                    label = statistic.date.formatted(.dateTime.day().locale(locale))
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
                title: monthDate.formatted(.dateTime.month(.abbreviated).locale(locale)),
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
        let formatter = DateFormatter()
        formatter.locale = locale
        let symbols = formatter.veryShortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else { return Weekday.allCases.map(\.shortTitle) }
        let start = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[start...] + symbols[..<start])
    }

    private var completionHeadline: String {
        store.statistics.plannedTaskDays == 0
            ? L10n.text("等待第一颗星")
            : store.statistics.completionRate.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    private var completionMessage: String {
        guard store.statistics.plannedTaskDays > 0 else {
            return L10n.text("建立一个习惯，开始记录属于你的轨迹。")
        }
        return L10n.format(
            "完成 %d / %d 个计划任务日",
            store.statistics.completedTaskDays,
            store.statistics.plannedTaskDays
        )
    }

    private var intervalTitle: String {
        let start = store.statistics.interval.start
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: store.statistics.interval.end)
            ?? store.statistics.interval.end
        switch store.statisticsPeriod {
        case .week:
            return "\(localizedDate(start, .dateTime.month().day())) – \(localizedDate(inclusiveEnd, .dateTime.month().day()))"
        case .month:
            return localizedDate(start, .dateTime.year().month(.wide))
        case .year:
            return localizedDate(start, .dateTime.year())
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

    private func localizedDate(_ date: Date, _ style: Date.FormatStyle) -> String {
        date.formatted(style.locale(locale))
    }

    private func panelTitle(_ title: String, symbol: String) -> some View {
        Label(L10n.text(title), systemImage: symbol)
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
            Text(L10n.text(message))
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

    var body: some View {
        SettingsView(store: store)
    }
}

struct SettingsView: View {
    @Environment(\.locale) private var locale
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [PlanetTheme.elevatedSurface, PlanetTheme.mutedSurface, PlanetTheme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    heroScene
                    preferencesCard
                    aboutCard
                    localDataNote
                }
                .frame(maxWidth: 620)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await store.refreshNotifications()
            await store.refreshStatistics()
        }
    }

    private var heroScene: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("ProfileRoomHero")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Hi～")
                    Text(profileSubtitle)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.violet)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(PlanetTheme.surface.opacity(0.94))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(PlanetTheme.lavender.opacity(0.46), lineWidth: 1.5)
                }
                .shadow(color: PlanetTheme.violet.opacity(0.12), radius: 10, y: 5)
                .frame(maxWidth: 220, alignment: .leading)
                // Keep the greeting bubble clear of the metrics card below.
                .offset(x: 22, y: -2)
            }
            .frame(height: 300)

            statsCard
                .padding(.top, 4)
        }
        .padding(.top, 4)
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            metric(label: "已打卡", value: store.completedTodayHabits.count, unit: "项")
            metricDivider
            metric(label: "连续", value: currentStreak, unit: "天")
            metricDivider
            metric(label: "最佳", value: bestStreak, unit: "天")
        }
        .padding(.vertical, 12)
        .background(PlanetTheme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PlanetTheme.lavender.opacity(0.42), lineWidth: 1.5)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.12), radius: 14, y: 7)
        .padding(.horizontal, 16)
    }

    private var preferencesCard: some View {
        VStack(spacing: 0) {
            NavigationLink {
                ThemeSettingsView(store: store)
            } label: {
                menuRow(title: "主题外观", asset: "ProfilePalette")
            }
            .buttonStyle(.plain)

            menuDivider

            NavigationLink {
                GeneralSettingsView(store: store)
            } label: {
                menuRow(title: "通用设置", asset: "ProfileGear")
            }
            .buttonStyle(.plain)
        }
        .background(PlanetTheme.surface.opacity(0.93))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: PlanetTheme.violet.opacity(0.09), radius: 14, y: 6)
        .padding(.horizontal, 16)
    }

    private var aboutCard: some View {
        NavigationLink {
            AboutCheckInView()
        } label: {
            menuRow(title: "关于", asset: "ProfileInfo")
                .background(PlanetTheme.surface.opacity(0.93))
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: PlanetTheme.violet.opacity(0.09), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var localDataNote: some View {
        Image(localDataNoteAssetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: 390)
            .padding(.horizontal, 18)
            .accessibilityLabel("所有数据仅保存在本机，无需登录，不上传，不提供云备份")
    }

    private var localDataNoteAssetName: String {
        locale.identifier.lowercased().hasPrefix("en")
            ? "ProfileLocalDataEnglish"
            : "ProfileLocalData"
    }

    private var activeHabitCount: Int {
        store.habits.filter { !$0.isArchived }.count
    }

    private var currentStreak: Int { store.statistics.currentStreak }
    private var bestStreak: Int { store.statistics.bestStreak }

    private var profileSubtitle: String {
        if currentStreak > 0 {
            return L10n.format("坚持打卡第 %d 天", currentStreak)
        }
        if bestStreak > 0 {
            return L10n.format("曾经连续 %d 天", bestStreak)
        }
        return L10n.text("开始你的第一天打卡")
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(PlanetTheme.separator.opacity(0.55))
            .frame(width: 1, height: 42)
    }

    private var menuDivider: some View {
        Divider()
            .overlay(PlanetTheme.separator.opacity(0.48))
            .padding(.leading, 68)
    }

    private func metric(label: String, value: Int, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(L10n.text(label))
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(value)")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(L10n.text(unit))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(L10n.text(label)) \(value) \(L10n.text(unit))")
    }

    private func menuRow(title: String, asset: String) -> some View {
        HStack(spacing: 12) {
            Image(asset)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 44, height: 44)
            Text(L10n.text(title))
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundStyle(PlanetTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(PlanetTheme.separator)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }
}

private struct ThemeSettingsView: View {
    @ObservedObject var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            ScrollView {
                VStack(spacing: 16) {
                    appearanceCard
                    widgetGuideCard
                }
                .padding(16)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("主题外观")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var appearanceCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                Image("ProfilePalette")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)

                VStack(alignment: .leading) {
                    Text("界面外观")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundStyle(PlanetTheme.primaryText)
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(PlanetTheme.separator.opacity(0.45))

            VStack(spacing: 4) {
                ForEach(AppAppearance.allCases) { appearance in
                    appearanceOption(appearance)
                }
            }
        }
        .padding(18)
        .background(PlanetTheme.surface.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.36), lineWidth: 1)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.08), radius: 16, y: 7)
    }

    private func appearanceOption(_ appearance: AppAppearance) -> some View {
        let selected = store.settings.appearance == appearance
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.78)) {
                store.setAppearance(appearance)
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(optionTint(appearance).opacity(selected ? 0.18 : 0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: optionSymbol(appearance))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(optionTint(appearance))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(appearance.title)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text(appearanceDescription(appearance))
                        .font(.system(.caption2, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }

                Spacer(minLength: 8)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(PlanetTheme.violet)
                } else {
                    Circle()
                        .stroke(PlanetTheme.separator.opacity(0.8), lineWidth: 1.5)
                        .frame(width: 19, height: 19)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(selected ? PlanetTheme.softViolet.opacity(0.72) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var widgetGuideCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("桌面打卡", systemImage: "sparkles")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(PlanetTheme.violet)
                    Text("把打卡放到桌面")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("不用打开 App，也能查看计划并快速打卡")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                widgetPreview
            }

            VStack(spacing: 0) {
                widgetGuideStep(1, symbol: "hand.tap.fill", text: "长按桌面空白处")
                widgetGuideStep(2, symbol: "plus", text: "点击左上角的添加按钮")
                widgetGuideStep(3, symbol: "magnifyingglass", text: "搜索“打卡小星球”")
                widgetGuideStep(4, symbol: "rectangle.3.group.fill", text: "选择喜欢的尺寸并添加")
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(PlanetTheme.mutedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(18)
        .background(PlanetTheme.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.36), lineWidth: 1)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.09), radius: 18, y: 8)
        .accessibilityElement(children: .contain)
    }

    private func widgetGuideStep(_ number: Int, symbol: String, text: String) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(stepColor(number).opacity(0.16))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(stepColor(number))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(L10n.format("第 %d 步", number))
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(stepColor(number))
                Text(L10n.text(text))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if number < 4 {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PlanetTheme.separator)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(PlanetTheme.mint)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
    }

    private var widgetPreview: some View {
        ZStack {
            LinearGradient(
                colors: [PlanetTheme.softViolet, PlanetTheme.lavender.opacity(0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(PlanetTheme.gold)
                    Capsule()
                        .fill(PlanetTheme.primaryText.opacity(0.72))
                        .frame(width: 34, height: 5)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("12")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("天")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                Capsule()
                    .fill(PlanetTheme.violet)
                    .frame(maxWidth: .infinity, minHeight: 12)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 6, weight: .heavy))
                            .foregroundStyle(.white)
                    }
            }
            .padding(10)
        }
        .frame(width: 92, height: 76)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.18), radius: 9, y: 5)
        .accessibilityHidden(true)
    }

    private func optionSymbol(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }
    }

    private func optionTint(_ appearance: AppAppearance) -> Color {
        switch appearance {
        case .system: PlanetTheme.violet
        case .light: PlanetTheme.gold
        case .dark: Color(hex: "#6366F1")
        }
    }

    private func appearanceDescription(_ appearance: AppAppearance) -> String {
        switch appearance {
        case .system: L10n.text("自动适配系统设置")
        case .light: L10n.text("明亮清爽")
        case .dark: L10n.text("夜间更舒适")
        }
    }

    private func stepColor(_ number: Int) -> Color {
        switch number {
        case 1: PlanetTheme.violet
        case 2: PlanetTheme.coral
        case 3: Color(hex: "#3B82F6")
        default: PlanetTheme.mint
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            ScrollView {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        settingsLabel("语言", caption: "默认跟随系统", symbol: "character.bubble.fill")
                        Spacer(minLength: 8)
                        Picker("语言", selection: languageBinding) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.title).tag(language)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .fixedSize()
                    }
                    .frame(minHeight: 62)

                    Toggle(isOn: hapticsBinding) {
                        settingsLabel("触感反馈", caption: "让每次打卡更有实感", symbol: "hand.tap.fill")
                    }
                    .tint(PlanetTheme.violet)
                    .frame(minHeight: 62)

                    Toggle(isOn: notificationsBinding) {
                        Label {
                            Text("打卡提醒")
                                .font(.system(.body, design: .rounded, weight: .bold))
                                .foregroundStyle(PlanetTheme.primaryText)
                        } icon: {
                            Image(systemName: store.settings.areNotificationsEnabled ? "bell.fill" : "bell.slash.fill")
                                .foregroundStyle(PlanetTheme.violet)
                                .frame(width: 28)
                        }
                    }
                    .tint(PlanetTheme.violet)
                    .frame(minHeight: 62)
                }
                .qCard(padding: 16)
                .padding(16)
            }
        }
        .navigationTitle("通用设置")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { store.settings.appLanguage }, set: store.setLanguage)
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(get: { store.settings.hapticsEnabled }, set: store.setHapticsEnabled)
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.areNotificationsEnabled },
            set: { enabled in
                Task { await store.setNotificationsEnabled(enabled) }
            }
        )
    }

    private func settingsLabel(_ title: String, caption: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text(title))
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(L10n.text(caption))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(PlanetTheme.violet)
                .frame(width: 28)
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
        case .notDetermined: L10n.text("尚未开启")
        case .denied: L10n.text("未授权")
        case .authorized: L10n.text("已开启")
        case .provisional: L10n.text("临时允许")
        case .ephemeral: L10n.text("本次允许")
        }
    }

    private var notificationMessage: String {
        switch store.notificationStatus {
        case .notDetermined:
            L10n.text("为习惯设置提醒时间后，系统会询问通知权限。")
        case .denied:
            L10n.text("提醒意图会保留，但需要在系统设置中允许通知后才能送达。")
        case .authorized, .provisional, .ephemeral:
            L10n.text("提醒只保存在这台设备上，可在习惯编辑页分别设置。")
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
        L10n.format("%@，完成 %d / %d", label, completed, planned)
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
        guard month.plannedDays > 0 else { return L10n.text("没有计划") }
        return L10n.format("完成 %d / %d 个计划日", month.completedDays, month.plannedDays)
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

    @Environment(\.locale) private var locale

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
            .accessibilityLabel(statistic.date.formatted(.dateTime.year().month().day().locale(locale)))
            .accessibilityValue(
                statistic.plannedTaskCount == 0
                    ? L10n.text("没有计划")
                    : L10n.format("完成 %d / %d", statistic.completedTaskCount, statistic.plannedTaskCount)
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
                        message: "习惯与打卡记录保存在这台设备的应用数据中，不会上传到任何服务器。",
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
                Text(L10n.text(title))
                    .font(.headline)
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(L10n.text(message))
                    .font(.subheadline)
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .planetPanel()
    }
}

private struct AboutCheckInView: View {
    @Environment(\.requestReview) private var requestReview
    @State private var isShowingDonation = false

    var body: some View {
        ZStack {
            PlanetAtmosphere()
            ScrollView {
                VStack(spacing: 16) {
                    compactHeader
                    articleCard
                    actionCard
                }
                .frame(maxWidth: 560)
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingDonation) {
            DonationView()
        }
    }

    private var compactHeader: some View {
        HStack(spacing: 14) {
            MascotView(mood: .ready, size: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("打卡小星球")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text("养成好习惯，每天进步一点点")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
                Text(L10n.format("版本 %@", appVersion))
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(PlanetTheme.violet)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private var actionCard: some View {
        VStack(spacing: 10) {
            VStack(spacing: 9) {
                supportButton(
                    title: "给个好评",
                    subtitle: "在 App Store 分享你的使用感受",
                    symbol: "star.fill",
                    tint: PlanetTheme.gold
                ) {
                    requestReview()
                }
                .accessibilityHint(L10n.text("打开系统评分弹窗"))

                supportButton(
                    title: "支持开发",
                    subtitle: "如果这个小星球对你有帮助",
                    symbol: "heart.fill",
                    tint: PlanetTheme.coral
                ) {
                    isShowingDonation = true
                }
                .accessibilityHint(L10n.text("查看微信和支付宝收款码"))
            }
        }
    }

    private var articleCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("写给每一位认真生活的人")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)
                .padding(.bottom, 22)

            articleSection(
                title: "为什么做这个 App",
                body: "做打卡小星球的起点很简单：习惯养成不应该是一件有压力的事。我用过许多越来越复杂的工具，也常常因为繁琐的设置忘记最初想做的那件小事。所以我想做一个安静、轻巧的地方，让你只需要记住今天要做什么，然后认真完成它。"
            )
            articleSection(
                title: "免费，是我的选择",
                body: "打卡小星球可以免费使用。我希望记录生活、培养习惯这件事，不会因为付费墙而变得遥远。你可以安心创建计划、记录打卡、查看自己的进步，不需要为了基础功能订阅。"
            )
            articleSection(
                title: "你的数据，只属于你",
                body: "你的习惯、打卡记录和设置都保存在这台设备上。App 不要求注册账号，不会把这些内容上传到任何服务器，也不会用于广告追踪或数据分析。如果你开启了系统设备备份，数据可能会随系统备份保存，是否备份由你的系统设置决定。"
            )
            articleSection(
                title: "关于隐私",
                body: "我相信，最好的隐私保护不是写一份很长的承诺，而是尽量少收集数据。当前版本不提供账号、云同步或跨设备共享，也不嵌入广告追踪。你的每一次打卡，都是你和自己之间的小约定。"
            )

            Text("谢谢你让这颗小星球，成为生活里的一部分。")
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(PlanetTheme.violet)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 24)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PlanetTheme.surface.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.32), lineWidth: 1)
        }
    }

    private func supportButton(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text(title))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text(L10n.text(subtitle))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlanetTheme.secondaryText.opacity(0.7))
            }
            .padding(.horizontal, 13)
            .frame(minHeight: 64)
            .background(tint.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text(title))
    }

    private func articleSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(L10n.text(title))
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(PlanetTheme.primaryText)
            Text(L10n.text(body))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(PlanetTheme.secondaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 24)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
}

private struct DonationView: View {
    private enum PaymentMethod: String, CaseIterable, Identifiable {
        case weChat
        case alipay

        var id: Self { self }

        var title: String {
            switch self {
            case .weChat: L10n.text("微信")
            case .alipay: L10n.text("支付宝")
            }
        }

        var imageName: String {
            switch self {
            case .weChat: "DonationWeChat"
            case .alipay: "DonationAlipay"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var paymentMethod: PaymentMethod = .weChat

    var body: some View {
        NavigationStack {
            ZStack {
                PlanetAtmosphere()

                ScrollView {
                    VStack(spacing: 16) {
                        Text(L10n.text("感谢你的支持"))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                            .foregroundStyle(PlanetTheme.primaryText)

                        Text(L10n.text("捐赠完全自愿，不会影响任何功能。"))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(PlanetTheme.secondaryText)
                            .multilineTextAlignment(.center)

                        Picker(L10n.text("付款方式"), selection: $paymentMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.title).tag(method)
                            }
                        }
                        .pickerStyle(.segmented)

                        Image(paymentMethod.imageName)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: 330)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .accessibilityLabel(
                                L10n.format("%@收款码", paymentMethod.title)
                            )

                        Text(L10n.format("请使用%@扫码", paymentMethod.title))
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(PlanetTheme.secondaryText)
                    }
                    .frame(maxWidth: 430)
                    .padding(20)
                }
            }
            .navigationTitle(L10n.text("支持开发"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("完成")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private extension StatisticsPeriod {
    var shortTitle: String {
        switch self {
        case .week: L10n.text("周")
        case .month: L10n.text("月")
        case .year: L10n.text("年")
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
