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
                PlanetBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        identitySection
                        appearanceSection
                        scheduleSection
                        reminderSection

                        if let validationMessage {
                            Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(PlanetTheme.coral)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: save) {
                            HStack(spacing: 8) {
                                if isSaving { ProgressView().tint(.white) }
                                Text(editingID == nil ? "点亮这个习惯" : "保存修改")
                            }
                        }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(editingID == nil ? "添加习惯" : "编辑习惯")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .fontWeight(.bold)
                        .disabled(isSaving || draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .tint(PlanetTheme.violet)
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "习惯信息", subtitle: "名字简短一点，更容易每天看见")
            TextField("例如：阅读 30 分钟", text: $draft.title)
                .textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(PlanetTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(PlanetTheme.separator, lineWidth: 1)
                }
        }
        .planetPanel()
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "打卡图标")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(HabitIconCatalog.assetNames, id: \.self) { icon in
                        Button {
                            draft.iconKey = icon
                        } label: {
                            HabitArtwork(iconKey: icon)
                                .frame(width: 80, height: 80)
                                .opacity(draft.iconKey == icon ? 1 : 0.42)
                                .scaleEffect(draft.iconKey == icon ? 1.06 : 1)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择打卡图标")
                        .accessibilityAddTraits(draft.iconKey == icon ? .isSelected : [])
                    }
                }
            }
            .accessibilityHint("向左滑动查看更多图标")
        }
        .planetPanel()
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "打卡计划", subtitle: "只在计划日计算连续天数")

            HStack(spacing: 8) {
                scheduleButton(.daily, title: "每天")
                scheduleButton(.weekdays, title: "工作日")
                scheduleButton(.custom, title: "自定义")
            }

            if scheduleType == .custom {
                HStack(spacing: 4) {
                    ForEach(Weekday.allCases) { weekday in
                        Button {
                            if selectedWeekdays.contains(weekday) {
                                selectedWeekdays.remove(weekday)
                            } else {
                                selectedWeekdays.insert(weekday)
                            }
                        } label: {
                            Text(weekday.shortTitle)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(selectedWeekdays.contains(weekday) ? Color.white : PlanetTheme.secondaryText)
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(selectedWeekdays.contains(weekday) ? PlanetTheme.violet : PlanetTheme.elevatedSurface)
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
                    Spacer()
                    Text("\(draft.dailyTarget) 次")
                        .font(.body.weight(.bold))
                        .foregroundStyle(PlanetTheme.violet)
                }
            }

            Toggle("设置开始日期", isOn: $hasStartDate)
            if hasStartDate {
                DatePicker("开始", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            Toggle("设置结束日期", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("结束", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
        .planetPanel()
    }

    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(title: "提醒")
            Toggle(isOn: $draft.reminderEnabled) {
                Label("打卡提醒", systemImage: "bell.fill")
            }
            .tint(PlanetTheme.mint)
            if draft.reminderEnabled {
                DatePicker("提醒时间", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                Text("首次保存时会请求系统通知权限。")
                    .font(.caption)
                    .foregroundStyle(PlanetTheme.secondaryText)
            }
        }
        .planetPanel()
    }

    private func scheduleButton(_ type: TaskScheduleType, title: String) -> some View {
        Button {
            scheduleType = type
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scheduleType == type ? Color.white : PlanetTheme.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(scheduleType == type ? PlanetTheme.violet : PlanetTheme.elevatedSurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
