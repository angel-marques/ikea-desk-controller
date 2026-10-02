import AppKit
import CoreText
import SwiftUI

struct IconChoice: Identifiable, Equatable {
    let glyph: String
    let name: String
    var id: String { glyph }
}

// Icons are Nerd Font glyphs: the SketchyBar plugin draws them with the same font.
enum ProfileIcons {
    static let fontName = "MesloLGS NF"
    static let defaultGlyph = "\u{F0004}"

    // CTFontCreateWithName substitutes a fallback for a missing family, so compare the family name
    static let fontAvailable: Bool = {
        let font = CTFontCreateWithName(fontName as CFString, 14, nil)
        return CTFontCopyFamilyName(font) as String == fontName
    }()

    static func font(size: CGFloat) -> Font { .custom(fontName, size: size) }

    static let curated: [IconChoice] = [
        IconChoice(glyph: "\u{f0004}", name: "Person"),
        IconChoice(glyph: "\u{f02e6}", name: "Standing person"),
        IconChoice(glyph: "\u{f0efb}", name: "Height"),
        IconChoice(glyph: "\u{f0482}", name: "Seated"),
        IconChoice(glyph: "\u{f0f48}", name: "Office chair"),
        IconChoice(glyph: "\u{f1239}", name: "Desk"),
        IconChoice(glyph: "\u{f0583}", name: "Walking"),
        IconChoice(glyph: "\u{f070e}", name: "Running"),
        IconChoice(glyph: "\u{f117c}", name: "Stretching"),
        IconChoice(glyph: "\u{f117b}", name: "Meditation"),
        IconChoice(glyph: "\u{f01e6}", name: "Fitness"),
        IconChoice(glyph: "\u{f00a3}", name: "Cycling"),
        IconChoice(glyph: "\u{f0322}", name: "Laptop"),
        IconChoice(glyph: "\u{f0379}", name: "Monitor"),
        IconChoice(glyph: "\u{f030c}", name: "Keyboard"),
        IconChoice(glyph: "\u{f0174}", name: "Code"),
        IconChoice(glyph: "\u{f03eb}", name: "Writing"),
        IconChoice(glyph: "\u{f14f7}", name: "Reading"),
        IconChoice(glyph: "\u{f01ee}", name: "Email"),
        IconChoice(glyph: "\u{f00ef}", name: "Calendar"),
        IconChoice(glyph: "\u{f0176}", name: "Coffee"),
        IconChoice(glyph: "\u{f025b}", name: "Snack"),
        IconChoice(glyph: "\u{f0849}", name: "Meeting"),
        IconChoice(glyph: "\u{f03f2}", name: "Phone"),
        IconChoice(glyph: "\u{f02ce}", name: "Headset"),
        IconChoice(glyph: "\u{f0567}", name: "Video call"),
        IconChoice(glyph: "\u{f075a}", name: "Music"),
        IconChoice(glyph: "\u{f0297}", name: "Gaming"),
        IconChoice(glyph: "\u{f03d8}", name: "Design"),
        IconChoice(glyph: "\u{f00d6}", name: "Work"),
        IconChoice(glyph: "\u{f02dc}", name: "Home"),
        IconChoice(glyph: "\u{f02e3}", name: "Rest"),
        IconChoice(glyph: "\u{f0594}", name: "Night"),
        IconChoice(glyph: "\u{f05a8}", name: "Day"),
        IconChoice(glyph: "\u{f04ce}", name: "Star"),
        IconChoice(glyph: "\u{f0241}", name: "Focus"),
        IconChoice(glyph: "\u{f0335}", name: "Ideas"),
        IconChoice(glyph: "\u{f0463}", name: "Launch"),
        IconChoice(glyph: "\u{f0238}", name: "Fire"),
    ]

    // The installed font may be an older patch level than the catalog assumes
    static let available: [IconChoice] = fontAvailable ? curated.filter { hasGlyph($0.glyph) } : []

    static func hasGlyph(_ glyph: String) -> Bool {
        let font = CTFontCreateWithName(fontName as CFString, 14, nil)
        var units = Array(glyph.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    }

    // One grapheme; "|" and "#" would break the desk_profiles line format
    static func singleGlyph(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar), trimmed != "|", trimmed != "#"
        else { return nil }
        return trimmed
    }
}
