import Foundation

struct WidgetPreferences: @unchecked Sendable {
    private let defaults: UserDefaults?

    init(appGroupIdentifier: String = CheckInSharedConstants.appGroupIdentifier) {
        defaults = UserDefaults(suiteName: appGroupIdentifier)
    }

    var carouselIndex: Int {
        defaults?.integer(forKey: CheckInSharedConstants.carouselIndexKey) ?? 0
    }

    func advance(taskCount: Int) {
        guard taskCount > 0 else {
            defaults?.set(0, forKey: CheckInSharedConstants.carouselIndexKey)
            return
        }
        defaults?.set((carouselIndex + 1) % taskCount, forKey: CheckInSharedConstants.carouselIndexKey)
    }
}
