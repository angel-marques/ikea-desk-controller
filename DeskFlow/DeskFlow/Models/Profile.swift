import Foundation

struct Profile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var height: Double  // in centimeters
    var icon: String
    var isActive: Bool

    init(id: UUID = UUID(), name: String, height: Double, icon: String = "person.fill", isActive: Bool = false) {
        self.id = id
        self.name = name
        self.height = height
        self.icon = icon
        self.isActive = isActive
    }

    static let defaultProfiles: [Profile] = [
        Profile(name: "Sitting", height: 72.4, icon: "person.fill", isActive: true),
        Profile(name: "Standing", height: 106.7, icon: "figure.stand", isActive: false),
        Profile(name: "Drafting", height: 92.7, icon: "pencil", isActive: false),
        Profile(name: "Meeting", height: 76.2, icon: "mug.fill", isActive: false)
    ]

    // All valid SF Symbols for macOS 14+
    static let availableIcons = [
        "person.fill",
        "figure.stand",
        "figure.walk",
        "pencil",
        "mug.fill",
        "laptopcomputer",
        "desktopcomputer",
        "gamecontroller.fill",
        "book.fill",
        "paintbrush.fill"
    ]
}
