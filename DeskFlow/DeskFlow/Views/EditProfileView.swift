import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var profileManager: ProfileManager
    @EnvironmentObject var bluetoothManager: BluetoothManager

    let profile: Profile?

    @State private var name: String = ""
    @State private var height: Double = 72.0
    @State private var selectedIcon: String = "armchair"

    private var isEditing: Bool { profile != nil }

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

                    Text(isEditing ? "Edit Profile" : "New Profile")
                        .font(AppFont.title2)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Button {
                        saveProfile()
                    } label: {
                        Text("Save")
                            .font(AppFont.headline)
                            .foregroundColor(.accentOrange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 32) {
                        // Name Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Name")
                                .font(AppFont.body)
                                .foregroundColor(.textSecondary)

                            TextField("Enter name", text: $name)
                                .font(AppFont.title2)
                                .foregroundColor(.textPrimary)
                                .padding(20)
                                .background(Color.cardBackground)
                                .cornerRadius(16)
                        }

                        // Height Section
                        VStack(spacing: 24) {
                            HStack {
                                Text("Height Setting")
                                    .font(AppFont.body)
                                    .foregroundColor(.textSecondary)

                                Spacer()

                                // Use Current Height button
                                if bluetoothManager.connectionState.isConnected {
                                    Button {
                                        withAnimation {
                                            height = bluetoothManager.currentHeight
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.to.line")
                                                .font(.system(size: 12, weight: .semibold))
                                            Text("Use Current")
                                                .font(AppFont.caption)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.accentOrange)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.accentOrange.opacity(0.15))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", height))
                                    .font(.system(size: 64, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPrimary)
                                    .contentTransition(.numericText())
                                    .animation(.easeInOut(duration: 0.2), value: height)

                                Text("cm")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.textMuted)
                            }

                            // Current desk height indicator
                            if bluetoothManager.connectionState.isConnected {
                                Text("Current desk: \(String(format: "%.1f", bluetoothManager.currentHeight)) cm")
                                    .font(AppFont.caption)
                                    .foregroundColor(.textMuted)
                            }

                            // Slider
                            VStack(spacing: 16) {
                                Slider(value: $height, in: 62...127, step: 0.1)
                                    .accentColor(.accentOrange)

                                HStack {
                                    Text("62 cm")
                                        .font(AppFont.caption)
                                        .foregroundColor(.textMuted)

                                    Spacer()

                                    Text("127 cm")
                                        .font(AppFont.caption)
                                        .foregroundColor(.textMuted)
                                }
                            }

                            // Adjust buttons
                            HStack(spacing: 24) {
                                Button {
                                    withAnimation {
                                        height = max(62, height - 0.5)
                                    }
                                } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(CircleButtonStyle(background: .cardBackground, size: 56))

                                Button {
                                    withAnimation {
                                        height = min(127, height + 0.5)
                                    }
                                } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 24, weight: .medium))
                                        .foregroundColor(.black)
                                }
                                .buttonStyle(CircleButtonStyle(background: .accentOrange, foreground: .black, size: 56))
                            }
                        }

                        // Icon Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Profile Icon")
                                .font(AppFont.body)
                                .foregroundColor(.textSecondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                                ForEach(Profile.availableIcons, id: \.self) { icon in
                                    IconOption(
                                        icon: icon,
                                        isSelected: selectedIcon == icon
                                    ) {
                                        selectedIcon = icon
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }

                Spacer()

                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        bluetoothManager.moveTo(height: height)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Set as Current Height")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    if isEditing {
                        Button {
                            deleteProfile()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .font(.system(size: 20, weight: .semibold))
                                Text("Delete Profile")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            if let profile = profile {
                name = profile.name
                height = profile.height
                selectedIcon = profile.icon
            } else {
                height = bluetoothManager.currentHeight
            }
        }
    }

    private func saveProfile() {
        if var existingProfile = profile {
            existingProfile.name = name
            existingProfile.height = height
            existingProfile.icon = selectedIcon
            profileManager.updateProfile(existingProfile)
        } else {
            let newProfile = Profile(
                name: name.isEmpty ? "New Profile" : name,
                height: height,
                icon: selectedIcon
            )
            profileManager.addProfile(newProfile)
        }
        dismiss()
    }

    private func deleteProfile() {
        if let profile = profile {
            profileManager.deleteProfile(profile)
        }
        dismiss()
    }
}

struct IconOption: View {
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentOrange : Color.borderMedium)
                    .frame(width: 56, height: 56)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .black : .white)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EditProfileView(profile: Profile.defaultProfiles[0])
        .environmentObject(ProfileManager())
        .environmentObject(BluetoothManager())
        .preferredColorScheme(.dark)
}
