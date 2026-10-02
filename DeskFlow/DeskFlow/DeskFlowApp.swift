import SwiftUI
import AppKit

// `@State` is a macro in the macOS 27 SDK and its plugin ships only with Xcode.
// The alias points at the property wrapper, so the Command Line Tools can build the app.
typealias ViewState = SwiftUI.State

@main
struct DeskFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var link = DeskLink()
    @StateObject private var store = ProfileStore()

    var body: some Scene {
        Window("DeskFlow", id: "main") {
            ContentView()
                .environmentObject(link)
                .environmentObject(store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 420, height: 640)
        .commands { ProfileCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private struct NewProfileKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newProfile: (() -> Void)? {
        get { self[NewProfileKey.self] }
        set { self[NewProfileKey.self] = newValue }
    }
}

struct ProfileCommands: Commands {
    @FocusedValue(\.newProfile) private var newProfile

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Profile") { newProfile?() }
                .keyboardShortcut("n")
                .disabled(newProfile == nil)
        }
    }
}
