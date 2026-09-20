// Owns the engine and enforces the lifecycle rules.
//
// This is NOT a mechanical port of Android's InferenceController, and the reason is jetsam.
// Android's low-memory killer gives `onTrimMemory` first, so the Android controller can wait to be
// told. **Jetsam gives no callback before it kills you.** So on iOS the rules are proactive, in this
// order of importance:
//
//   1. The context is freed after ~30 s idle and *immediately* when the UI is hidden. Nothing waits
//      for a warning.
//   2. The model is created lazily on the first message, never at app start, so an app that is
//      opened and closed costs nothing.
//   3. `didReceiveMemoryWarning` is handled, but only as a bonus: it is a courtesy the system may
//      never extend. Anything that depends on it would be a bug that only shows up on a full phone.
//   4. The weights stay mmap'd and clean. `phys_footprint` — the number jetsam charges — barely
//      counts them, which is the whole reason the budget fits (see DeviceMemory.swift).
//
// Cancellation is the other half of this file. `CancelBox` is nonisolated on purpose: Stop must work
// *during* the model load, when the actor is busy and the native cancel flag has not been created
// yet. Ignoring Stop during a cold start was a real bug on Android (leaves/NOTES.md, bug 2) and the
// first run is exactly when someone wants to back out (leaves/design.md §14, request 3).
//
// spine: C2, C6, C10

import ArivuCore
import ArivuEngine
import Foundation
import os

public enum EngineState: Sendable, Equatable {
    case cold        // no model
    case starting    // loading the model, or creating the context
    case ready       // model loaded, idle
    case generating
}

/// Carries a Stop request across the boundary between "the app decided" and "the engine noticed".
/// Every way a generation can be stopped goes through here, so the partial reply is always saved by
/// the same path and labelled by *why* it stopped (leaves/design.md §5.1).
public final class CancelBox: @unchecked Sendable {
    private let lock = NSLock()
    private var engine: ArivuEngine?
    private var requestedCause: CancelCause?

    public init() {}

    /// True from the moment the app asks until the next generation begins.
    public var isRequested: Bool {
        lock.lock(); defer { lock.unlock() }
        return requestedCause != nil
    }

    public var cause: CancelCause? {
        lock.lock(); defer { lock.unlock() }
        return requestedCause
    }

    /// Safe from any thread and at any moment, including while the model is still being mapped.
    public func request(_ cause: CancelCause) {
        lock.lock()
        requestedCause = cause
        let engine = self.engine
        lock.unlock()
        engine?.cancel()
    }

    func attach(_ engine: ArivuEngine?) {
        lock.lock(); defer { lock.unlock() }
        self.engine = engine
    }

    /// Cleared when a generation starts, mirroring the engine's own flag.
    func beginGeneration() {
        lock.lock(); defer { lock.unlock() }
        requestedCause = nil
    }
}

/// "Has a model ever been mapped on this device?" — the one bit that decides
/// `state_starting_first_run` (leaves/design.md §5.2). Not a user preference and not settable by the
/// user, so C8 still holds. Wrapped because `UserDefaults` is not `Sendable`.
public final class LoadedBeforeFlag: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "io.github.brettleehari.arivu.model.everLoaded"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public var value: Bool { defaults.bool(forKey: key) }
    public func set() { defaults.set(true, forKey: key) }
    public func reset() { defaults.removeObject(forKey: key) }
}

