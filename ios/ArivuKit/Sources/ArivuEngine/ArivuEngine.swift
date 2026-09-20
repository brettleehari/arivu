// The Swift side of the platform boundary: one Swift object over `arivu_*`.
//
// Rules this file exists to enforce, all of them from core/include/arivu/arivu.h:
//
//  1. One handle is used from one thread at a time, EXCEPT `arivu_cancel`, which is safe from any
//     thread and is the whole point of having it. So every call but cancel runs on one private
//     serial queue, and model/context lifetime changes can never race a running decode.
//  2. The handle cannot leak. It is owned by `Handle`, a final class whose only job is to free it in
//     `deinit`. Nothing else can create or release one, and there is no code path — thrown error,
//     cancelled task, torn-down stream — that skips a `deinit`.
//  3. Model bytes arrive as fd + offset + length. On iOS that is the bundle file, offset 0, whole
//     length. Android passes a window inside the APK. One signature, one loading path, no `#if`.
//
// spine: C2, C10, C11

import ArivuCore
import CArivuCore
import Foundation

public enum ArivuEngineError: Error, CustomStringConvertible {
    case engineCreateFailed
    case modelLoadFailed(String)
    case contextCreateFailed(String)
    case tokenizeFailed
    case noModel

    public var description: String {
        switch self {
        case .engineCreateFailed: return "could not create the engine"
        case .modelLoadFailed(let m): return "model load failed: \(m)"
        case .contextCreateFailed(let m): return "context creation failed: \(m)"
        case .tokenizeFailed: return "the tokenizer could not count this text"
        case .noModel: return "no model is loaded"
        }
    }

    /// Whether this failure is the phone being full rather than Arivu being broken. It decides
    /// between `load_failed` and `load_failed_low_memory` (leaves/design.md §7).
    public var isMemoryFailure: Bool {
        switch self {
        case .modelLoadFailed(let m), .contextCreateFailed(let m):
            let lower = m.lowercased()
            return ["alloc", "memory", "mmap", "out of", "enomem", "cannot allocate"].contains { lower.contains($0) }
        default:
            return false
        }
    }
}

public struct ContextParameters: Equatable, Sendable {
    public var nCtx: Int32
    public var nBatch: Int32
    public var nThreads: Int32
    public var kvQ8_0: Bool
    public var repack: Bool

    public init(nCtx: Int32, nBatch: Int32, nThreads: Int32, kvQ8_0: Bool, repack: Bool) {
        self.nCtx = nCtx
        self.nBatch = nBatch
        self.nThreads = nThreads
        self.kvQ8_0 = kvQ8_0
        self.repack = repack
    }

    public init(profile: Profile, threads: Int32? = nil) {
        self.init(nCtx: profile.nCtx, nBatch: profile.nBatch,
                  nThreads: threads ?? profile.nThreads,
                  kvQ8_0: profile.kvQ8_0, repack: profile.repack)
    }
}

public struct SamplingParameters: Equatable, Sendable {
    public var temperature: Float
    public var topK: Int32
    public var topP: Float
    public var seed: UInt32

    public init(temperature: Float, topK: Int32, topP: Float, seed: UInt32) {
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.seed = seed
    }

    /// The shipped sampling (D-007). The seed is the one value that changes per reply.
    public static func shipped(seed: UInt32 = UInt32.random(in: 0...UInt32.max)) -> SamplingParameters {
        SamplingParameters(temperature: Policy.temperature, topK: Policy.topK, topP: Policy.topP, seed: seed)
    }
}

/// The model card, as the file states it. Nothing here is authored; see `arivu_model_info`.
public struct ModelInfo: Equatable, Sendable {
    public let description: String     // llama's own summary, e.g. "qwen3 0.6B Q4_K - Medium"
    public let architecture: String
    public let name: String
    public let parameters: UInt64
    public let sizeBytes: UInt64
    public let layers: Int32
    public let heads: Int32
    public let kvHeads: Int32
    public let embeddingWidth: Int32
    public let keyLength: Int32
    public let valueLength: Int32
    public let trainedContext: Int32
    public let vocabulary: Int32

    init(_ raw: arivu_model_info) {
        // C fixed-size char arrays import as tuples; rebinding is the only way to read them.
        var r = raw
        self.description  = withUnsafePointer(to: &r.description)  { $0.withMemoryRebound(to: CChar.self, capacity: 128) { String(cString: $0) } }
        self.architecture = withUnsafePointer(to: &r.architecture) { $0.withMemoryRebound(to: CChar.self, capacity: 32)  { String(cString: $0) } }
        self.name         = withUnsafePointer(to: &r.name)         { $0.withMemoryRebound(to: CChar.self, capacity: 96)  { String(cString: $0) } }
        self.parameters = raw.parameters
        self.sizeBytes = raw.size_bytes
        self.layers = raw.n_layer
        self.heads = raw.n_head
        self.kvHeads = raw.n_head_kv
        self.embeddingWidth = raw.n_embd
        self.keyLength = raw.key_length
        self.valueLength = raw.value_length
        self.trainedContext = raw.n_ctx_train
        self.vocabulary = raw.n_vocab
    }

