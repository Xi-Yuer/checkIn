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
        case .today: L10n.text("首页")
        case .habits: L10n.text("习惯")
        case .add: L10n.text("新增")
        case .statistics: L10n.text("统计")
        case .profile: L10n.text("我的")
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
                    onAdd: { showingEditor = true }
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
                onAdd: { showingEditor = true }
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
