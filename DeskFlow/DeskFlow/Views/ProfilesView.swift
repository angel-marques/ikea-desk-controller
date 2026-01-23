import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var showAddProfile = false
    @State private var selectedProfile: Profile?

    // Find which profile matches current height (within 2cm tolerance)
    private var activeProfileId: UUID? {
        profileManager.profileForHeight(bluetoothManager.currentHeight)?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Profiles")
                    .font(AppFont.title)
                    .foregroundColor(.textPrimary)

                Spacer()

                Button {
                    showAddProfile = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("New")
                            .font(AppFont.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.accentOrange)
                    .cornerRadius(20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            // Profiles List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(profileManager.profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isActive: profile.id == activeProfileId,
                            onActivate: {
                                if bluetoothManager.connectionState.isConnected {
                                    bluetoothManager.moveTo(height: profile.height)
                                }
                            },
                            onEdit: {
                                selectedProfile = profile
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showAddProfile) {
            EditProfileView(profile: nil)
                .environmentObject(profileManager)
                .environmentObject(bluetoothManager)
        }
        .sheet(item: $selectedProfile) { profile in
            EditProfileView(profile: profile)
                .environmentObject(profileManager)
                .environmentObject(bluetoothManager)
        }
    }
}

struct ProfileRow: View {
    let profile: Profile
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon - tap to activate
            Button(action: onActivate) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? Color.accentOrange : Color.borderMedium)
                        .frame(width: 48, height: 48)

                    Image(systemName: profile.icon)
                        .font(.system(size: 24))
                        .foregroundColor(isActive ? .black : .white)
                }
            }
            .buttonStyle(.plain)

            // Content - tap to activate
            Button(action: onActivate) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)

                    Text(String(format: "%.1f cm", profile.height))
                        .font(AppFont.body)
                        .foregroundColor(.textMuted)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Active badge
            if isActive {
                Text("Active")
                    .font(AppFont.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentOrange)
                    .cornerRadius(12)
            }

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20))
                    .foregroundColor(.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.accentOrange : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    ProfilesView()
        .environmentObject(ProfileManager())
        .environmentObject(BluetoothManager())
        .preferredColorScheme(.dark)
        .background(Color.appBackground)
}
