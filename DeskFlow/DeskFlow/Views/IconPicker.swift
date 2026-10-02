import SwiftUI

// Compact radio-style grid of curated glyphs plus a field for any other single glyph.
// The grid is one focus stop; the arrow keys move the selection like a radio group.
struct IconPicker: View {
    @Binding var icon: String
    @Binding var isValid: Bool

    @ViewState private var customText: String
    @FocusState private var gridFocused: Bool

    private static let columnCount = 10
    private let columns = Array(repeating: GridItem(.flexible(minimum: 24), spacing: 4), count: columnCount)

    init(icon: Binding<String>, isValid: Binding<Bool>) {
        _icon = icon
        _isValid = isValid
        let isCurated = ProfileIcons.available.contains { $0.glyph == icon.wrappedValue }
        _customText = ViewState(initialValue: isCurated ? "" : icon.wrappedValue)
    }

    private var customInvalid: Bool {
        !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ProfileIcons.singleGlyph(customText) == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("Icon").font(.caption).foregroundStyle(Color.textSecondary)
                Spacer()
                TextField("Custom", text: $customText)
                    .font(customText.isEmpty ? .system(size: 12) : ProfileIcons.font(size: 13))
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .help("Paste any single glyph")
                    .accessibilityLabel("Custom icon glyph")
            }

            if ProfileIcons.available.isEmpty {
                Text("\(ProfileIcons.fontName) is not installed, so there is no icon set to pick from. Paste a glyph instead.")
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                grid
            }

            if customInvalid {
                Text("Enter a single character.")
                    .font(.caption)
                    .foregroundStyle(Color.statusStop)
            }
        }
        .onChange(of: customText) { _, text in
            if let glyph = ProfileIcons.singleGlyph(text) { icon = glyph }
            isValid = !customInvalid
        }
    }

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(ProfileIcons.available) { choice in
                IconCell(choice: choice, isSelected: icon == choice.glyph) { select(choice.glyph) }
            }
        }
        .padding(4)
        .focusable()
        .focused($gridFocused)
        .onKeyPress(.leftArrow) { move(-1) }
        .onKeyPress(.rightArrow) { move(1) }
        .onKeyPress(.upArrow) { move(-Self.columnCount) }
        .onKeyPress(.downArrow) { move(Self.columnCount) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Icon")
    }

    private func select(_ glyph: String) {
        icon = glyph
        customText = ""
        gridFocused = true
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        let options = ProfileIcons.available
        guard !options.isEmpty else { return .ignored }
        let current = options.firstIndex { $0.glyph == icon }
        let target = current.map { min(max($0 + delta, 0), options.count - 1) } ?? 0
        icon = options[target].glyph
        customText = ""
        return .handled
    }
}

private struct IconCell: View {
    let choice: IconChoice
    let isSelected: Bool
    let action: () -> Void

    @ViewState private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(choice.glyph)
                .font(ProfileIcons.font(size: 16))
                .foregroundStyle(isSelected ? Color.accentOrange : Color.primary)
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentOrange.opacity(0.18) : Color.white.opacity(hovered ? 0.08 : 0)))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentOrange, lineWidth: isSelected ? 1.5 : 0))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(choice.name)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
