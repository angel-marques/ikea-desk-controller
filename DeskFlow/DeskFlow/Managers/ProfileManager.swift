import Foundation
import Combine

@MainActor
class ProfileManager: ObservableObject {
    @Published var profiles: [Profile] = []
    @Published var activeProfile: Profile?

    private let profilesKey = "savedProfiles"
    private let profilesVersionKey = "profilesVersion"
    private let currentVersion = 3  // Increment when icons change

    // Map old invalid icons to new valid ones
    private let iconMigration: [String: String] = [
        "armchair": "person.fill",
        "cup.and.saucer": "mug.fill",
        "chair": "person.fill",
        "chair.fill": "person.fill",
        "gamecontroller": "gamecontroller.fill",
        "book": "book.fill",
        "paintbrush": "paintbrush.fill",
        "music.note": "figure.walk"
    ]

    init() {
        loadProfiles()
    }

    func loadProfiles() {
        let savedVersion = UserDefaults.standard.integer(forKey: profilesVersionKey)

        if let data = UserDefaults.standard.data(forKey: profilesKey),
           let decoded = try? JSONDecoder().decode([Profile].self, from: data) {

            // Migrate icons if needed
            if savedVersion < currentVersion {
                profiles = decoded.map { profile in
                    var migrated = profile
                    if let newIcon = iconMigration[profile.icon] {
                        migrated.icon = newIcon
                    }
                    return migrated
                }
                UserDefaults.standard.set(currentVersion, forKey: profilesVersionKey)
                saveProfiles()
            } else {
                profiles = decoded
            }

            activeProfile = profiles.first(where: { $0.isActive })
        } else {
            // Load defaults
            resetToDefaults()
        }
    }

    func resetToDefaults() {
        profiles = Profile.defaultProfiles
        activeProfile = profiles.first
        UserDefaults.standard.set(currentVersion, forKey: profilesVersionKey)
        saveProfiles()
    }

    func saveProfiles() {
        if let encoded = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(encoded, forKey: profilesKey)
        }
    }

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
    }

    func updateProfile(_ profile: Profile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
            if profile.isActive {
                activeProfile = profile
            }
            saveProfiles()
        }
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
            if var first = profiles.first {
                first.isActive = true
                profiles[0] = first
            }
        }
        saveProfiles()
    }

    func setActive(_ profile: Profile) {
        // Deactivate all profiles
        for i in profiles.indices {
            profiles[i].isActive = false
        }

        // Activate selected profile
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index].isActive = true
            activeProfile = profiles[index]
        }

        saveProfiles()
    }

    func profileForHeight(_ height: Double) -> Profile? {
        // Find closest profile within 2cm tolerance
        profiles.min(by: { abs($0.height - height) < abs($1.height - height) })
            .flatMap { abs($0.height - height) <= 2 ? $0 : nil }
    }
}
