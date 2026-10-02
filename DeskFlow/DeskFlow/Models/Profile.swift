import Foundation

enum DeskRange {
    static let min = 62.0
    static let max = 127.0

    static func contains(_ height: Double) -> Bool { (min...max).contains(height) }

    // Accepts a decimal comma because the field is typed by hand
    static func parse(_ text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), contains(value) else { return nil }
        return value
    }
}

struct Profile: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var height: Double
    // A single Nerd Font glyph, drawn by the SketchyBar item and popup row
    var icon: String = ProfileIcons.defaultGlyph
    // Comment and blank lines above this profile in the file, kept so a save does not drop them
    var leading: [String] = []

    var heightLabel: String { String(format: "%.1f cm", height) }
}
