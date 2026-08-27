import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        AppShell(store: store)
        .task {
            await store.load()
        }
    }
}
