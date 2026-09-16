// The device tier as a config object, not a code fork (MULTIPLATFORM.md appendix; spine: C11).
//
// "What the app can do is chosen by what the device can carry, never by which platform it is." An
// 8 GB Android phone and an 8 GB iPhone get the same profile. Nothing here branches on the OS; the
// platform layer only *measures* the device and hands the numbers in.
//
// The core now exposes the same idea in C (`arivu_profile`, `arivu_profile_fits`). This Swift copy
// exists so the arithmetic is testable with no native library present, and `CoreParity.swift` in
// ArivuEngine checks the two against each other whenever a real core is linked. Two implementations
// that are never compared are two implementations that have already drifted.

import Foundation

public struct Capabilities: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }

    /// The shipped product: one screen, the user's own text.
    public static let chat = Capabilities(rawValue: 1 << 0)
    /// Reserved; SPINE R2 refuses tool calling in iteration-1.
    public static let tools = Capabilities(rawValue: 1 << 1)
    /// Reserved; needs a context a 4 GB phone cannot hold.
    public static let longform = Capabilities(rawValue: 1 << 2)
}

public struct Profile: Equatable, Sendable {
    public var id: String
    public var modelID: String
    public var modelBytes: UInt64

    public var nCtx: Int32
    public var nBatch: Int32
    public var nThreads: Int32
    public var kvQ8_0: Bool
    public var repack: Bool

    public var replyReserveTokens: Int32
    public var maxReplyTokens: Int32

    public var kvBytesPerToken: UInt64
    public var computeBufferBytes: UInt64
    public var runtimeOverheadBytes: UInt64

    public var minTotalRamBytes: UInt64
    public var minFreeStorageBytes: UInt64

    public var capabilities: Capabilities

    public init(id: String, modelID: String, modelBytes: UInt64,
                nCtx: Int32, nBatch: Int32, nThreads: Int32, kvQ8_0: Bool, repack: Bool,
                replyReserveTokens: Int32, maxReplyTokens: Int32,
                kvBytesPerToken: UInt64, computeBufferBytes: UInt64, runtimeOverheadBytes: UInt64,
                minTotalRamBytes: UInt64, minFreeStorageBytes: UInt64,
                capabilities: Capabilities) {
        self.id = id
        self.modelID = modelID
        self.modelBytes = modelBytes
        self.nCtx = nCtx
        self.nBatch = nBatch
        self.nThreads = nThreads
        self.kvQ8_0 = kvQ8_0
        self.repack = repack
        self.replyReserveTokens = replyReserveTokens
        self.maxReplyTokens = maxReplyTokens
        self.kvBytesPerToken = kvBytesPerToken
        self.computeBufferBytes = computeBufferBytes
        self.runtimeOverheadBytes = runtimeOverheadBytes
        self.minTotalRamBytes = minTotalRamBytes
        self.minFreeStorageBytes = minFreeStorageBytes
        self.capabilities = capabilities
    }

    /// The profile Arivu ships today. Every number is a decision already made (C8) or a measurement
    /// (leaves/NOTES.md): KV ≈ 56 KiB/token at q8_0 for Qwen3-0.6B, compute buffer 28.09 MiB measured
    /// on the emulator with `n_outputs_max = 1` (D-028), runtime overhead the app + framework baseline.
    public static let compact = Profile(
        id: "compact",
        modelID: "qwen3-0.6b-q4km",
        modelBytes: 396_000_000,
        nCtx: Policy.nCtx,
        nBatch: Policy.nBatch,
        nThreads: 4,
        kvQ8_0: Policy.kvQ8_0,
        repack: Policy.repackWeights,
        replyReserveTokens: Policy.replyReserveTokens,
        maxReplyTokens: Policy.maxReplyTokens,
        kvBytesPerToken: 57_344,
        computeBufferBytes: 29_452_206,
        runtimeOverheadBytes: 150_000_000,
        minTotalRamBytes: Policy.minTotalRamBytes,
        minFreeStorageBytes: Policy.minFreeStorageBytes,
        capabilities: [.chat]
    )

    /// model + KV + compute + runtime. The number M3 is measured against (≤ 800 MB).
    public var estimatedPeakBytes: UInt64 {
        modelBytes + kvBytesPerToken * UInt64(max(nCtx, 0)) + computeBufferBytes + runtimeOverheadBytes
    }

    public func has(_ capability: Capabilities) -> Bool { capabilities.contains(capability) }

    /// Internally consistent? The same checks `arivu_profile_valid` makes.
    public var validationError: String? {
        if nCtx <= 0 { return "n_ctx must be positive" }
        if nBatch <= 0 || nBatch > nCtx { return "n_batch must be in (0, n_ctx]" }
        if nThreads <= 0 { return "n_threads must be positive" }
        if replyReserveTokens <= 0 || replyReserveTokens >= nCtx { return "reply_reserve must be in (0, n_ctx)" }
        if maxReplyTokens <= 0 { return "max_reply_tokens must be positive" }
        if capabilities.isEmpty { return "a profile with no capability can do nothing" }
        if capabilities.contains(.longform) && nCtx < 8192 { return "longform needs n_ctx >= 8192" }
        return nil
    }

    /// Reply length for one send: never more than the profile allows, never more than the context
    /// has left. The overrun is reported, never silent (C7).
    public func replyBudget(promptTokens: Int32) -> Int32 {
        max(min(maxReplyTokens, nCtx - promptTokens), 0)
    }
}

public enum ProfileFit: Equatable, Sendable {
    case ok
    case invalidProfile(String)
    case noArm64
    case lowRamDevice
    case totalRam(actual: UInt64, required: UInt64)
    case availableMemory(actual: UInt64, required: UInt64)
    case storage(actual: UInt64, required: UInt64)
}

public extension Profile {
    /// "Can this device run this profile", answered from measured numbers only.
    /// `availableMemoryBytes == 0` means "not measured" and is not a failure — on Android there is
    /// no equivalent reading, and on iOS a transient value must never condemn a device (design.md §5.4).
    func fits(_ device: DeviceFacts, availableMemoryBytes: UInt64 = 0) -> ProfileFit {
        if let problem = validationError { return .invalidProfile(problem) }
        if !device.arm64 { return .noArm64 }
        if device.lowRamFlagged { return .lowRamDevice }
        if device.totalRamBytes < minTotalRamBytes {
            return .totalRam(actual: device.totalRamBytes, required: minTotalRamBytes)
        }
        if availableMemoryBytes > 0 && availableMemoryBytes < estimatedPeakBytes {
            return .availableMemory(actual: availableMemoryBytes, required: estimatedPeakBytes)
        }
        if device.freeStorageBytes < minFreeStorageBytes {
            return .storage(actual: device.freeStorageBytes, required: minFreeStorageBytes)
        }
        return .ok
    }

    /// The first profile in `candidates` that fits, richest first; `nil` if none does.
    /// The candidate list is a product decision; this is only the arithmetic (C11).
    static func select(from candidates: [Profile], for device: DeviceFacts,
                       availableMemoryBytes: UInt64 = 0) -> Int? {
        candidates.firstIndex { $0.fits(device, availableMemoryBytes: availableMemoryBytes) == .ok }
    }
}
