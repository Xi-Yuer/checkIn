import SwiftUI

struct HabitsView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    @State private var pendingDeletion: TaskDTO?
    @State private var deletionHistoryCount = 0
    @State private var showingDeleteConfirmation = false
    @State private var showsSearch = false
    @State private var editMode: EditMode = .inactive

    private let filters: [TaskFilter] = [.all, .active, .ended, .paused]

    var body: some View {
        ZStack {
            PlanetBackground()

            VStack(spacing: 0) {
                pageHeader

                if showsSearch {
                    searchField
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                filterBar

                if store.filteredHabits.isEmpty {
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    habitList
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.editMode, $editMode)
        .confirmationDialog(
            pendingDeletion.map { "删除“\($0.title)”？" } ?? "删除习惯？",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除习惯和 \(deletionHistoryCount) 条记录", role: .destructive) {
                guard let habit = pendingDeletion else { return }
                Task { _ = await store.deleteHabit(id: habit.id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复；暂停则会保留全部历史。")
        }
    }

    private var pageHeader: some View {
        HStack(spacing: 12) {
            Text("我的习惯")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(PlanetTheme.primaryText)

            Spacer(minLength: 12)

            Menu {
                Button {
                    withAnimation(.easeOut(duration: 0.20)) {
                        showsSearch.toggle()
                        if !showsSearch {
                            store.searchText = ""
                        }
                    }
                } label: {
                    Label(showsSearch ? "收起搜索" : "搜索习惯", systemImage: "magnifyingglass")
                }

                Picker("排序方式", selection: sortBinding) {
                    ForEach(TaskSort.allCases) { sort in
                        Label(sort.title, systemImage: sortSymbol(sort)).tag(sort)
                    }
                }

                if store.habitSort == .manual && store.searchText.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    } label: {
                        Label(editMode == .active ? "完成排序" : "手动排序", systemImage: "line.3.horizontal")
                    }
                }

                Divider()

                Button(action: onAdd) {
                    Label("添加习惯", systemImage: "plus")
                }
            } label: {
                Image(systemName: "square.grid.3x3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PlanetTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("习惯列表选项")
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PlanetTheme.secondaryText)

            TextField("搜索习惯或备注", text: $store.searchText)
                .font(.system(.body, design: .rounded))
                .submitLabel(.search)

            if !store.searchText.isEmpty {
                Button {
                    store.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PlanetTheme.secondaryText.opacity(0.72))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(minHeight: 46)
        .background(PlanetTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.62), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var filterBar: some View {
        HStack(spacing: 0) {
            ForEach(filters) { filter in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        editMode = .inactive
                        store.setHabitFilter(filter)
                    }
                } label: {
                    VStack(spacing: 0) {
                        Text(filterTitle(filter))
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(store.habitFilter == filter ? PlanetTheme.violet : PlanetTheme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 48)

                        Capsule()
                            .fill(store.habitFilter == filter ? PlanetTheme.lavender : Color.clear)
                            .frame(width: 26, height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(store.habitFilter == filter ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 1)
        .background(PlanetTheme.surface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(PlanetTheme.separator.opacity(0.3), lineWidth: 1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityLabel("习惯状态筛选")
    }

    private var habitList: some View {
        List {
            ForEach(store.filteredHabits) { habit in
                HabitSummaryRow(
                    habit: habit,
                    streak: store.habitStreaks[habit.id] ?? 0
                )
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if habit.isArchived {
                        Button {
                            Task { await store.resumeHabit(id: habit.id) }
                        } label: {
                            Label("恢复", systemImage: "play.fill")
                        }
                        .tint(PlanetTheme.mint)
                    } else {
                        Button {
                            Task { await store.pauseHabit(id: habit.id) }
                        } label: {
                            Label("暂停", systemImage: "pause.fill")
                        }
                        .tint(PlanetTheme.gold)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        prepareDeletion(habit)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                }
                .contextMenu {
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
                    Button(role: .destructive) { prepareDeletion(habit) } label: {
                        Label("删除习惯", systemImage: "trash")
                    }
                }
            }
            .onMove(perform: moveHabits)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await store.load() }
    }

    private var emptyState: some View {
        EmptyStateView(
            mood: store.searchText.isEmpty ? .reading : .ready,
            title: store.searchText.isEmpty ? emptyTitle : "没有找到相关习惯",
            message: store.searchText.isEmpty ? emptyMessage : "试试缩短关键词，或切换上方状态。",
            actionTitle: store.searchText.isEmpty && store.habitFilter != .paused ? "添加习惯" : nil,
            action: store.searchText.isEmpty && store.habitFilter != .paused ? onAdd : nil
        )
        .frame(maxWidth: .infinity)
        .padding(.top, 30)
    }

    private var sortBinding: Binding<TaskSort> {
        Binding(
            get: { store.habitSort },
            set: { newValue in
                editMode = .inactive
                Task { await store.setHabitSort(newValue) }
            }
        )
    }

    private var emptyTitle: String {
        switch store.habitFilter {
        case .paused: "没有暂停的习惯"
        case .ended: "还没有完成的习惯"
        default: "给生活放一颗小星星"
        }
    }

    private var emptyMessage: String {
        switch store.habitFilter {
        case .paused: "暂停的习惯会保留历史，并可以随时恢复。"
        case .ended: "设置结束日期的习惯会在到期后出现在这里。"
        default: "建立一个每天都愿意完成的小目标。"
        }
    }

    private func filterTitle(_ filter: TaskFilter) -> String {
        switch filter {
        case .ended: "已完成"
        default: filter.title
        }
    }

    private func prepareDeletion(_ habit: TaskDTO) {
        pendingDeletion = habit
        Task {
            deletionHistoryCount = await store.historyCount(for: habit.id)
            showingDeleteConfirmation = true
        }
    }

    private func moveHabits(from source: IndexSet, to destination: Int) {
        guard store.habitSort == .manual else { return }
        var reordered = store.filteredHabits
        reordered.move(fromOffsets: source, toOffset: destination)
        let visibleIDs = Set(reordered.map(\.id))
        let orderedIDs = reordered.map(\.id) + store.habits.map(\.id).filter { !visibleIDs.contains($0) }
        Task { await store.updateManualOrder(orderedIDs) }
    }

    private func sortSymbol(_ sort: TaskSort) -> String {
        switch sort {
        case .manual: "line.3.horizontal"
        case .priority: "exclamationmark.triangle.fill"
        case .createdAt: "clock.fill"
        case .streak: "flame.fill"
        }
    }
}
