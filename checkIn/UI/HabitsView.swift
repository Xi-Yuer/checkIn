import SwiftUI

struct HabitsView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    @State private var pendingDeletion: TaskDTO?
    @State private var deletionHistoryCount = 0
    @State private var showingDeleteConfirmation = false

    private let filters: [TaskFilter] = [.active, .ended, .paused, .all]

    var body: some View {
        ZStack {
            PlanetBackground()
            VStack(spacing: 12) {
                filterBar

                if store.filteredHabits.isEmpty {
                    emptyState
                    Spacer(minLength: 0)
                } else {
                    habitList
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("我的习惯")
        .searchable(text: $store.searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "搜索习惯或备注")
        .toolbar { toolbarContent }
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

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters) { filter in
                    Button {
                        store.setHabitFilter(filter)
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(store.habitFilter == filter ? Color.white : PlanetTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 38)
                            .background(store.habitFilter == filter ? PlanetTheme.violet : PlanetTheme.surface)
                            .clipShape(Capsule())
                            .overlay {
                                if store.habitFilter != filter {
                                    Capsule().stroke(PlanetTheme.separator, lineWidth: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 1)
        }
        .accessibilityLabel("习惯状态筛选")
    }

    private var habitList: some View {
        List {
            ForEach(store.filteredHabits) { habit in
                HabitListRow(
                    habit: habit,
                    progress: store.todayProgress[habit.id],
                    showsAction: false,
                    onCheckIn: {}
                )
                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
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
        .padding(.top, 36)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Picker("排序方式", selection: sortBinding) {
                    ForEach(TaskSort.allCases) { sort in
                        Label(sort.title, systemImage: sortSymbol(sort)).tag(sort)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("排序方式")

            if store.habitSort == .manual && store.searchText.isEmpty {
                EditButton()
            }

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.body.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("添加习惯")
        }
    }

    private var sortBinding: Binding<TaskSort> {
        Binding(
            get: { store.habitSort },
            set: { newValue in Task { await store.setHabitSort(newValue) } }
        )
    }

    private var emptyTitle: String {
        switch store.habitFilter {
        case .paused: "没有暂停的习惯"
        case .ended: "还没有结束的习惯"
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
