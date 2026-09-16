// Where the shipped GGUF comes from.
//
// On Android this is a window inside the APK, and D-013's whole apparatus — the `.gguf.so` name, the
// bundletool alignment rule, the 32-byte offset check — exists to make that window mmappable. On
// iOS an app bundle is a directory, not a zip, so the model is a plain file with a plain path and
// all of that disappears (leaves/architecture/ios-port.md).
//
// What does NOT change is the call: `arivu_load_model_fd(fd, offset, length)`, with offset 0 and the
// whole file. One loading path in the core, exercised identically by both platforms.
//
// spine: C1, C2

import ArivuCore
import Foundation

public enum ModelSourceError: Error, CustomStringConvertible {
    case notInBundle(String)
    case cannotOpen(String, errno: Int32)
    case cannotSize(String, errno: Int32)

    public var description: String {
        switch self {
        case .notInBundle(let name):
            return "\(name) is not in the app bundle — the model copy build phase did not run"
        case .cannotOpen(let path, let e):
            return "could not open \(path): \(String(cString: strerror(e)))"
        case .cannotSize(let path, let e):
            return "could not measure \(path): \(String(cString: strerror(e)))"
        }
    }
}

/// An open model file. Closing the descriptor after the load is safe and deliberate: the mapping
/// the core makes outlives the descriptor, and holding one open for the life of the app is a
/// resource nobody needs.
public final class OpenModelFile {
    public let window: ModelWindow
    public let url: URL
    private var closed = false

    init(url: URL, fileDescriptor: Int32, length: UInt64) {
        self.url = url
        self.window = ModelWindow(fileDescriptor: fileDescriptor, offset: 0, length: length)
    }

    public func close() {
        guard !closed else { return }
        closed = true
        Darwin.close(window.fileDescriptor)
    }

    deinit { close() }
}

public protocol ModelSource: Sendable {
    /// Opens the model. The caller closes it once the load has returned.
    func open() throws -> OpenModelFile
}

/// The shipping source: the GGUF sitting in the app bundle, copied there by
/// `tools/ios/copy_model.sh` as a build phase (spine: C1 — nothing is downloaded, ever).
public struct BundleModelSource: ModelSource {
    private let bundle: Bundle
    private let name: String
    private let ext: String

    public init(bundle: Bundle = .main,
                name: String = Policy.modelResourceName,
                extension ext: String = Policy.modelResourceExtension) {
        self.bundle = bundle
        self.name = name
        self.ext = ext
    }

    public func open() throws -> OpenModelFile {
        guard let url = bundle.url(forResource: name, withExtension: ext) else {
            throw ModelSourceError.notInBundle("\(name).\(ext)")
        }
        return try FileModelSource(url: url).open()
    }
}

/// Any file on disk. Used by the benchmark and by tests; the shipping app uses `BundleModelSource`.
public struct FileModelSource: ModelSource {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func open() throws -> OpenModelFile {
        let path = url.path
        let fd = Darwin.open(path, O_RDONLY)
        guard fd >= 0 else { throw ModelSourceError.cannotOpen(path, errno: errno) }
        var status = stat()
        guard fstat(fd, &status) == 0 else {
            let e = errno
            Darwin.close(fd)
            throw ModelSourceError.cannotSize(path, errno: e)
        }
        return OpenModelFile(url: url, fileDescriptor: fd, length: UInt64(status.st_size))
    }
}
