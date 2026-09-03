import SwiftUI

struct HabitEditorView: View {
    @ObservedObject var store: AppStore
    private let editingID: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TaskDraft
    @State private var scheduleType: TaskScheduleType
    @State private var regularScheduleType: TaskScheduleType
    @State private var selectedWeekdays: Set<Weekday>
    @State private var specificDates: [TaskSpecificDate]
    @State private var countdownDays: Int
    @State private var showingSpecificDatePicker = false
    @State private var selectedCalendarDates: Set<DateComponents>
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var reminderTime: Date
    @State private var fixedTime: Date
    @State private var validationMessage: String?
    @State private var isSaving = false

    init(store: AppStore, habit: TaskDTO? = nil) {
        self.store = store
        editingID = habit?.id
        let initialDraft = habit?.draft ?? TaskDraft()
        _draft = State(initialValue: initialDraft)
        _scheduleType = State(initialValue: initialDraft.schedule.type)
        _regularScheduleType = State(initialValue: initialDraft.schedule.type == .specificDates ? .daily : initialDraft.schedule.type)
        _selectedWeekdays = State(initialValue: initialDraft.schedule.selectedWeekdays)
        _specificDates = State(initialValue: initialDraft.schedule.specificDateEntries)
        _countdownDays = State(initialValue: initialDraft.schedule.countdownDays)
        _selectedCalendarDates = State(initialValue: Set(initialDraft.schedule.specificDateEntries.compactMap {
            DayKey(rawValue: $0.dayKey).date().map { Calendar.current.dateComponents([.year, .month, .day], from: $0) }
        }))
        _hasStartDate = State(initialValue: initialDraft.startDate != nil)
        _hasEndDate = State(initialValue: initialDraft.endDate != nil)
        let now = Date()
        _startDate = State(initialValue: initialDraft.startDate ?? now)
        _endDate = State(initialValue: initialDraft.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = initialDraft.reminderHour ?? 9
        components.minute = initialDraft.reminderMinute ?? 0
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? now)
        components.hour = initialDraft.fixedTimeHour ?? 9
        components.minute = initialDraft.fixedTimeMinute ?? 0
        _fixedTime = State(initialValue: Calendar.current.date(from: components) ?? now)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PlanetAtmosphere()

                ScrollView {
                    VStack(spacing: 16) {
                        identitySection
                        appearanceSection
                        scheduleSection

                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .foregroundStyle(PlanetTheme.coral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        Button(action: save) {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(.white) }
                                Text(editingID == nil ? "保存习惯" : "保存修改")
                            }
                        }
                        .buttonStyle(QActionButtonStyle())
                        .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(editingID == nil ? "添加习惯" : "编辑习惯")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .font(.system(.body, design: .rounded))
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(PlanetTheme.violet)
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showingSpecificDatePicker) {
            specificDatePickerSheet
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("习惯名称")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.primaryText)
            TextField("例如：阅读 30 分钟", text: $draft.title)
                .font(.system(.body, design: .rounded, weight: .medium))
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .background(PlanetTheme.mutedSurface)
                .clipShape(RoundedRectangle(cornerRadius: PlanetTheme.Radius.nest, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .softCard(fill: PlanetTheme.surface.opacity(0.97), shadowOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选一个图标")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(PlanetTheme.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(HabitIconCatalog.assetNames, id: \.self) { icon in
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.72)) {
                                draft.iconKey = icon
                            }
                        } label: {
                            HabitArtwork(iconKey: icon)
                                .frame(width: 80, height: 80)
                                .opacity(draft.iconKey == icon ? 1 : 0.42)
                                .scaleEffect(draft.iconKey == icon ? 1.08 : 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择打卡图标")
                        .accessibilityAddTraits(draft.iconKey == icon ? .isSelected : [])
                    }
                }
            }
            .accessibilityHint("向左滑动查看更多图标")
        }
        .padding(18)
        .softCard(fill: PlanetTheme.surface.opacity(0.97), shadowOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("什么时候打卡")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text("只在计划日计算连续天数")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }

            Button {
                synchronizeCalendarSelection()
                showingSpecificDatePicker = true
            } label: {
                HStack(spacing: 12) {
                    Text("重复计划")
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Spacer()
                    Text(scheduleSelectionSummary)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(PlanetTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(PlanetTheme.separator)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Stepper(value: $draft.dailyTarget, in: 1...99) {
                HStack {
                    Text("每日目标")
                        .font(.system(.body, design: .rounded, weight: .medium))
                    Spacer()
                    Text("\(draft.dailyTarget) 次")
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(PlanetTheme.violet)
                }
            }

            if scheduleType != .specificDates {
            Toggle("设置开始日期", isOn: $hasStartDate)
                .font(.system(.body, design: .rounded, weight: .medium))
                .tint(PlanetTheme.lavender)
            if hasStartDate {
                DatePicker("开始", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.system(.body, design: .rounded))
            }
            Toggle("设置结束日期", isOn: $hasEndDate)
                .font(.system(.body, design: .rounded, weight: .medium))
                .tint(PlanetTheme.lavender)
            if hasEndDate {
                DatePicker("结束", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.system(.body, design: .rounded))
            }
            }

            Toggle(isOn: $draft.fixedTimeEnabled) {
                Text("固定时间打卡")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .tint(PlanetTheme.mint)
            .onChange(of: draft.fixedTimeEnabled) { enabled in
                if enabled { draft.autoCheckInEnabled = false }
            }

            if draft.fixedTimeEnabled {
                DatePicker("打卡时间", selection: $fixedTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .font(.system(.body, design: .rounded))

                HStack(spacing: 12) {
                    Text("允许提前/延后")
                        .font(.system(.body, design: .rounded))

                    Spacer()

                    Menu {
                        ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                            Button {
                                draft.fixedTimeToleranceMinutes = minutes
                            } label: {
                                HStack {
                                    Text(L10n.format("%d 分钟", minutes))
                                    if draft.fixedTimeToleranceMinutes == minutes {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(L10n.format("%d 分钟", draft.fixedTimeToleranceMinutes))
                                .monospacedDigit()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.violet)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 38)
                        .background(PlanetTheme.mutedSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(minHeight: 44)

                Toggle("到点提醒", isOn: $draft.reminderEnabled)
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .tint(PlanetTheme.mint)
            } else {
            Toggle(isOn: $draft.reminderEnabled) {
                Text("打卡提醒")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .tint(PlanetTheme.mint)

            if draft.reminderEnabled {
                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .font(.system(.body, design: .rounded))
            }
            }

            Divider()
                .overlay(PlanetTheme.separator.opacity(0.48))

            Toggle(isOn: $draft.autoCheckInEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("自动打卡")
                        .font(.system(.body, design: .rounded, weight: .medium))
                    Text("开启后次日生效，计划日将自动完成打卡。")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
            }
            .tint(PlanetTheme.mint)
            .onChange(of: draft.autoCheckInEnabled) { enabled in
                if enabled { draft.fixedTimeEnabled = false }
            }
        }
        .padding(18)
        .softCard(fill: PlanetTheme.surface.opacity(0.97), shadowOpacity: 0.08)
        .overlay {
            RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
        }
    }

    private func scheduleButton(_ type: TaskScheduleType, title: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                scheduleType = type
                regularScheduleType = type
            }
        } label: {
            Text(L10n.text(title))
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(scheduleType == type ? Color.white : PlanetTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(scheduleType == type ? PlanetTheme.violet : PlanetTheme.mutedSurface)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(scheduleType == type ? .isSelected : [])
    }

    private func save() {
        guard !isSaving else { return }
        validationMessage = nil
        var value = draft
        switch scheduleType {
        case .daily: value.schedule = .daily
        case .weekdays: value.schedule = .weekdays
        case .custom: value.schedule = .custom(selectedWeekdays)
        case .specificDates: value.schedule = .specificDates(specificDates, countdownDays: countdownDays)
        }
        value.startDate = scheduleType == .specificDates ? nil : (hasStartDate ? startDate : nil)
        value.endDate = scheduleType == .specificDates ? nil : (hasEndDate ? endDate : nil)
        if value.fixedTimeEnabled {
            let components = Calendar.current.dateComponents([.hour, .minute], from: fixedTime)
            value.fixedTimeHour = components.hour
            value.fixedTimeMinute = components.minute
            value.autoCheckInEnabled = false
            if value.reminderEnabled {
                value.reminderHour = components.hour
                value.reminderMinute = components.minute
            } else {
                value.reminderHour = nil
                value.reminderMinute = nil
            }
        } else if value.reminderEnabled {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            value.reminderHour = components.hour
            value.reminderMinute = components.minute
        } else {
            value.reminderHour = nil
            value.reminderMinute = nil
        }

        do {
            value = try value.validated()
        } catch {
            validationMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return
        }

        isSaving = true
        Task {
            let savedID = await store.saveHabit(value, id: editingID)
            isSaving = false
            if savedID != nil { dismiss() }
        }
    }

    private func specificDateBinding(at index: Int) -> Binding<Date> {
        Binding(
            get: { DayKey(rawValue: specificDates[index].dayKey).date() ?? Date() },
            set: { specificDates[index].dayKey = DayKey(date: $0).rawValue }
        )
    }

    private func recurrenceBinding(at index: Int) -> Binding<SpecificDateRecurrence> {
        Binding(
            get: { specificDates[index].recurrence },
            set: { specificDates[index].recurrence = $0 }
        )
    }

    private var specificDatePickerSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(spacing: 12) {
                        frequencyOption(.daily, title: "每天", subtitle: "每天都安排一次打卡", symbol: "sun.max.fill")
                        frequencyOption(.weekdays, title: "工作日", subtitle: "周一至周五打卡", symbol: "briefcase.fill")
                        frequencyOption(.custom, title: "按星期", subtitle: "选择每周固定的日期", symbol: "calendar")
                        frequencyOption(.specificDates, title: "指定日期", subtitle: "单次日期或每年纪念日", symbol: "calendar.badge.plus")
                    }

                    if scheduleType == .custom {
                        weekdayPicker
                            .padding(18)
                            .background(PlanetTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }

                    if scheduleType == .specificDates {
                        VStack(spacing: 18) {
                            MultiDatePicker("选择日期", selection: $selectedCalendarDates)
                                .tint(PlanetTheme.violet)
                                .padding(16)
                                .background(PlanetTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .onChange(of: selectedCalendarDates) { _ in synchronizeSpecificDates() }

                            Stepper(value: $countdownDays, in: 1...30) {
                                HStack {
                                    Text("提前展示")
                                    Spacer()
                                    Text(L10n.format("提前 %d 天", countdownDays))
                                        .foregroundStyle(PlanetTheme.violet)
                                }
                                .font(.system(.body, design: .rounded, weight: .medium))
                            }
                            .padding(.horizontal, 18)
                            .frame(minHeight: 60)
                            .background(PlanetTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }

                        if !specificDates.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(specificDates.indices), id: \.self) { index in
                                HStack(spacing: 12) {
                                    Text(specificDateBinding(at: index).wrappedValue.formatted(.dateTime.year().month().day()))
                                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                        .foregroundStyle(PlanetTheme.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Picker("重复", selection: recurrenceBinding(at: index)) {
                                        ForEach(SpecificDateRecurrence.allCases) { recurrence in
                                            Text(recurrence.title).tag(recurrence)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(PlanetTheme.violet)
                                }
                                .padding(.horizontal, 16)
                                .frame(minHeight: 56)
                                .background(PlanetTheme.mutedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                        }
                    }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
            .background(PlanetTheme.background)
            .navigationTitle("打卡频率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { showingSpecificDatePicker = false }
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func frequencyOption(
        _ type: TaskScheduleType,
        title: String,
        subtitle: String,
        symbol: String
    ) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                scheduleType = type
                if type != .specificDates { regularScheduleType = type }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(scheduleType == type ? Color.white : PlanetTheme.violet)
                    .frame(width: 38, height: 38)
                    .background(scheduleType == type ? PlanetTheme.violet : PlanetTheme.softViolet)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.text(title))
                        .font(.system(.body, design: .rounded, weight: .bold))
                        .foregroundStyle(PlanetTheme.primaryText)
                    Text(L10n.text(subtitle))
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(PlanetTheme.secondaryText)
                }
                Spacer()
                Image(systemName: scheduleType == type ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(scheduleType == type ? PlanetTheme.violet : PlanetTheme.separator)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 70)
            .background(scheduleType == type ? PlanetTheme.softViolet.opacity(0.7) : PlanetTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        scheduleType == type ? PlanetTheme.lavender.opacity(0.5) : PlanetTheme.separator.opacity(0.28),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { weekday in
                Button {
                    if selectedWeekdays.contains(weekday) {
                        selectedWeekdays.remove(weekday)
                    } else {
                        selectedWeekdays.insert(weekday)
                    }
                } label: {
                    Text(weekday.shortTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(selectedWeekdays.contains(weekday) ? Color.white : PlanetTheme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .background(selectedWeekdays.contains(weekday) ? PlanetTheme.lavender : PlanetTheme.mutedSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var scheduleSelectionSummary: String {
        switch scheduleType {
        case .daily: return L10n.text("每天")
        case .weekdays: return L10n.text("工作日")
        case .custom: return L10n.text("按星期")
        case .specificDates:
            return specificDates.isEmpty ? L10n.text("尚未选择日期") : L10n.format("已选择 %d 个日期", specificDates.count)
        }
    }

    private func synchronizeCalendarSelection() {
        selectedCalendarDates = Set(specificDates.compactMap {
            DayKey(rawValue: $0.dayKey).date().map {
                Calendar.current.dateComponents([.year, .month, .day], from: $0)
            }
        })
    }

    private func synchronizeSpecificDates() {
        let calendar = Calendar.current
        let selected = selectedCalendarDates.compactMap { calendar.date(from: $0) }.sorted()
        if selected.count > 20 {
            selectedCalendarDates = Set(selected.prefix(20).map {
                calendar.dateComponents([.year, .month, .day], from: $0)
            })
            return
        }
        let existing = Dictionary(uniqueKeysWithValues: specificDates.map { ($0.dayKey, $0) })
        specificDates = selected.map { date in
            let key = DayKey(date: date, calendar: calendar).rawValue
            return existing[key] ?? TaskSpecificDate(date: date, calendar: calendar)
        }
    }
}
