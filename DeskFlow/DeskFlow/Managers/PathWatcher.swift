import Foundation

// A file-descriptor source follows in-place writes but loses a file that is replaced by a rename.
// The directory source catches the rename and the creation, and the file source is attached again each time.
final class PathWatcher {
    private let path: String
    private let onChange: () -> Void
    private var fileSource: DispatchSourceFileSystemObject?
    private var directorySource: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
        directorySource = makeSource(at: (path as NSString).deletingLastPathComponent, mask: .write)
        fileSource = makeSource(at: path, mask: [.write, .extend, .delete, .rename, .attrib])
    }

    deinit {
        pending?.cancel()
        fileSource?.cancel()
        directorySource?.cancel()
    }

    private func makeSource(at target: String, mask: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let fd = open(target, O_EVTONLY)
        guard fd >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: mask, queue: .main)
        source.setEventHandler { [weak self] in self?.schedule() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    // One save produces several events; the delay merges them into one callback
    private func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.fileSource?.cancel()
            self.fileSource = self.makeSource(at: self.path, mask: [.write, .extend, .delete, .rename, .attrib])
            self.onChange()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }
}
