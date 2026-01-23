import SwiftUI

@main
struct DeskFlowApp: App {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var statsManager = StatsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                .environmentObject(profileManager)
                .environmentObject(statsManager)
                .frame(minWidth: 390, minHeight: 700)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