    /// Bytes of KV cache per token at the given precision, from this model's own shape.
    /// The profile predicts the same number; a mismatch means the profile is stale.
    public func kvBytesPerToken(q8_0: Bool) -> UInt64 {
        arivu_kv_bytes_per_token(layers, kvHeads, keyLength, valueLength, q8_0)
    }

    /// Grouped-query attention: fewer KV heads than attention heads. This ratio is the single
    /// reason the cache is small enough for a phone.
    public var queriesPerKVHead: Int32 { kvHeads > 0 ? heads / kvHeads : 0 }
}

/// Where the GGUF bytes are. iOS: the app bundle file, offset 0, whole length.
public struct ModelWindow: Sendable {
    public let fileDescriptor: Int32
    public let offset: UInt64
    public let length: UInt64

    public init(fileDescriptor: Int32, offset: UInt64, length: UInt64) {
        self.fileDescriptor = fileDescriptor
        self.offset = offset
        self.length = length
    }
}

public final class ArivuEngine: @unchecked Sendable {
    /// Sole owner of the C handle. Separate from `ArivuEngine` so that no future refactor of the
    /// engine's own stored properties can accidentally lose the `deinit` that frees it.
    private final class Handle: @unchecked Sendable {
        let raw: OpaquePointer

        init() throws {
            guard let p = arivu_engine_create() else { throw ArivuEngineError.engineCreateFailed }
            raw = p
        }

        deinit {
            // Cancel first: if a generate() is somehow still running on another thread, it must stop
            // touching the handle before the free. arivu_cancel is the one thread-safe entry point.
            arivu_cancel(raw)
            arivu_engine_free(raw)
        }
    }

    private let handle: Handle
    private let queue = DispatchQueue(label: "io.github.brettleehari.arivu.engine", qos: .userInitiated)

    public init() throws {
        handle = try Handle()
    }

    /// Thread-safe, by contract with the C API. Takes effect mid-prefill or at the next token.
    /// Never hops to `queue`: the queue is busy running the generation this is trying to stop.
    public func cancel() {
        arivu_cancel(handle.raw)
    }

    public static var coreVersion: String { String(cString: arivu_version()) }

    /// What the shipped GGUF says about itself. `nil` until a model is loaded — and the model is
    /// loaded lazily on the first message (C1), so a page that shows this must be able to say
    /// "not loaded yet" rather than force a 378 MB map just to fill a row.
    public func modelInfo() async -> ModelInfo? {
        await run {
            var raw = arivu_model_info()
            guard arivu_model_info_get(self.handle.raw, &raw) else { return nil }
            return ModelInfo(raw)
        }
    }

    // MARK: - Model and context lifetime

    /// The only loading path. Android hands a window inside the APK; iOS hands the bundle file at
    /// offset 0 with its whole length. `arivu_load_model_path` exists in the C API and is
    /// deliberately not used here, so both platforms exercise the same code in the core.
    public func loadModel(_ window: ModelWindow, repack: Bool = Policy.repackWeights) async throws {
        try await runThrowing {
            try Self.withErrorBuffer { buf, cap in
                arivu_load_model_fd(self.handle.raw, window.fileDescriptor, window.offset, window.length, repack, buf, cap)
            } orThrow: { ArivuEngineError.modelLoadFailed($0) }
        }
    }

    public func ensureContext(_ params: ContextParameters) async throws {
        try await runThrowing {
            var p = arivu_context_params()
            p.n_ctx = params.nCtx
            p.n_batch = params.nBatch
            p.n_threads = params.nThreads
            p.kv_q8_0 = params.kvQ8_0
            p.repack = params.repack
            try Self.withErrorBuffer { buf, cap in
                arivu_ensure_context(self.handle.raw, p, buf, cap)
            } orThrow: { ArivuEngineError.contextCreateFailed($0) }
        }
    }

    public func hasModel() async -> Bool { await run { arivu_has_model(self.handle.raw) } }
    public func hasContext() async -> Bool { await run { arivu_has_context(self.handle.raw) } }
    public func contextSize() async -> Int32 { await run { arivu_n_ctx(self.handle.raw) } }

    /// Releases the KV cache and compute buffers. The mmap'd weights stay, because they are clean
    /// file-backed pages the kernel can take back for nothing.
    public func freeContext() async { await run { arivu_free_context(self.handle.raw) } }

    /// Frees context and weights.
    public func freeModel() async { await run { arivu_free_model(self.handle.raw) } }

    public func countTokens(_ text: String) async throws -> Int32 {
        let n: Int32 = await run {
            let bytes = Array(text.utf8)
            return bytes.withUnsafeBufferPointer { p in
                p.baseAddress.map { arivu_count_tokens(self.handle.raw, $0, p.count) } ?? 0
            }
        }
        guard n >= 0 else { throw ArivuEngineError.tokenizeFailed }
        return n
    }

