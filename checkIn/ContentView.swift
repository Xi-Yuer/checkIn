import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            AppShell(store: store)
                .transition(.opacity)

            if !hasLoaded {
                launchSplash
                    .transition(.opacity)
                    .zIndex(50)
            }
        }
        .task {
            guard !hasLoaded else { return }
            await store.load()
            withAnimation(.easeOut(duration: 0.28)) {
                hasLoaded = true
            }
        }
    }

    private var launchSplash: some View {
        Image("Launch")
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
            .accessibilityLabel("正在载入")
    }
}
