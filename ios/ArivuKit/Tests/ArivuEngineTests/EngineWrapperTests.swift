// The wrapper, exercised against the fake core in CArivuStub.
//
// What this proves: the handle is freed on every path, `cancel` works from another thread while a
// generation is running, the stream ends with exactly one `.done`, stop reasons arrive intact, and a
// failure that is really "the phone is full" is distinguishable from one that is not.
//
// What this does NOT prove: anything about llama.cpp. Tokenisation, sampling, prefix reuse and
// memory are verified by tools/host/run_smoke.sh on the C++ side and on a device.
//
// spine: C2, C10

import CArivuStub
import Foundation
import Testing
@testable import ArivuCore
@testable import ArivuEngine

private func temporaryModelFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("arivu-model-\(UUID().uuidString).gguf")
    try Data(repeating: 0x42, count: 4096).write(to: url)
    return url
}

@Suite(.serialized)
struct EngineWrapperTests {
    init() { arivu_stub_reset() }

    /// Counted as a delta, not an absolute: other suites in the same process may hold engines of
    /// their own. What must be true is that this scope gives back exactly what it took.
    @Test("the handle is freed when the engine goes, on every path")
    func handleCannotLeak() async throws {
        let baseline = arivu_stub_live_engines()
        do {
            let engine = try ArivuEngine()
            #expect(arivu_stub_live_engines() == baseline + 1)
            _ = await engine.hasModel()
        }
        // The engine is gone; its Handle's deinit ran.
        #expect(arivu_stub_live_engines() == baseline)

        // A throwing load must not keep the handle alive either.
        arivu_stub_fail_next_load("stub: refused")
        do {
            let engine = try ArivuEngine()
            let file = try temporaryModelFile()
            defer { try? FileManager.default.removeItem(at: file) }
            let open = try FileModelSource(url: file).open()
            defer { open.close() }
            await #expect(throws: (any Error).self) { try await engine.loadModel(open.window) }
        }
        #expect(arivu_stub_live_engines() == baseline)
    }

    @Test("a model is loaded as fd + offset 0 + whole length")
    func loadsFromFileDescriptor() async throws {
        let file = try temporaryModelFile()
        defer { try? FileManager.default.removeItem(at: file) }
        let open = try FileModelSource(url: file).open()
        defer { open.close() }

        #expect(open.window.offset == 0)
        #expect(open.window.length == 4096)
        #expect(open.window.fileDescriptor >= 0)

        let engine = try ArivuEngine()
        try await engine.loadModel(open.window)
        #expect(await engine.hasModel())
    }

    @Test("a context is created lazily and can be freed without losing the model")
    func contextLifetime() async throws {
        let engine = try await loadedEngine()
        #expect(await engine.hasContext() == false)
        try await engine.ensureContext(ContextParameters(profile: .compact))
        #expect(await engine.hasContext())
        #expect(await engine.contextSize() == Policy.nCtx)

        await engine.freeContext()
        #expect(await engine.hasContext() == false)
        #expect(await engine.hasModel(), "freeing the context must not drop the weights")

        await engine.freeModel()
        #expect(await engine.hasModel() == false)
    }

    @Test("generation streams text and ends with exactly one done")
    func streamsThenDone() async throws {
        arivu_stub_set_script("one two three")
        let engine = try await readyEngine()

        var text = ""
        var dones: [GenerationStats] = []
        for await event in engine.generate(prompt: "p", maxNewTokens: 100, sampling: .shipped(seed: 1)) {
            switch event {
            case .text(let piece): text += piece
            case .done(let stats): dones.append(stats)
            }
        }
        #expect(text == "one two three")
        #expect(dones.count == 1)
        #expect(dones.first?.stop == .endOfTurn)
        #expect(dones.first?.generated == 3)
    }

