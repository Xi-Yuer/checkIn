import SwiftUI

struct HabitEditorView: View {
    @ObservedObject var store: AppStore
    private let editingID: UUID?

    @Environment(\.dismiss) private var dismiss

    @State private var draft: TaskDraft
    @State private var scheduleType: TaskScheduleType
    @State private var selectedWeekdays: Set<Weekday>
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var reminderTime: Date
    @State private var validationMessage: String?
    @State private var isSaving = false

    init(store: AppStore, habit: TaskDTO? = nil) {
        self.store = store
        editingID = habit?.id
        let initialDraft = habit?.draft ?? TaskDraft()
        _draft = State(initialValue: initialDraft)
        _scheduleType = State(initialValue: initialDraft.schedule.type)
        _selectedWeekdays = State(initialValue: initialDraft.schedule.selectedWeekdays)
        _hasStartDate = State(initialValue: initialDraft.startDate != nil)
        _hasEndDate = State(initialValue: initialDraft.endDate != nil)
        let now = Date()
        _startDate = State(initialValue: initialDraft.startDate ?? now)
        _endDate = State(initialValue: initialDraft.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now)
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = initialDraft.reminderHour ?? 9
        components.minute = initialDraft.reminderMinute ?? 0
        _reminderTime = State(initialValue: Calendar.current.date(from: components) ?? now)
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
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .environment(\.calendar, chineseCalendar)
        .presentationDragIndicator(.visible)
    }

    private var chineseCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        return calendar
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

            HStack(spacing: 8) {
                scheduleButton(.daily, title: "每天")
                scheduleButton(.weekdays, title: "工作日")
                scheduleButton(.custom, title: "自定义")
            }

            if scheduleType == .custom {
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
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(selectedWeekdays.contains(weekday) ? PlanetTheme.lavender : PlanetTheme.mutedSurface)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedWeekdays.contains(weekday) ? .isSelected : [])
                    }
                }
            }

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

            Toggle(isOn: $draft.reminderEnabled) {
                Label("打卡提醒", systemImage: "bell.fill")
                    .font(.system(.body, design: .rounded, weight: .medium))
            }
            .tint(PlanetTheme.mint)

            if draft.reminderEnabled {
                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                    .font(.system(.body, design: .rounded))
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
            }
        } label: {
            Text(title)
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
        }
        value.startDate = hasStartDate ? startDate : nil
        value.endDate = hasEndDate ? endDate : nil
        if value.reminderEnabled {
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
}
