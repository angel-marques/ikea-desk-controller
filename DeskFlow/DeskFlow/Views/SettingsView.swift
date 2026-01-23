import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: ProfileManager

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Settings")
                        .font(AppFont.title2)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    // Spacer for alignment
                    Image(systemName: "arrow.left")
                        .font(.system(size: 24))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 24) {
                        // Bluetooth Section
                        BluetoothSection()

                        // Available Devices Section
                        if !bluetoothManager.discoveredDevices.isEmpty {
                            AvailableDevicesSection()
                        }

                        // App Data Section
                        AppDataSection()

                        // Troubleshooting Section
                        TroubleshootingSection()
                    }
                    .padding(24)
                }
            }
        }
    }
}

struct BluetoothSection: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Bluetooth Connection")
                    .font(AppFont.title2)
                    .foregroundColor(.textPrimary)

                Spacer()
            }

            // Connected device card
            if bluetoothManager.connectionState.isConnected {
                ConnectedDeviceCard()
            } else if case .connecting = bluetoothManager.connectionState {
                // Connecting state
                CardView(padding: 16) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentOrange.opacity(0.2))
                                .frame(width: 48, height: 48)
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .accentOrange))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(bluetoothManager.connectedDeviceName ?? "IKEA Desk")
                                .font(AppFont.headline)
                                .foregroundColor(.textPrimary)

                            Text("Connecting...")
                                .font(AppFont.body)
                                .foregroundColor(.accentOrange)
                        }

                        Spacer()

                        Button {
                            bluetoothManager.disconnect()
                        } label: {
                            Text("Cancel")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.borderMedium)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else if bluetoothManager.savedDeviceIdentifier != nil {
                // Saved device but not connected
                SavedDeviceCard()
            } else {
                // No saved device
                CardView(padding: 16) {
                    HStack(spacing: 16) {
                        IconBackground(icon: "wifi.slash", color: .textMuted, size: 48, iconSize: 24)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Device Paired")
                                .font(AppFont.headline)
                                .foregroundColor(.textPrimary)

                            Text("Scan to find your IKEA desk")
                                .font(AppFont.body)
                                .foregroundColor(.textMuted)
                        }

                        Spacer()

                        Button {
                            bluetoothManager.startScanning()
                        } label: {
                            Text("Scan")
                                .font(AppFont.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.accentOrange)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Device info
            if bluetoothManager.connectionState.isConnected {
                DeviceInfoCard()
            }
        }
    }
}

struct SavedDeviceCard: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                IconBackground(icon: "desktopcomputer", color: .textMuted, size: 48, iconSize: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetoothManager.connectedDeviceName ?? "IKEA Desk")
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)

                    Text("Saved • Not connected")
                        .font(AppFont.body)
                        .foregroundColor(.textMuted)
                }

                Spacer()

                Button {
                    bluetoothManager.connectToSavedDevice()
                } label: {
                    Text("Connect")
                        .font(AppFont.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentOrange)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.borderMedium)

            Button {
                bluetoothManager.forgetDevice()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Forget Device")
                        .font(AppFont.caption)
                }
                .foregroundColor(.error)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }
}

struct ConnectedDeviceCard: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                IconBackground(icon: "checkmark", color: .success, size: 48, iconSize: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(bluetoothManager.connectedDeviceName ?? "IKEA Desk")
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)

                    Text("Connected")
                        .font(AppFont.body)
                        .foregroundColor(.success)
                }

                Spacer()

                Button {
                    bluetoothManager.disconnect()
                } label: {
                    Text("Disconnect")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.borderMedium)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Divider().background(Color.borderMedium)

            Button {
                bluetoothManager.forgetDevice()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                    Text("Forget Device")
                        .font(AppFont.caption)
                }
                .foregroundColor(.error)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.success, lineWidth: 2)
        )
    }
}

struct DeviceInfoCard: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        CardView(padding: 20) {
            VStack(spacing: 16) {
                InfoRow(label: "Device Type", value: "IKEA IDÅSEN")
                Divider().background(Color.borderMedium)
                InfoRow(label: "Model", value: "DPG1C")
                Divider().background(Color.borderMedium)
                InfoRow(label: "Signal", value: "Strong")
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(AppFont.body)
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
        }
    }
}

struct AvailableDevicesSection: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Devices")
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)

                Spacer()

                if case .scanning = bluetoothManager.connectionState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .accentOrange))
                        .scaleEffect(0.8)
                } else {
                    Button {
                        bluetoothManager.startScanning()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Scan")
                                .font(AppFont.caption)
                        }
                        .foregroundColor(.accentOrange)
                    }
                    .buttonStyle(.plain)
                }
            }

            ForEach(bluetoothManager.discoveredDevices) { device in
                DeviceRow(device: device) {
                    bluetoothManager.connect(to: device)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: DiscoveredDevice
    let onConnect: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.borderMedium)
                    .frame(width: 48, height: 48)

                Image(systemName: "desktopcomputer")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)

                Text("Signal: \(signalStrength(device.rssi))")
                    .font(AppFont.body)
                    .foregroundColor(.textMuted)
            }

            Spacer()

            Button(action: onConnect) {
                Text("Connect")
                    .font(AppFont.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.accentOrange)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
    }

    private func signalStrength(_ rssi: Int) -> String {
        switch rssi {
        case -50...0: return "Excellent"
        case -60..<(-50): return "Good"
        case -70..<(-60): return "Fair"
        default: return "Weak"
        }
    }
}

struct AppDataSection: View {
    @EnvironmentObject var profileManager: ProfileManager
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("App Data")
                .font(AppFont.headline)
                .foregroundColor(.textPrimary)

            CardView(padding: 16) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profiles")
                                .font(AppFont.body)
                                .foregroundColor(.textPrimary)

                            Text("\(profileManager.profiles.count) saved profiles")
                                .font(AppFont.caption)
                                .foregroundColor(.textMuted)
                        }

                        Spacer()

                        Button {
                            showResetConfirmation = true
                        } label: {
                            Text("Reset")
                                .font(AppFont.caption)
                                .foregroundColor(.error)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.error.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .alert("Reset Profiles?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                profileManager.resetToDefaults()
            }
        } message: {
            Text("This will delete all your custom profiles and restore the defaults.")
        }
    }
}

struct TroubleshootingSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Troubleshooting")
                .font(AppFont.headline)
                .foregroundColor(.textPrimary)

            CardView(padding: 20) {
                VStack(spacing: 12) {
                    HelpItem(
                        icon: "1.circle.fill",
                        text: "Make sure your desk is plugged in and the Bluetooth module is active"
                    )

                    HelpItem(
                        icon: "2.circle.fill",
                        text: "Try pressing a button on the desk controller to wake it up"
                    )

                    HelpItem(
                        icon: "3.circle.fill",
                        text: "Ensure Bluetooth is enabled in System Settings"
                    )
                }
            }
        }
    }
}

struct HelpItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accentOrange)

            Text(text)
                .font(AppFont.body)
                .foregroundColor(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(BluetoothManager())
        .environmentObject(ProfileManager())
        .preferredColorScheme(.dark)
}