    @Test("cancel from another thread stops the stream and reports CANCELLED")
    func cancelMidStream() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 500))
        arivu_stub_set_piece_delay_us(200)
        let engine = try await readyEngine()

        var pieces = 0
        var stop: StopReason?
        for await event in engine.generate(prompt: "p", maxNewTokens: 10_000, sampling: .shipped(seed: 1)) {
            switch event {
            case .text:
                pieces += 1
                if pieces == 5 {
                    // From the caller's thread, while the engine's own queue is busy generating.
                    engine.cancel()
                }
            case .done(let stats):
                stop = stats.stop
            }
        }
        #expect(stop == .cancelled)
        #expect(pieces < 500, "cancel did not take effect")
    }

    @Test("breaking out of the loop cancels rather than leaving a generation running")
    func terminationCancels() async throws {
        arivu_stub_set_script(String(repeating: "word ", count: 500))
        arivu_stub_set_piece_delay_us(200)
        let engine = try await readyEngine()

        let stream = engine.generate(prompt: "p", maxNewTokens: 10_000, sampling: .shipped(seed: 1))
        var seen = 0
        for await _ in stream {
            seen += 1
            if seen == 3 { break }
        }
        // The stream's termination handler cancelled; a following generation starts clean.
        arivu_stub_set_piece_delay_us(0)
        arivu_stub_set_script("done now")
        var text = ""
        for await event in engine.generate(prompt: "p", maxNewTokens: 100, sampling: .shipped(seed: 1)) {
            if case .text(let piece) = event { text += piece }
        }
        #expect(text == "done now")
    }

    @Test("the reply limit and a full context arrive as themselves")
    func stopReasons() async throws {
        arivu_stub_set_script("a b c d e f")
        let engine = try await readyEngine()

        var stop: StopReason?
        for await event in engine.generate(prompt: "p", maxNewTokens: 2, sampling: .shipped(seed: 1)) {
            if case .done(let stats) = event { stop = stats.stop }
        }
        #expect(stop == .maxTokens)

        arivu_stub_next_stop_context_full()
        for await event in engine.generate(prompt: "p", maxNewTokens: 100, sampling: .shipped(seed: 1)) {
            if case .done(let stats) = event { stop = stats.stop }
        }
        #expect(stop == .contextFull)
    }

    @Test("token counting fails loudly rather than returning a wrong number")
    func tokenCounting() async throws {
        let engine = try ArivuEngine()
        await #expect(throws: ArivuEngineError.self) { _ = try await engine.countTokens("hello") }

        let ready = try await loadedEngine()
        #expect(try await ready.countTokens("hello") == 5)
        #expect(try await ready.countTokens("") == 0)
    }

    /// leaves/design.md §7: a memory failure gets its own screen, not the generic one.
    @Test("a load failure says whether it was memory")
    func memoryFailuresAreDistinguishable() async throws {
        let file = try temporaryModelFile()
        defer { try? FileManager.default.removeItem(at: file) }

        arivu_stub_fail_next_load("failed to allocate buffer: Cannot allocate memory")
        let engine = try ArivuEngine()
        let open = try FileModelSource(url: file).open()
        defer { open.close() }
        do {
            try await engine.loadModel(open.window)
            Issue.record("expected the load to fail")
        } catch let error as ArivuEngineError {
            #expect(error.isMemoryFailure)
        }

        arivu_stub_fail_next_load("gguf: unknown magic")
        do {
            try await engine.loadModel(open.window)
            Issue.record("expected the load to fail")
        } catch let error as ArivuEngineError {
            #expect(!error.isMemoryFailure)
        }
    }

    @Test("a model that is not in the bundle is a named error, not a crash")
    func missingModel() {
        #expect(throws: ModelSourceError.self) {
            _ = try BundleModelSource(bundle: Bundle(for: DummyForBundle.self)).open()
        }
    }

    // MARK: - helpers

    private func loadedEngine() async throws -> ArivuEngine {
        let engine = try ArivuEngine()
        let file = try temporaryModelFile()
        let open = try FileModelSource(url: file).open()
        try await engine.loadModel(open.window)
        open.close()
        try? FileManager.default.removeItem(at: file)
        return engine
    }

    private func readyEngine() async throws -> ArivuEngine {
        let engine = try await loadedEngine()
        try await engine.ensureContext(ContextParameters(profile: .compact))
        return engine
    }
}

final class DummyForBundle {}

@Suite("Process memory")
struct DeviceMemoryTests {
    /// The number jetsam charges. macOS reports it too, which is why this can run here at all.
    @Test("the footprint is a real reading")
    func footprint() {
        let footprint = DeviceMemory.footprintBytes()
        #expect(footprint != nil)
        #expect((footprint ?? 0) > 0)
    }

    @Test("physical memory is a tier signal, and it is not zero")
    func physical() {
        #expect(DeviceMemory.physicalBytes() > 0)
    }

