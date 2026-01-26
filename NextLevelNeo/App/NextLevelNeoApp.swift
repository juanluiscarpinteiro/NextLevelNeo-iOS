import SwiftUI

@main
struct NextLevelNeoApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var bleManager = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(bleManager)
                .preferredColorScheme(.dark)
        }
    }
}