    /// Compute-buffer size of the live context in KiB; -1 if there is no context.
    public func computeBufferKiB() async -> Int64 { await run { arivu_compute_buffer_kib(self.handle.raw) } }

    // MARK: - Generation

    /// Emits text pieces and exactly one `.done`, then finishes.
    ///
    /// Cancellation: `cancel()` from anywhere, or simply stop consuming the stream — the
    /// termination handler cancels for you, so a `for await` loop that breaks does not leave a
    /// generation running. Both land in the same `arivu_cancel`, which is what lets the app label a
    /// stop by *why* it happened (user, memory pressure, background expiry) rather than by where the
    /// call came from (leaves/design.md §5.1).
    public func generate(prompt: String,
                         maxNewTokens: Int32,
                         sampling: SamplingParameters) -> AsyncStream<GenerationEvent> {
        AsyncStream(GenerationEvent.self, bufferingPolicy: .unbounded) { continuation in
            continuation.onTermination = { [weak self] termination in
                if case .cancelled = termination { self?.cancel() }
            }
            queue.async { [handle] in
                let sink = PieceSink(continuation: continuation)
                let sinkPointer = Unmanaged.passRetained(sink).toOpaque()
                defer { Unmanaged<PieceSink>.fromOpaque(sinkPointer).release() }

                var params = arivu_sampling_params()
                params.temperature = sampling.temperature
                params.top_k = sampling.topK
                params.top_p = sampling.topP
                params.seed = sampling.seed

                var error: String?
                var raw = arivu_stats()
                var errBuf = [CChar](repeating: 0, count: Self.errorBufferSize)
                let promptBytes = Array(prompt.utf8)

                promptBytes.withUnsafeBufferPointer { p in
                    errBuf.withUnsafeMutableBufferPointer { e in
                        raw = arivu_generate(handle.raw,
                                             p.baseAddress, p.count,
                                             maxNewTokens, params,
                                             { bytes, len, user in
                                                 guard let bytes, let user, len > 0 else { return }
                                                 let sink = Unmanaged<PieceSink>.fromOpaque(user).takeUnretainedValue()
                                                 sink.emit(bytes: bytes, length: len)
                                             },
                                             sinkPointer,
                                             e.baseAddress, e.count)
                        if e.baseAddress?.pointee != 0, let base = e.baseAddress {
                            error = String(cString: base)
                        }
                    }
                }

                continuation.yield(.done(GenerationStats(
                    stop: StopReason(rawValue: Int32(raw.stop.rawValue)) ?? .error,
                    promptTokens: raw.prompt_tokens,
                    reusedTokens: raw.reused_tokens,
                    generated: raw.generated,
                    prefillMs: raw.prefill_ms,
                    decodeMs: raw.decode_ms,
                    firstTokenMs: raw.first_token_ms,
                    error: error)))
                continuation.finish()
            }
        }
    }

    /// Holds the continuation for the C callback. A class, because the callback gets a raw pointer.
    private final class PieceSink {
        private let continuation: AsyncStream<GenerationEvent>.Continuation
        init(continuation: AsyncStream<GenerationEvent>.Continuation) { self.continuation = continuation }

        /// The core promises complete UTF-8 sequences and never a partial character, so this never
        /// has to buffer. If that promise were ever broken the decode below would drop the piece,
        /// which is why `utf8CompletePrefix` is parity-tested against the core's own rule.
        func emit(bytes: UnsafePointer<CChar>, length: Int) {
            let data = Data(bytes: UnsafeRawPointer(bytes), count: length)
            guard let text = String(data: data, encoding: .utf8) else { return }
            continuation.yield(.text(text))
        }
    }

    // MARK: - Process memory

    /// Resident and peak resident set size of this process, in kB; -1 where unavailable.
    /// NOTE for iOS: this is NOT the number jetsam charges. See `DeviceMemory.footprintBytes()`.
    public static func residentKB() -> (rss: Int64, peak: Int64) {
        var rss: Int64 = -1
        var peak: Int64 = -1
        arivu_memory_kb(&rss, &peak)
        return (rss, peak)
    }

    // MARK: - Plumbing

    private static let errorBufferSize = 512

    private static func withErrorBuffer(_ body: (UnsafeMutablePointer<CChar>?, Int) -> Bool,
                                        orThrow makeError: (String) -> ArivuEngineError) throws {
        var buf = [CChar](repeating: 0, count: errorBufferSize)
        let ok = buf.withUnsafeMutableBufferPointer { body($0.baseAddress, $0.count) }
        if !ok {
            let message = buf.withUnsafeBufferPointer { p -> String in
                guard let base = p.baseAddress, base.pointee != 0 else { return "unknown error" }
                return String(cString: base)
            }
            throw makeError(message)
        }
    }

    private func run<T: Sendable>(_ body: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: body()) }
        }
    }

    private func runThrowing(_ body: @escaping @Sendable () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try body()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