public actor InferenceController {
    public nonisolated let profile: Profile
    public nonisolated let cancelBox = CancelBox()
    public nonisolated let states: AsyncStream<EngineState>

    private let modelSource: ModelSource
    private let calibration: MemoryCalibrationStore
    /// Nonisolated: the UI asks `hasLoadedBefore` while deciding which Starting line to show, and
    /// must not have to wait behind a model load to find out.
    private nonisolated let loadedBefore: LoadedBeforeFlag
    private let log = Logger(subsystem: "io.github.brettleehari.arivu", category: "lifecycle")
    private let stateContinuation: AsyncStream<EngineState>.Continuation

    private var engine: ArivuEngine?
    private var idleTask: Task<Void, Never>?
    private var uiVisible = true
    private var state: EngineState = .cold

    public init(modelSource: ModelSource,
                profile: Profile = .compact,
                loadedBefore: LoadedBeforeFlag = LoadedBeforeFlag(),
                calibration: MemoryCalibrationStore = .standard) {
        self.modelSource = modelSource
        self.calibration = calibration
        self.profile = profile
        self.loadedBefore = loadedBefore
        let (stream, continuation) = AsyncStream<EngineState>.makeStream(bufferingPolicy: .bufferingNewest(8))
        self.states = stream
        self.stateContinuation = continuation
        continuation.yield(.cold)
    }

    deinit {
        // Ends any `for await` on `states`, so a watcher task cannot outlive the controller.
        stateContinuation.finish()
    }

    /// Has a model ever been mapped on this device? Decides `state_starting_first_run`
    /// (leaves/design.md §5.2). Nonisolated so the UI can ask before the actor is busy.
    public nonisolated var hasLoadedBefore: Bool { loadedBefore.value }

    public var currentState: EngineState { state }

    /// The token counter the prompt builder uses. Building a prompt is what forces the model to
    /// load, which is why "Starting Arivu…" has to be on screen before this is called.
    public nonisolated func makePromptBuilder(systemPrompt: String = Policy.systemPrompt) -> PromptBuilder {
        PromptBuilder(systemPrompt: systemPrompt,
                      nCtx: profile.nCtx,
                      replyReserve: profile.replyReserveTokens) { [weak self] text in
            guard let self else { return 0 }
            return try await self.countTokens(text)
        }
    }

    /// The loaded model's own description of itself, or nil if nothing is loaded. Never loads:
    /// mapping 378 MB to fill a page would break the lifecycle rule this file exists to enforce.
    public func modelInfo() async -> ModelInfo? {
        guard let engine, await engine.hasModel() else { return nil }
        return await engine.modelInfo()
    }

    public func countTokens(_ text: String) async throws -> Int32 {
        let engine = try await ensureModel()
        return try await engine.countTokens(text)
    }

    public nonisolated func maxReplyTokens(promptTokens: Int32) -> Int32 {
        profile.replyBudget(promptTokens: promptTokens)
    }

    /// Emits text pieces and one `.done`, then finishes. Throws only for failures that happen
    /// *before* generation — a model or context that would not load — because those are a notice
    /// bar, not a stop label (leaves/design.md §7).
    public nonisolated func generate(prompt: String, maxNewTokens: Int32) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            let work = Task {
                do {
                    let engine = try await self.prepareForGeneration()

                    // Stop pressed while the model loaded or the context was created: the native
                    // cancel flag is reset when a generation starts, so honour the request here.
                    if self.cancelBox.isRequested {
                        continuation.yield(.done(GenerationStats(stop: .cancelled)))
                        continuation.finish()
                        await self.finishGeneration()
                        return
                    }

                    self.cancelBox.beginGeneration()
                    for await event in engine.generate(prompt: prompt,
                                                       maxNewTokens: maxNewTokens,
                                                       sampling: .shipped()) {
                        // Closes the microsecond window between the check above and the native start.
                        if self.cancelBox.isRequested { engine.cancel() }
                        if case .done(let stats) = event {
                            await self.logDone(stats)
                            if stats.generated > 0 { await self.recordFootprint() }
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                await self.finishGeneration()
            }
            continuation.onTermination = { _ in work.cancel() }
        }
    }

    // MARK: - Lifecycle events from the app

    public func onUIVisible() {
        uiVisible = true
    }

    /// The app is going to the background. The context goes NOW unless a reply is still being
    /// written — jetsam will not ask first, and a suspended app holding a KV cache is the single
    /// most likely thing on this phone to be killed.
    public func onUIHidden() {
        uiVisible = false
        if state != .generating { freeContext(reason: "ui hidden") }
    }

    /// `didReceiveMemoryWarning`. A courtesy, not a contract: everything above already assumes it
    /// never arrives. While generating, the caller has already asked for a cancel with
    /// `.memoryPressure`, and the context is freed when that generation unwinds.
    public func onMemoryWarning() {
        log.notice("memory warning; \(DeviceMemory.summary(), privacy: .public)")
        if state != .generating { freeContext(reason: "memory warning") }
    }

    /// The whole engine goes, weights included. Only worth doing when the app is hidden and the
    /// system is clearly short — reloading is a page-cache hit when it is not.
    public func freeEverything(reason: String) {
        idleTask?.cancel()
        let engine = self.engine
        self.engine = nil
        cancelBox.attach(nil)
        setState(.cold)
        log.notice("engine released: \(reason, privacy: .public)")
        _ = engine  // released here; its deinit frees the handle
    }

    // MARK: - Internals

    private func prepareForGeneration() async throws -> ArivuEngine {
        idleTask?.cancel()
        let engine = try await ensureModel()

        // Ask before allocating, where the platform can say. A context that cannot be created is a
        // different screen from one that failed for any other reason (leaves/design.md §7).
        if DeviceMemory.hasRoomForContext(for: profile, calibration: calibration) == false {
            throw ArivuEngineError.contextCreateFailed("not enough memory available for a context")
        }
        try await engine.ensureContext(ContextParameters(profile: profile,
                                                         threads: DeviceMemory.performanceCoreCount()))
        setState(.generating)
        return engine
    }

    private func ensureModel() async throws -> ArivuEngine {
        if let engine, await engine.hasModel() { return engine }
        setState(.starting)
        let engine = try self.engine ?? ArivuEngine()
        self.engine = engine
        cancelBox.attach(engine)

        let file = try modelSource.open()
        defer { file.close() }
        // fd + offset + length, always. iOS passes offset 0 and the whole file; Android passes a
        // window inside the APK. One path in the core (MULTIPLATFORM.md).
        try await engine.loadModel(file.window, repack: profile.repack)

        loadedBefore.set()
        setState(.ready)
        return engine
    }

    private func finishGeneration() {
        setState(engine == nil ? .cold : .ready)
        if uiVisible {
            scheduleIdleFree()
        } else {
            freeContext(reason: "generation finished while hidden")
        }
    }

    private func scheduleIdleFree() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(Policy.contextIdleSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self.freeContextAfterIdle()
        }
    }

    private func freeContextAfterIdle() {
        freeContext(reason: "idle \(Int(Policy.contextIdleSeconds))s")
    }

    private func freeContext(reason: String) {
        guard state != .generating, let engine else { return }
        Task { [log] in
            guard await engine.hasContext() else { return }
            await engine.freeContext()
            log.notice("context freed: \(reason, privacy: .public); \(DeviceMemory.summary(), privacy: .public)")
        }
    }

    /// Record what this reply actually cost, so the next memory check is answered from this phone
    /// rather than from an estimate made on a different one.
    ///
    /// Taken after a generation that produced something, because a run that failed says nothing
    /// about the steady-state cost. The store keeps the maximum, so this only ever tightens.
    private func recordFootprint() {
        guard let footprint = DeviceMemory.footprintBytes() else { return }
        calibration.record(footprint, for: profile.id)
    }

    private func logDone(_ stats: GenerationStats) {
        // One line per reply: the on-device evidence for M1/M2. No text content is logged. spine: C2
        log.notice("\(stats.summary(threads: DeviceMemory.performanceCoreCount()), privacy: .public); \(DeviceMemory.summary(), privacy: .public)")
    }

    private func setState(_ new: EngineState) {
        guard new != state else { return }
        state = new
        stateContinuation.yield(new)
    }
}
