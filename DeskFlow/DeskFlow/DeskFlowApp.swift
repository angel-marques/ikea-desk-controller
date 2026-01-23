import SwiftUI
import AppKit

@main
struct DeskFlowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
                .onAppear {
                    appDelegate.setupMenuBar(
                        bluetoothManager: bluetoothManager,
                        profileManager: profileManager
                    )
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarManager = MenuBarManager()
    private var windowObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start with dock icon visible
        NSApp.setActivationPolicy(.regular)

        // Observe window visibility changes
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDockVisibility()
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Delay to allow window to fully close
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.updateDockVisibility()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateDockVisibility() {
        let hasVisibleWindows = NSApp.windows.contains { window in
            window.isVisible && window.canBecomeMain && !window.isMiniaturized
        }

        if hasVisibleWindows {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    @MainActor
    func setupMenuBar(bluetoothManager: BluetoothManager, profileManager: ProfileManager) {
        menuBarManager.setup(bluetoothManager: bluetoothManager, profileManager: profileManager)
    }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
