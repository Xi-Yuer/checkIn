import SwiftUI

struct HabitsView: View {
    @ObservedObject var store: AppStore
    let onAdd: () -> Void

    @State private var pendingDeletion: TaskDTO?
    @State private var deletionHistoryCount = 0
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack {
            PlanetAtmosphere()

            ScrollView {
                VStack(spacing: 18) {
                    pageHeader
                    habitContent
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
            .refreshable { await store.load() }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog(
            pendingDeletion.map { L10n.format("删除“%@”？", $0.title) } ?? L10n.text("删除习惯？"),
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("我的习惯")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(PlanetTheme.primaryText)
                Text("\(store.habits.count) 个习惯")
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(PlanetTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PlanetTheme.violet)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加习惯")
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var habitContent: some View {
        if store.habits.isEmpty {
            EmptyStateView(
                mood: .reading,
                title: "给生活放一颗小星星",
                message: "建立一个每天都愿意完成的小目标。",
                actionTitle: "添加习惯",
                action: onAdd
            )
            .frame(maxWidth: .infinity)
            .softCard(fill: PlanetTheme.surface.opacity(0.96), shadowOpacity: 0.08)
            .padding(.horizontal, 16)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.habits) { habit in
                    HabitSummaryRow(
                        habit: habit,
                        streak: store.habitStreaks[habit.id] ?? 0
                    )
                    .softCard(fill: PlanetTheme.surface.opacity(0.97), shadowOpacity: 0.08)
                    .overlay {
                        RoundedRectangle(cornerRadius: PlanetTheme.Radius.card, style: .continuous)
                            .stroke(PlanetTheme.separator.opacity(0.4), lineWidth: 1)
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
                            Label(
                                habit.isArchived ? L10n.text("恢复习惯") : L10n.text("暂停习惯"),
                                systemImage: habit.isArchived ? "play.fill" : "pause.fill"
                            )
                        }
                        Button(role: .destructive) { prepareDeletion(habit) } label: {
                            Label("删除习惯", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func prepareDeletion(_ habit: TaskDTO) {
        pendingDeletion = habit
        Task {
            deletionHistoryCount = await store.historyCount(for: habit.id)
            showingDeleteConfirmation = true
        }
    }
}
