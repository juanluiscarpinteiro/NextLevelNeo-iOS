import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            DeviceListView()
        }
        .tint(.orange)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
        .environmentObject(BLEManager())
}
