import Intents

final class IntentHandler: INExtension, FocusedHabitConfigurationIntentHandling {
    private let snapshotStore = AppGroupWidgetSnapshotStore()

    func provideHabitOptionsCollection(
        for intent: FocusedHabitConfigurationIntent
    ) async throws -> INObjectCollection<HabitChoice> {
        INObjectCollection(items: availableChoices())
    }

    func defaultHabit(for intent: FocusedHabitConfigurationIntent) -> HabitChoice? {
        let choices = availableChoices()
        return choices.count == 1 ? choices[0] : nil
    }

    private func availableChoices() -> [HabitChoice] {
        guard case .available(let snapshot) = snapshotStore.load(now: Date()) else { return [] }
        return snapshot.tasks
            .filter { !$0.isPaused }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .map { HabitChoice(identifier: $0.id.uuidString, display: $0.title) }
    }
}