    /// Android has no equivalent of os_proc_available_memory() and macOS does not expose it, so
    /// "not measured" must be a first-class answer everywhere rather than a platform branch.
    @Test("an unmeasurable available-memory reading means go ahead and try")
    func availableMemoryIsOptional() {
        #if os(iOS)
        #expect(DeviceMemory.availableBytes() != nil)
        #expect(DeviceMemory.memorySource() == .probed)
        #else
        #expect(DeviceMemory.availableBytes() == nil)
        #expect(DeviceMemory.hasRoomForContext(for: .compact) == nil)
        // macOS cannot answer, and says so rather than reporting a number nothing measured.
        #expect(DeviceMemory.memorySource() == .unmeasured)
        #endif
    }

    @Test("the thread count stays in the band Android uses")
    func threads() {
        let threads = DeviceMemory.performanceCoreCount()
        #expect(threads >= Policy.minThreads)
        #expect(threads <= Policy.maxThreads)
    }

    @Test("the log line says when a number came from a simulator")
    func simulatorIsLabelled() {
        let summary = DeviceMemory.summary()
        #expect(summary.contains("footprint="))
        #expect(summary.contains("NOT REPRESENTATIVE") == DeviceMemory.isSimulator)
    }
}

@Suite("Parity with the core")
struct CoreParityTests {
    /// The one rule the app relies on without owning it: complete UTF-8 sequences only.
    @Test("the Swift UTF-8 rule agrees with the core's")
    func utf8Prefix() {
        let cases: [[UInt8]] = [
            [],
            Array("hello".utf8),
            Array("héllo".utf8),
            Array("नमस्ते".utf8),
            Array("🙂".utf8),
            Array("🙂".utf8).dropLast().map { $0 },       // a cut 4-byte sequence
            Array("é".utf8).dropLast().map { $0 },        // a cut 2-byte sequence
            Array("ते".utf8).dropLast().map { $0 },       // a cut 3-byte sequence
            [0x80],                                       // a stray continuation byte
            Array("ok ".utf8) + Array("🙂".utf8).dropLast(),
        ]
        for bytes in cases {
            #expect(utf8CompletePrefix(bytes) == CoreParity.utf8CompletePrefix(bytes),
                    "disagreement on \(bytes)")
        }
    }

    @Test("stop reason numbers agree with the C enum")
    func stopReasonNumbering() {
        let expected = ["end_of_turn", "cancelled", "context_full", "max_tokens", "error"]
        for (index, reason) in StopReason.allCases.enumerated() {
            #expect(CoreParity.stopReasonName(reason) == expected[index],
                    "\(reason) is not \(expected[index]) in the core")
        }
    }

    @Test("the assistant opening is the core's")
    func assistantOpen() {
        #expect(CoreParity.assistantOpen == PromptBuilder.assistantOpen)
    }

    /// Skipped against the fake core, which implements neither the profile arithmetic nor the
    /// prompt builder. The comparison itself lives in `CoreParity.disagreements()` so that this
    /// suite and the app's `CoreParityTests` — the bundle that actually links the real core, and so
    /// the only place these ever execute — cannot drift into two ideas of what parity means.
    ///
    /// Left in place rather than deleted because it is the suite that runs if ArivuKit is ever
    /// built against a real core directly, e.g. on a device.
    @Test("the Swift copies agree with the core", .enabled(if: CoreParity.isRealCore))
    func swiftAgreesWithCore() {
        let disagreements = CoreParity.disagreements()
        // A literal with interpolation, not a concatenation: #expect's second argument is a
        // `Comment`, which is ExpressibleByStringInterpolation but not the result of `+`.
        #expect(disagreements.isEmpty,
                "the Swift copies and /core disagree:\n  - \(disagreements.joined(separator: "\n  - "))")
    }

    /// `disagreements()` must not report agreement when it compared nothing. Against the stub it
    /// returns exactly one note saying so, and that is the behaviour the app's suite relies on.
    @Test("the comparison refuses to pass vacuously against a fake core")
    func vacuousPassIsImpossible() {
        guard !CoreParity.isRealCore else { return }
        let disagreements = CoreParity.disagreements()
        #expect(disagreements.count == 1)
        #expect(disagreements.first?.contains("fake core") == true)
    }
}
