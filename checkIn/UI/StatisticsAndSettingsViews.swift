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
                    periodControls
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
            statsSticker("StatsAstronaut", height: 128)
                .offset(x: -2, y: 8)
        }
        .padding(.horizontal, 16)
    }

    private var periodControls: some View {
        VStack(spacing: 14) {
            Picker("统计周期", selection: periodBinding) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.shortTitle).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))

            HStack(spacing: 10) {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
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
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canMoveForward ? PlanetTheme.violet : PlanetTheme.separator)
                .disabled(!canMoveForward)
                .accessibilityLabel("下一个统计周期")
            }
        }
        .qCard(padding: 12)
        .padding(.horizontal, 16)
    }

    private var chineseLocale: Locale { Locale(identifier: "zh_CN") }

    private var trendPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            panelTitle("完成趋势", symbol: "chart.bar.fill")

            if chartPoints.isEmpty {
                compactEmptyState("这个周期还没有计划数据", sticker: "StatsCheer")
            } else {
                Chart(chartPoints) { point in
                    BarMark(
                        x: .value("日期", point.label),
                        y: .value("完成率", point.completionRate)
                    )
                    .foregroundStyle(
                        point.completionRate >= 1
                            ? PlanetTheme.mint.gradient
                            : PlanetTheme.violet.gradient
                    )
                    .cornerRadius(6)
                    .accessibilityLabel(point.accessibilityLabel)
                    .accessibilityValue(
                        Text(point.completionRate, format: .percent.precision(.fractionLength(0)))
                    )
                }
                .chartYScale(domain: 0...1)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0.0, 0.5, 1.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(PlanetTheme.separator)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(number, format: .percent.precision(.fractionLength(0)))
                            }
                        }
                        .foregroundStyle(PlanetTheme.secondaryText)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: store.statisticsPeriod == .month ? 6 : 8)) {
                        AxisValueLabel()
                            .foregroundStyle(PlanetTheme.secondaryText)
                    }
                }
                .frame(height: 200)
            }
        }
        .qCard(padding: 16)
        .padding(.horizontal, 16)
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
                                showsDayNumber: store.statisticsPeriod != .year
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
        .overlay(alignment: .topTrailing) {
            if !store.statistics.daily.isEmpty {
                statsSticker("StatsCloudPeek", height: 48)
                    .offset(x: 6, y: -16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var periodBinding: Binding<StatisticsPeriod> {
        Binding(
            get: { store.statisticsPeriod },
            set: { period in
                Task { await store.refreshStatistics(period: period, anchor: store.statisticsAnchor) }
            }
        )
    }

    private var chartPoints: [StatisticsChartPoint] {
        if store.statisticsPeriod == .year {
            let grouped = Dictionary(grouping: store.statistics.daily) {
                calendar.dateComponents([.year, .month], from: $0.date)
            }
            return grouped.compactMap { components, days in
                guard let date = calendar.date(from: components) else { return nil }
                return StatisticsChartPoint(
                    id: DayKey(date: date, calendar: calendar).rawValue,
                    label: "\(calendar.component(.month, from: date))月",
                    planned: days.reduce(0) { $0 + $1.plannedTaskCount },
                    completed: days.reduce(0) { $0 + $1.completedTaskCount }
                )
            }
            .sorted { $0.id < $1.id }
        }

        return store.statistics.daily.map { statistic in
            let label: String
            if store.statisticsPeriod == .week {
                label = statistic.date.formatted(.dateTime.weekday(.abbreviated).locale(chineseLocale))
            } else {
                label = "\(calendar.component(.day, from: statistic.date))日"
            }
            return StatisticsChartPoint(
                id: statistic.dayKey,
                label: label,
                planned: statistic.plannedTaskCount,
                completed: statistic.completedTaskCount
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

    var body: some View {
        SettingsView(store: store)
    }
}

struct SettingsView: View {
    @ObservedObject var store: AppStore

    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            PlanetBackground()

            ScrollView {
                VStack(spacing: 16) {
                    profileHero
                    preferencesPanel
                    notificationPanel
                    informationPanel
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.refreshNotifications()
        }
    }

    private var profileHero: some View {
        HStack(spacing: 18) {
            MascotView(mood: .ready, size: 108)
            VStack(alignment: .leading, spacing: 7) {
                Text("小星星")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text(profileSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Label("\(store.habits.filter { !$0.isArchived }.count) 个习惯在培养", systemImage: "heart.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(PlanetTheme.violet)
            }
            Spacer(minLength: 0)
        }
        .planetPanel(padding: 18)
    }

    private var preferencesPanel: some View {
        VStack(spacing: 0) {
            settingsHeader("偏好设置", symbol: "slider.horizontal.3")
            settingsDivider

            Toggle(isOn: soundBinding) {
                settingsLabel("打卡声音", symbol: "speaker.wave.2.fill", color: PlanetTheme.sky)
            }
            .tint(PlanetTheme.mint)
            .frame(minHeight: 52)

            settingsDivider

            Toggle(isOn: hapticsBinding) {
                settingsLabel("触感反馈", symbol: "waveform.path", color: PlanetTheme.coral)
            }
            .tint(PlanetTheme.mint)
            .frame(minHeight: 52)

            settingsDivider

            VStack(alignment: .leading, spacing: 10) {
                settingsLabel("外观", symbol: "circle.lefthalf.filled", color: PlanetTheme.violet)
                Picker("外观", selection: appearanceBinding) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Text(appearance.title).tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.vertical, 12)
        }
        .planetPanel(padding: 14)
    }

    private var notificationPanel: some View {
        VStack(spacing: 0) {
            settingsHeader("打卡提醒", symbol: "bell.badge.fill")
            settingsDivider

            HStack(spacing: 12) {
                settingsLabel("通知权限", symbol: notificationSymbol, color: notificationColor)
                Spacer()
                Text(notificationTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(notificationColor)
            }
            .frame(minHeight: 52)
            .accessibilityElement(children: .combine)

            Text(notificationMessage)
                .font(.caption)
                .foregroundStyle(PlanetTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            if store.notificationStatus == .denied {
                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(url)
                } label: {
                    Label("前往系统设置", systemImage: "arrow.up.right.square")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(PlanetTheme.violet)
            } else {
                Button {
                    Task { await store.refreshNotifications() }
                } label: {
                    Label("刷新通知状态", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(PlanetTheme.violet)
            }
        }
        .planetPanel(padding: 14)
    }

    private var informationPanel: some View {
        VStack(spacing: 0) {
            NavigationLink {
                DataPrivacyView()
            } label: {
                settingsNavigationRow("数据与隐私", symbol: "lock.shield.fill", color: PlanetTheme.mint)
            }
            .buttonStyle(.plain)

            settingsDivider

            NavigationLink {
                AboutCheckInView()
            } label: {
                settingsNavigationRow("关于打卡小星球", symbol: "info.circle.fill", color: PlanetTheme.sky)
            }
            .buttonStyle(.plain)

            settingsDivider

            Button {
                store.showOnboardingAgain()
            } label: {
                settingsNavigationRow("重看新手引导", symbol: "play.rectangle.fill", color: PlanetTheme.gold)
            }
            .buttonStyle(.plain)
        }
        .planetPanel(padding: 14)
    }

    private var soundBinding: Binding<Bool> {
        Binding(
            get: { store.settings.soundEnabled },
            set: store.setSoundEnabled
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { store.settings.hapticsEnabled },
            set: store.setHapticsEnabled
        )
    }

    private var appearanceBinding: Binding<AppAppearance> {
        Binding(
            get: { store.settings.appearance },
            set: store.setAppearance
        )
    }

    private var profileSubtitle: String {
        if store.statistics.currentStreak > 0 {
            return "已经坚持 \(store.statistics.currentStreak) 天，继续点亮今天。"
        }
        return "从一个小习惯开始，积累自己的星光。"
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
        case .denied: "bell.slash.fill"
        case .authorized, .provisional, .ephemeral: "bell.fill"
        case .notDetermined: "bell.badge.fill"
        }
    }

    private var settingsDivider: some View {
        Divider().overlay(PlanetTheme.separator)
    }

    private func settingsHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(PlanetTheme.primaryText)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private func settingsLabel(_ title: String, symbol: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.body)
                .foregroundStyle(PlanetTheme.primaryText)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 24)
        }
    }

    private func settingsNavigationRow(_ title: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            settingsLabel(title, symbol: symbol, color: color)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(PlanetTheme.secondaryText)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 52)
    }
}

private struct StatisticsChartPoint: Identifiable {
    let id: String
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
        .navigationTitle("数据与隐私")
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
    var body: some View {
        ZStack {
            PlanetBackground()
            VStack(spacing: 18) {
                MascotView(mood: .ready, size: 144)
                VStack(spacing: 7) {
                    Text("打卡小星球")
                        .font(.system(.title, design: .rounded, weight: .heavy))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text("养成好习惯，每天进步一点点")
                        .font(.subheadline)
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                Text("版本 \(appVersion)")
                    .font(.caption)
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
            .frame(maxWidth: 420)
            .padding(28)
        }
        .navigationTitle("关于")
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
