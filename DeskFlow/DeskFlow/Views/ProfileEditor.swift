import SwiftUI

struct ProfileEditor: View {
    @EnvironmentObject private var link: DeskLink
    @ViewState private var name: String
    @ViewState private var heightText: String
    @ViewState private var icon: String
    @ViewState private var iconValid = true
    @FocusState private var nameFocused: Bool

    let onSave: (String, Double, String) -> Void
    let onCancel: () -> Void

    init(
        name: String, height: Double, icon: String,
        onSave: @escaping (String, Double, String) -> Void, onCancel: @escaping () -> Void
    ) {
        _name = ViewState(initialValue: name)
        _heightText = ViewState(initialValue: String(format: "%.1f", height))
        _icon = ViewState(initialValue: icon)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var parsedHeight: Double? { DeskRange.parse(heightText) }
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && parsedHeight != nil && iconValid }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Name", text: $name)
                    .focused($nameFocused)
                    .accessibilityLabel("Profile name")
                TextField("Height", text: $heightText)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 72)
                    .accessibilityLabel("Height in centimetres")
                Text("cm").foregroundStyle(Color.textSecondary)
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit(save)

            IconPicker(icon: $icon, isValid: $iconValid)

            HStack {
                Button("Use Current Height") {
                    if let height = link.height { heightText = String(format: "%.1f", height) }
                }
                .disabled(link.height == nil)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
            .controlSize(.small)

            if !heightText.isEmpty && parsedHeight == nil {
                Text(String(format: "Height must be %.0f–%.0f cm.", DeskRange.min, DeskRange.max))
                    .font(.caption)
                    .foregroundStyle(Color.statusStop)
            }
        }
        .padding(.vertical, 8)
        .onAppear { nameFocused = true }
    }

    private func save() {
        guard canSave, let height = parsedHeight else { return }
        onSave(name, height, icon)
    }
}
