import SwiftUI

struct DeskControlView: View {
    @EnvironmentObject private var link: DeskLink
    @ViewState private var target = ""
    @ViewState private var targetInvalid = false

    var body: some View {
        VStack(spacing: 14) {
            readout
            statusRow
            controls
            hint
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var readout: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(link.height.map { String(format: "%.1f", $0) } ?? "—")
                .font(.heightReadout)
                .monospacedDigit()
                .foregroundStyle(link.height == nil ? Color.textSecondary : .white)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.2), value: link.height)
            Text("cm")
                .font(.title2)
                .foregroundStyle(Color.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Desk height")
        .accessibilityValue(link.height.map { String(format: "%.1f centimetres", $0) } ?? "Unknown")
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle().fill(statusColor).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(statusTitle).fontWeight(.semibold)
            if let detail = statusDetail {
                Text(detail).foregroundStyle(Color.textSecondary)
            }
            if link.status == .moving {
                Button("Stop", systemImage: "stop.fill") { link.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .tint(.statusStop)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .help("Stop the desk (⌘.)")
            }
        }
        .font(.callout)
        .lineLimit(1)
        .frame(maxWidth: .infinity, minHeight: 24)
        .accessibilityElement(children: .combine)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button("−1 cm", systemImage: "arrow.down") { link.nudge(-1) }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .help("Lower the desk by 1 cm (⌘↓)")
            TextField("Go to", text: $target, prompt: Text(link.height.map { String(format: "%.1f", $0) } ?? "Height"))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 88)
                .onSubmit(goToTarget)
                .onChange(of: target) { targetInvalid = false }
                .accessibilityLabel("Go to height in centimetres")
            Text("cm").foregroundStyle(Color.textSecondary)
            Button("+1 cm", systemImage: "arrow.up") { link.nudge(1) }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .help("Raise the desk by 1 cm (⌘↑)")
        }
        .controlSize(.large)
        .disabled(!link.canMove)
    }

    private var hint: some View {
        Text(String(format: "%.0f–%.0f cm · Return to go", DeskRange.min, DeskRange.max))
            .font(.caption)
            .foregroundStyle(targetInvalid ? Color.statusStop : Color.textSecondary)
    }

    private func goToTarget() {
        guard let value = DeskRange.parse(target) else {
            targetInvalid = !target.isEmpty
            return
        }
        link.goto(value)
        target = ""
    }

    private var statusTitle: String {
        switch link.status {
        case .connected: "Connected"
        case .moving: "Moving"
        case .disconnected: "Desk disconnected"
        case .providerMissing: "Provider not running"
        }
    }

    private var statusDetail: String? {
        switch link.status {
        case .disconnected: "Waiting for the desk"
        case .providerMissing: "Reload SketchyBar to start it"
        default: nil
        }
    }

    private var statusColor: Color {
        switch link.status {
        case .connected: .statusOK
        case .moving: .accentOrange
        case .disconnected, .providerMissing: .statusStop
        }
    }
}
