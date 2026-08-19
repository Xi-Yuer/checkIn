import SwiftUI

@main
struct checkInApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store: AppStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-reset-onboarding") {
            UserDefaults.standard.removeObject(forKey: "app.settings.v1")
        }
        _store = StateObject(wrappedValue: AppStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(preferredColorScheme)
                .tint(PlanetTheme.violet)
                .onOpenURL { url in
                    Task { await store.handle(url: url) }
                }
                .onChange(of: scenePhase) { phase in
                    guard phase == .active else { return }
                    Task {
                        await store.refreshNotifications()
                        await store.load()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
                    Task {
                        await store.refreshNotifications()
                        await store.load()
                    }
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.settings.appearance {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
