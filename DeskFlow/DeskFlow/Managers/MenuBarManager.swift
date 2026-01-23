import SwiftUI
import AppKit

extension Notification.Name {
    static let openMainWindow = Notification.Name("openMainWindow")
}

@MainActor
class MenuBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    @Published var isPopoverShown = false

    weak var bluetoothManager: BluetoothManager?
    weak var profileManager: ProfileManager?

    func setup(bluetoothManager: BluetoothManager, profileManager: ProfileManager) {
        self.bluetoothManager = bluetoothManager
        self.profileManager = profileManager

        setupStatusItem()
        setupPopover()
        setupEventMonitor()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .openMainWindow,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openMainWindow()
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // SF Symbol works well as template for menu bar
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            button.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle.fill", accessibilityDescription: "DeskFlow")?
                .withSymbolConfiguration(config)
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 320)
        popover?.behavior = .transient
        popover?.animates = true
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover?.isShown == true {
                self?.closePopover()
            }
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent

        if event?.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            if popover?.isShown == true {
                closePopover()
            } else {
                showPopover(sender)
            }
        }
    }

    private func showPopover(_ sender: NSStatusBarButton) {
        guard let popover = popover,
              let bluetoothManager = bluetoothManager,
              let profileManager = profileManager else { return }

        let contentView = MenuBarPopoverView()
            .environmentObject(bluetoothManager)
            .environmentObject(profileManager)

        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        isPopoverShown = true
    }

    private func closePopover() {
        popover?.performClose(nil)
        isPopoverShown = false
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open DeskFlow", action: #selector(openMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        if let profiles = profileManager?.profiles.prefix(4) {
            for profile in profiles {
                let item = NSMenuItem(title: "\(profile.name) (\(String(format: "%.0f", profile.height)) cm)", action: #selector(activateProfile(_:)), keyEquivalent: "")
                item.representedObject = profile
                item.target = self
                menu.addItem(item)
            }
            menu.addItem(NSMenuItem.separator())
        }

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func openMainWindow() {
        closePopover()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.setActivationPolicy(.regular)

            if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
                if window.isMiniaturized {
                    window.deminiaturize(nil)
                }
                window.makeKeyAndOrderFront(nil)
            }

            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func activateProfile(_ sender: NSMenuItem) {
        guard let profile = sender.representedObject as? Profile,
              let bluetoothManager = bluetoothManager else { return }

        if bluetoothManager.connectionState.isConnected {
            bluetoothManager.moveTo(height: profile.height)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    deinit {
        if let eventMonitor = eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }
}

// MARK: - Menu Bar Popover View
struct MenuBarPopoverView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: ProfileManager

    private var activeProfileId: UUID? {
        profileManager.profileForHeight(bluetoothManager.currentHeight)?.id
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header with height
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(bluetoothManager.connectionState.isConnected ? Color.success : Color.textMuted)
                        .frame(width: 8, height: 8)
                    Text(bluetoothManager.connectionState.isConnected ? "Connected" : "Disconnected")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                }

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", bluetoothManager.currentHeight))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.textPrimary)
                    Text("cm")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textMuted)
                }
            }

            // Quick controls
            if bluetoothManager.connectionState.isConnected {
                HStack(spacing: 12) {
                    Button {
                        bluetoothManager.moveDown()
                    } label: {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(MenuBarButtonStyle())

                    if bluetoothManager.isMoving {
                        Button {
                            bluetoothManager.stopMovement()
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .buttonStyle(MenuBarButtonStyle(isDestructive: true))
                    }

                    Button {
                        bluetoothManager.moveUp()
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(MenuBarButtonStyle(isPrimary: true))
                }
            }

            Divider()

            // Profiles
            VStack(spacing: 8) {
                ForEach(profileManager.profiles.prefix(4)) { profile in
                    MenuBarProfileRow(
                        profile: profile,
                        isActive: profile.id == activeProfileId
                    ) {
                        if bluetoothManager.connectionState.isConnected {
                            bluetoothManager.moveTo(height: profile.height)
                        }
                    }
                }
            }

            Divider()

            // Open main window
            Button {
                // Post notification to open window (handled by MenuBarManager)
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text("Open DeskFlow")
                }
                .font(AppFont.body)
                .foregroundColor(.accentOrange)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.appBackground)
    }
}

struct MenuBarProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: profile.icon)
                    .font(.system(size: 14))
                    .foregroundColor(isActive ? .black : .white)
                    .frame(width: 28, height: 28)
                    .background(isActive ? Color.accentOrange : Color.borderMedium)
                    .cornerRadius(6)

                Text(profile.name)
                    .font(AppFont.body)
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(String(format: "%.0f cm", profile.height))
                    .font(AppFont.caption)
                    .foregroundColor(.textMuted)

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.accentOrange)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentOrange.opacity(0.1) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct MenuBarButtonStyle: ButtonStyle {
    var isPrimary: Bool = false
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isPrimary ? .black : (isDestructive ? .white : .white))
            .frame(width: 44, height: 36)
            .background(isPrimary ? Color.accentOrange : (isDestructive ? Color.error : Color.cardBackground))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
