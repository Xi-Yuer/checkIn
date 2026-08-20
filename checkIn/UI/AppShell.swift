import AudioToolbox
import SwiftUI
import UIKit

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case habits
    case add
    case statistics
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "首页"
        case .habits: "习惯"
        case .add: "新增"
        case .statistics: "统计"
        case .profile: "我的"
        }
    }

    var symbolName: String {
        switch self {
        case .today: "house.fill"
        case .habits: "heart.text.square.fill"
        case .add: "plus.circle.fill"
        case .statistics: "chart.bar.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

struct AppShell: View {
    @ObservedObject var store: AppStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selection: AppSection = .today
    @State private var showingEditor = false
    @State private var linkedHabit: TaskDTO?

    var body: some View {
        ZStack {
            if horizontalSizeClass == .regular {
                tabletLayout
            } else {
                phoneLayout
            }

            if let habit = store.celebrationHabit {
                CelebrationOverlay(
                    habit: habit,
                    reduceMotion: reduceMotion,
                    undo: {
                        Task { await store.undoLastCheckIn(habitID: habit.id) }
                    },
                    dismiss: store.dismissCelebration
                )
                .zIndex(20)
            }
        }
        .sheet(isPresented: $showingEditor) {
            HabitEditorView(store: store)
        }
        .sheet(item: $linkedHabit) { habit in
            NavigationStack {
                HabitDetailView(store: store, habitID: habit.id)
            }
        }
        .alert(item: errorBinding) { error in
            Alert(title: Text("暂时没能完成"), message: Text(error.message), dismissButton: .default(Text("知道了")))
        }
        .onChange(of: store.route) { route in
            handle(route)
        }
        .onChange(of: store.celebrationHabit) { habit in
            guard habit != nil else { return }
            deliverCompletionFeedback()
        }
        .onAppear {
            handle(store.route)
        }
    }

    private var phoneLayout: some View {
        TabView(selection: $selection) {
            navigationRoot {
                TodayView(
                    store: store,
                    onAdd: { showingEditor = true },
                    onShowHabits: { selection = .habits }
                )
            }
            .tag(AppSection.today)
            .tabItem { Label(AppSection.today.title, systemImage: AppSection.today.symbolName) }

            navigationRoot {
                HabitsView(store: store, onAdd: { showingEditor = true })
            }
            .tag(AppSection.habits)
            .tabItem { Label(AppSection.habits.title, systemImage: AppSection.habits.symbolName) }

            navigationRoot {
                StatisticsView(store: store)
            }
            .tag(AppSection.statistics)
            .tabItem { Label(AppSection.statistics.title, systemImage: AppSection.statistics.symbolName) }

            navigationRoot {
                ProfileView(store: store)
            }
            .tag(AppSection.profile)
            .tabItem { Label(AppSection.profile.title, systemImage: AppSection.profile.symbolName) }
        }
        .tint(PlanetTheme.violet)
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            PlanetTabBar(
                selection: $selection,
                onAdd: { showingEditor = true }
            )
        }
    }

    private var tabletLayout: some View {
        NavigationSplitView {
            List {
                Section {
                    ForEach([AppSection.today, .habits, .statistics, .profile]) { section in
                        Button {
                            selection = section
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: section.symbolName)
                                    .foregroundStyle(selection == section ? PlanetTheme.violet : PlanetTheme.secondaryText)
                                    .frame(width: 24)
                                Text(section.title)
                                    .foregroundStyle(PlanetTheme.primaryText)
                                Spacer()
                                if selection == section {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(PlanetTheme.violet)
                                }
                            }
                            .font(.body.weight(.semibold))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(selection == section ? PlanetTheme.elevatedSurface : Color.clear)
                    }
                }

                Section {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("添加习惯", systemImage: "plus.circle.fill")
                            .font(.body.weight(.bold))
                            .foregroundStyle(PlanetTheme.violet)
                    }
                    .buttonStyle(.plain)
                }
            }
            .scrollContentBackground(.hidden)
            .background(PlanetTheme.background)
            .navigationTitle("打卡小星球")
        } detail: {
            navigationRoot {
                destination(for: selection)
            }
        }
        .tint(PlanetTheme.violet)
    }

    private func navigationRoot<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .navigationDestination(for: UUID.self) { id in
                    HabitDetailView(store: store, habitID: id)
                }
        }
    }

    @ViewBuilder
    private func destination(for section: AppSection) -> some View {
        switch section {
        case .today:
            TodayView(
                store: store,
                onAdd: { showingEditor = true },
                onShowHabits: { selection = .habits }
            )
        case .habits:
            HabitsView(store: store, onAdd: { showingEditor = true })
        case .statistics:
            StatisticsView(store: store)
        case .profile:
            ProfileView(store: store)
        case .add:
            TodayView(store: store, onAdd: { showingEditor = true })
        }
    }

    private var errorBinding: Binding<AppStoreError?> {
        Binding(get: { store.error }, set: { _ in store.clearError() })
    }

    private func handle(_ route: DeepLinkDestination?) {
        guard let route else { return }
        switch route {
        case .today:
            selection = .today
        case let .task(id):
            selection = .today
            linkedHabit = store.habit(id: id)
        }
    }

    private func deliverCompletionFeedback() {
        if store.settings.hapticsEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
        if store.settings.soundEnabled {
            AudioServicesPlaySystemSound(1108)
        }
    }
}

private struct PlanetTabBar: View {
    @Binding var selection: AppSection
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.today)
            tabButton(.habits)
            addButton
            tabButton(.statistics)
            tabButton(.profile)
        }
        .padding(.horizontal, 8)
        .frame(height: 66)
        .background(PlanetTheme.surface.opacity(0.98))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PlanetTheme.separator.opacity(0.45))
                .frame(height: 1)
        }
        .shadow(color: PlanetTheme.violet.opacity(0.08), radius: 12, y: -4)
        .background(PlanetTheme.surface.ignoresSafeArea(edges: .bottom))
    }

    private func tabButton(_ section: AppSection) -> some View {
        let isSelected = selection == section
        return Button {
            withAnimation(.easeOut(duration: 0.18)) {
                selection = section
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tabSymbol(for: section, selected: isSelected))
                    .font(.system(size: 21, weight: .semibold))
                    .frame(width: 28, height: 28)
                Text(section.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? PlanetTheme.violet : PlanetTheme.secondaryText.opacity(0.74))
            .frame(maxWidth: .infinity, minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Image(systemName: "plus")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 56, height: 56)
                .background(PlanetTheme.lavender)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.88), lineWidth: 3)
                }
                .shadow(color: PlanetTheme.violet.opacity(0.24), radius: 8, y: 4)
                .frame(maxWidth: .infinity, minHeight: 60)
                .offset(y: -7)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("添加习惯")
    }

    private func tabSymbol(for section: AppSection, selected: Bool) -> String {
        switch section {
        case .today: selected ? "house.fill" : "house"
        case .habits: selected ? "heart.fill" : "heart"
        case .statistics: selected ? "chart.bar.fill" : "chart.bar"
        case .profile: selected ? "person.fill" : "person"
        case .add: "plus"
        }
    }
}
