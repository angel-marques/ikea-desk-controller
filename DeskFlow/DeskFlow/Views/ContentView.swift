import SwiftUI

enum Tab {
    case control
    case profiles
    case stats
}

struct ContentView: View {
    @State private var selectedTab: Tab = .control
    @State private var showSettings = false
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var profileManager: ProfileManager

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                Group {
                    switch selectedTab {
                    case .control:
                        MainControlView(showSettings: $showSettings, selectedTab: $selectedTab)
                    case .profiles:
                        ProfilesView()
                    case .stats:
                        StatsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Navigation
                BottomNavigationBar(selectedTab: $selectedTab)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(bluetoothManager)
                .environmentObject(profileManager)
        }
    }
}

struct BottomNavigationBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack {
            NavItem(icon: "house.fill", label: "Control", isSelected: selectedTab == .control)
                .onTapGesture { selectedTab = .control }

            Spacer()

            NavItem(icon: "bookmark.fill", label: "Profiles", isSelected: selectedTab == .profiles)
                .onTapGesture { selectedTab = .profiles }

            Spacer()

            NavItem(icon: "chart.bar.fill", label: "Stats", isSelected: selectedTab == .stats)
                .onTapGesture { selectedTab = .stats }
        }
        .padding(.horizontal, 40)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .background(Color.navBackground)
        .overlay(
            Rectangle()
                .fill(Color.borderMedium)
                .frame(height: 1),
            alignment: .top
        )
    }
}

struct NavItem: View {
    let icon: String
    let label: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(isSelected ? .accentOrange : .textMuted)

            Text(label)
                .font(AppFont.small)
                .foregroundColor(isSelected ? .accentOrange : .textMuted)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
        .environmentObject(ProfileManager())
        .environmentObject(StatsManager())
        .preferredColorScheme(.dark)
}
