import Foundation

// desk_profiles is the single source of truth, shared with the SketchyBar plugin.
// Each line is "<Name> | <cm> | <glyph>". The legacy "<Name> <cm>" still parses: the height is the last
// field and the icon is the default. Keep in sync with read_profiles in the plugin desk.sh.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published private(set) var saveError: String?

    private let path: String
    private var trailing: [String] = []
    private var lastText = ""
    private var watcher: PathWatcher?

    init() {
        // A symlinked file (dotfiles manager) must stay a symlink; an atomic write replaces the link itself
        let configured = NSHomeDirectory() + "/.config/sketchybar/desk_profiles"
        path = URL(fileURLWithPath: configured).resolvingSymlinksInPath().path
        reload()
        watcher = PathWatcher(path: path) { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    // MARK: - Editing

    @discardableResult
    func add(name: String, height: Double, icon: String = ProfileIcons.defaultGlyph) -> Profile {
        let profile = Profile(name: Self.cleaned(name), height: Self.rounded(height), icon: icon)
        profiles.append(profile)
        save()
        return profile
    }

    func update(_ id: Profile.ID, name: String, height: Double, icon: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        profiles[index].name = Self.cleaned(name)
        profiles[index].height = Self.rounded(height)
        profiles[index].icon = icon
        save()
    }

    func delete(_ id: Profile.ID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        // Notes above a deleted profile move to the next one
        let orphaned = profiles[index].leading
        profiles.remove(at: index)
        if index < profiles.count {
            profiles[index].leading = orphaned + profiles[index].leading
        } else {
            trailing = orphaned + trailing
        }
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func moveByOffset(_ id: Profile.ID, _ offset: Int) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let target = index + offset
        guard profiles.indices.contains(target) else { return }
        move(from: IndexSet(integer: index), to: offset > 0 ? target + 1 : target)
    }

    func uniqueName(base: String) -> String {
        var number = profiles.count + 1
        while profiles.contains(where: { $0.name == "\(base) \(number)" }) { number += 1 }
        return "\(base) \(number)"
    }

    // MARK: - File

    private func reload() {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        guard text != lastText else { return }
        lastText = text
        let parsed = Self.parse(text)
        trailing = parsed.trailing
        profiles = Self.reusingIdentities(parsed.profiles, from: profiles)
    }

    private func save() {
        let text = Self.serialize(profiles, trailing: trailing)
        do {
            try FileManager.default.createDirectory(
                atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            try text.write(toFile: path, atomically: true, encoding: .utf8)
            lastText = text
            saveError = nil
            notifyBar()
        } catch {
            saveError = "Could not save profiles: \(error.localizedDescription)"
        }
    }

    // A GUI app has no Homebrew PATH; a missing sketchybar is not an error
    private func notifyBar() {
        let binary = "/opt/homebrew/bin/sketchybar"
        guard FileManager.default.isExecutableFile(atPath: binary) else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binary)
        process.arguments = ["--trigger", "desk_profiles_changed"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    // MARK: - Format

    nonisolated static func parse(_ text: String) -> (profiles: [Profile], trailing: [String]) {
        var profiles: [Profile] = []
        var pending: [String] = []
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let fields = fields(of: trimmed) else {
                pending.append(line)
                continue
            }
            profiles.append(Profile(
                name: fields.name, height: fields.height,
                icon: fields.glyph.isEmpty ? ProfileIcons.defaultGlyph : fields.glyph, leading: pending))
            pending = []
        }
        return (profiles, pending)
    }

    nonisolated static func serialize(_ profiles: [Profile], trailing: [String]) -> String {
        var lines: [String] = []
        for profile in profiles {
            lines.append(contentsOf: profile.leading)
            lines.append("\(profile.name) | \(format(profile.height)) | \(profile.icon)")
        }
        lines.append(contentsOf: trailing)
        return lines.isEmpty ? "" : lines.joined(separator: "\n") + "\n"
    }

    // Same rules as read_profiles in desk.sh: the height is a plain decimal and the name is not empty
    nonisolated private static func fields(of line: String) -> (name: String, height: Double, glyph: String)? {
        let name: String, heightText: String
        var glyph = ""
        if line.contains("|") {
            let parts = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { return nil }
            (name, heightText) = (parts[0], parts[1])
            if parts.count > 2 { glyph = parts[2] }
        } else {
            guard let split = line.lastIndex(where: { $0 == " " || $0 == "\t" }) else { return nil }
            name = line[..<split].trimmingCharacters(in: .whitespaces)
            heightText = String(line[line.index(after: split)...])
        }
        guard !name.isEmpty, heightText.range(of: #"^[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil,
              let height = Double(heightText)
        else { return nil }
        return (name, height, glyph)
    }

    // The plugin reads the height as a plain decimal; "74" and "74.5" both parse
    nonisolated private static func format(_ height: Double) -> String {
        let text = String(format: "%.1f", height)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    nonisolated private static func rounded(_ height: Double) -> Double { (height * 10).rounded() / 10 }

    // A leading "#" would turn the line into a comment and "|" would split the name
    nonisolated private static func cleaned(_ name: String) -> String {
        var result = name.components(separatedBy: .newlines).joined(separator: " ")
            .replacingOccurrences(of: "|", with: " ")
            .trimmingCharacters(in: .whitespaces)
        while result.hasPrefix("#") { result.removeFirst() }
        result = result.trimmingCharacters(in: .whitespaces)
        return result.isEmpty ? "Profile" : result
    }

    // A reload keeps the id of an unchanged profile so an open editor survives an external edit elsewhere
    nonisolated private static func reusingIdentities(_ parsed: [Profile], from old: [Profile]) -> [Profile] {
        var available = old
        return parsed.map { profile in
            var result = profile
            if let match = available.firstIndex(where: { $0.name == profile.name && $0.height == profile.height }) {
                result.id = available.remove(at: match).id
            }
            return result
        }
    }
}
