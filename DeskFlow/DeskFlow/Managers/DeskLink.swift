import Foundation
import AppKit

// The desk provider owns the Bluetooth connection. This class only reads its state file
// and writes commands to its FIFO.
@MainActor
final class DeskLink: ObservableObject {
    enum Status {
        case providerMissing, disconnected, connected, moving
    }

    @Published private(set) var status: Status = .providerMissing
    @Published private(set) var height: Double?

    var canMove: Bool { status == .connected || status == .moving }

    private let cacheDirectory = NSHomeDirectory() + "/.cache/sketchybar"
    private var statePath: String { cacheDirectory + "/desk.state" }
    private var fifoPath: String { cacheDirectory + "/desk.fifo" }
    private var watcher: PathWatcher?
    private var activationObserver: NSObjectProtocol?

    init() {
        watcher = PathWatcher(path: statePath) { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // A provider that exits leaves a stale state file; the FIFO probe catches it on return to the app
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func goto(_ target: Double) { send("goto \(String(format: "%.1f", target))") }

    func nudge(_ delta: Double) { send("nudge \(String(format: "%+.1f", delta))") }

    func stop() { send("stop") }

    private func refresh() {
        guard providerIsListening(), let line = try? String(contentsOfFile: statePath, encoding: .utf8) else {
            status = .providerMissing
            height = nil
            return
        }
        let fields = line.split(whereSeparator: \.isWhitespace)
        guard fields.count == 2, let value = Double(fields[0]) else { return }
        switch fields[1] {
        case "connected": status = .connected
        case "moving": status = .moving
        default: status = .disconnected
        }
        height = canMove && value > 0 ? value : nil
    }

    // The provider holds the FIFO open for reading; without it a non-blocking write open fails with ENXIO
    private func providerIsListening() -> Bool {
        let fd = open(fifoPath, O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else { return false }
        close(fd)
        return true
    }

    private func send(_ command: String) {
        let fd = open(fifoPath, O_WRONLY | O_NONBLOCK)
        guard fd >= 0 else {
            refresh()
            return
        }
        defer { close(fd) }
        let bytes = Array((command + "\n").utf8)
        _ = write(fd, bytes, bytes.count)
    }
}
