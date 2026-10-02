import SwiftUI

struct ProfilesView: View {
    @EnvironmentObject private var link: DeskLink
    @EnvironmentObject private var store: ProfileStore

    private enum Editing: Equatable {
        case existing(Profile.ID)
        case new
    }

    @ViewState private var editing: Editing?
    @ViewState private var selection: Profile.ID?
    @ViewState private var hovered: Profile.ID?

    var body: some View {
        VStack(spacing: 0) {
            header
            if store.profiles.isEmpty && editing != .new {
                emptyState
            } else {
                list
            }
            if let error = store.saveError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.statusStop)
                    .padding(12)
            }
        }
        .focusedSceneValue(\.newProfile, beginNew)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Profiles").font(.headline)
            Spacer()
            Button("Save Current Height", systemImage: "square.and.arrow.down", action: saveCurrentHeight)
                .disabled(link.height == nil)
                .help("Add a profile at the current desk height")
            Button("New Profile", systemImage: "plus", action: beginNew)
                .labelStyle(.iconOnly)
                .help("New profile (⌘N)")
        }
        .controlSize(.small)
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(store.profiles) { profile in
                if editing == .existing(profile.id) {
                    ProfileEditor(
                        name: profile.name, height: profile.height, icon: profile.icon,
                        onSave: { name, height, icon in
                            store.update(profile.id, name: name, height: height, icon: icon)
                            editing = nil
                        },
                        onCancel: { editing = nil })
                } else {
                    row(profile)
                }
            }
            .onMove { store.move(from: $0, to: $1) }

            if editing == .new {
                ProfileEditor(
                    name: "", height: link.height ?? 90, icon: ProfileIcons.defaultGlyph,
                    onSave: { name, height, icon in
                        store.add(name: name, height: height, icon: icon)
                        editing = nil
                    },
                    onCancel: { editing = nil })
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .onDeleteCommand { if let selection { store.delete(selection) } }
        .onKeyPress(.return) {
            guard let selection, editing == nil else { return .ignored }
            editing = .existing(selection)
            return .handled
        }
    }

    private func row(_ profile: Profile) -> some View {
        let isCurrent = link.height.map { abs($0 - profile.height) <= 1 } ?? false
        return HStack(spacing: 10) {
            if ProfileIcons.fontAvailable {
                Text(profile.icon)
                    .font(ProfileIcons.font(size: 16))
                    .foregroundStyle(isCurrent ? Color.accentOrange : Color.textSecondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
            }
            Text(profile.name).lineLimit(1)
            Spacer()
            Image(systemName: "pencil")
                .foregroundStyle(Color.textSecondary)
                .opacity(hovered == profile.id ? 1 : 0)
                .accessibilityHidden(true)
            Text(profile.heightLabel)
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Color.accentOrange : Color.textSecondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(hovered == profile.id && link.canMove ? 0.07 : 0)))
        .onHover { hovered = $0 ? profile.id : (hovered == profile.id ? nil : hovered) }
        .onTapGesture { if link.canMove { link.goto(profile.height) } }
        .contextMenu {
            Button("Go to \(profile.heightLabel)") { link.goto(profile.height) }
                .disabled(!link.canMove)
            Button("Edit…") { editing = .existing(profile.id) }
            Button("Use Current Height") {
                if let height = link.height { store.update(profile.id, name: profile.name, height: height, icon: profile.icon) }
            }
            .disabled(link.height == nil)
            Divider()
            Button("Move Up") { store.moveByOffset(profile.id, -1) }
            Button("Move Down") { store.moveByOffset(profile.id, 1) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(profile.id) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "Current height" : "")
        .accessibilityHint(link.canMove ? "Moves the desk to this height" : "Desk is not available")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Edit") { editing = .existing(profile.id) }
        .accessibilityAction(named: "Delete") { store.delete(profile.id) }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No profiles yet", systemImage: "list.bullet")
        } description: {
            Text("Save the current height or add one by hand.")
        } actions: {
            Button("New Profile", action: beginNew)
        }
        .frame(maxHeight: .infinity)
    }

    private func beginNew() { editing = .new }

    private func saveCurrentHeight() {
        guard let height = link.height else { return }
        let profile = store.add(name: store.uniqueName(base: "Profile"), height: height)
        selection = profile.id
        editing = .existing(profile.id)
    }
}
