import SwiftUI

struct MainControlView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var statsManager: StatsManager
    @Binding var showSettings: Bool
    @Binding var selectedTab: Tab

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HeaderView(showSettings: $showSettings)

                // Height Section
                HeightDisplaySection()

                // Controls Section
                ControlsSection()

                // Quick Presets Section
                QuickPresetsSection(selectedTab: $selectedTab)
            }
        }
        .onAppear {
            bluetoothManager.startHeightPolling()
        }
        .onDisappear {
            bluetoothManager.stopHeightPolling()
        }
        .onChange(of: bluetoothManager.connectionState) { _, newState in
            // When connected, try to resume session from last known state
            if newState.isConnected {
                statsManager.resumeSessionIfNeeded(currentHeight: bluetoothManager.currentHeight)
            }
        }
        .onChange(of: bluetoothManager.currentHeight) { _, newHeight in
            statsManager.updateHeight(newHeight)
        }
    }
}

struct HeaderView: View {
    @Binding var showSettings: Bool
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        HStack {
            Text("DeskFlow")
                .font(AppFont.title)
                .foregroundColor(.textPrimary)

            Spacer()

            // Connection indicator
            Circle()
                .fill(bluetoothManager.connectionState.isConnected ? Color.success : Color.textMuted)
                .frame(width: 8, height: 8)

            Button {
                showSettings = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.cardBackground)
                        .frame(width: 44, height: 44)
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
}

struct HeightDisplaySection: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 24) {
            // Height Display
            VStack(spacing: 8) {
                Text("CURRENT HEIGHT")
                    .font(AppFont.caption)
                    .foregroundColor(.textMuted)
                    .tracking(1.5)

                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", bluetoothManager.currentHeight))
                        .font(AppFont.largeTitle)
                        .foregroundColor(.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.2), value: bluetoothManager.currentHeight)

                    Text("cm")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.textMuted)
                }
            }

            // Desk Visualization
            DeskVisualization(height: bluetoothManager.currentHeight)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
    }
}

struct DeskVisualization: View {
    let height: Double

    private var normalizedHeight: CGFloat {
        // Map 62-127cm to 0-1
        CGFloat((height - 62) / (127 - 62))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardBackground)
                .frame(width: 280, height: 180)

            VStack(spacing: 0) {
                // Laptop icon
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 60))
                    .foregroundColor(.accentOrange)

                // Desk surface
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.textMuted)
                    .frame(width: 180, height: 8)
                    .offset(y: -5)

                // Desk legs
                HStack(spacing: 144) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentOrange)
                        .frame(width: 8, height: 30 + normalizedHeight * 30)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentOrange)
                        .frame(width: 8, height: 30 + normalizedHeight * 30)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: normalizedHeight)
    }
}

struct ControlsSection: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        VStack(spacing: 20) {
            // Stop button (when moving)
            if bluetoothManager.isMoving {
                Button {
                    bluetoothManager.stopMovement()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "stop.fill")
                        Text("STOP")
                    }
                    .font(AppFont.headline)
                    .foregroundColor(.white)
                }
                .buttonStyle(CircleButtonStyle(background: .error, size: 80))
            }

            // Up/Down Controls
            HStack(spacing: 16) {
                // Down button
                Button {
                    bluetoothManager.moveDown()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 32, weight: .medium))
                        Text("Lower")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(CircleButtonStyle(background: .cardBackground, foreground: .white))

                // Up button
                Button {
                    bluetoothManager.moveUp()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 32, weight: .semibold))
                        Text("Raise")
                            .font(AppFont.caption)
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(CircleButtonStyle(background: .accentOrange, foreground: .black))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

struct QuickPresetsSection: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @Binding var selectedTab: Tab

    // Find which profile matches current height (within 2cm tolerance)
    private var activeProfileId: UUID? {
        profileManager.profileForHeight(bluetoothManager.currentHeight)?.id
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Quick Presets")
                    .font(AppFont.title2)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    selectedTab = .profiles
                } label: {
                    Text("View All")
                        .font(AppFont.body)
                        .foregroundColor(.accentOrange)
                }
                .buttonStyle(.plain)
            }

            // Preset cards
            HStack(spacing: 12) {
                ForEach(profileManager.profiles.prefix(3)) { profile in
                    PresetCard(
                        profile: profile,
                        isActive: profile.id == activeProfileId
                    ) {
                        if bluetoothManager.connectionState.isConnected {
                            bluetoothManager.moveTo(height: profile.height)
                        }
                    }
                }
            }
        }
        .padding(24)
    }
}

struct PresetCard: View {
    let profile: Profile
    let isActive: Bool
    let onTap: () -> Void
    @EnvironmentObject var bluetoothManager: BluetoothManager

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.accentOrange : Color.borderMedium)
                        .frame(width: 32, height: 32)
                    Image(systemName: profile.icon)
                        .font(.system(size: 14))
                        .foregroundColor(isActive ? .black : .white)
                }

                Text(profile.name)
                    .font(AppFont.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)

                Text(String(format: "%.1f cm", profile.height))
                    .font(AppFont.caption)
                    .foregroundColor(.textMuted)

                if isActive {
                    Text("Active")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentOrange)
                        .cornerRadius(8)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isActive ? Color.accentOrange : Color.borderLight, lineWidth: isActive ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainControlView(showSettings: .constant(false), selectedTab: .constant(.control))
        .environmentObject(BluetoothManager())
        .environmentObject(ProfileManager())
        .environmentObject(StatsManager())
        .preferredColorScheme(.dark)
        .background(Color.appBackground)
}
