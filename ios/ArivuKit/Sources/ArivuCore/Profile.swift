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

    /// The profile Arivu ships today.
    ///
    /// Every number here is `arivu_default_profile()` in core/src/profile.cpp, to the byte. The core
    /// is the authority: it is the copy both platforms link, and `ProfileParityTest` fails the build
    /// if these drift again. They had drifted — see the note on `kvBytesPerToken`.
    public static let compact = Profile(
        id: "compact",
        modelID: "qwen3-1.7b-q4km",
        // tools/fetch_model.sh, sha256-pinned. Not rounded: the parity test compares literals.
        modelBytes: 1_107_409_472,
        nCtx: Policy.nCtx,
        nBatch: Policy.nBatch,
        nThreads: 4,
        kvQ8_0: Policy.kvQ8_0,
        repack: Policy.repackWeights,
        replyReserveTokens: Policy.replyReserveTokens,
        maxReplyTokens: Policy.maxReplyTokens,
        // 28 layers x 8 KV heads x (128 key + 128 value) at q8_0's 1.0625 B/value = 60928 B/token.
        // UNCHANGED by the 1.7B swap: 1.7B has the same depth and head shape and is merely wider,
        // and width does not enter the KV cache. That is what makes the bigger model affordable.
        kvBytesPerToken: 60_928,
        // Measured via arivu_compute_buffer_kib: 51292 KiB for 1.7B against 28764 KiB for 0.6B.
        // The one part of the footprint the bigger model genuinely costs — it nearly doubles.
        computeBufferBytes: 52_523_008,
        // 160 MiB, provisional: ART/Compose/allocator remainder from the emulator dry run. The W02
        // test-phone numbers replace it, in core/src/profile.cpp first.
        runtimeOverheadBytes: 167_772_160,
        minTotalRamBytes: Policy.minTotalRamBytes,
        minFreeStorageBytes: Policy.minFreeStorageBytes,
        capabilities: [.chat]
    )

    /// Clean, file-backed, evictable: the mmap'd weights. Counts against physical RAM and against
    /// the page cache, but `phys_footprint` — the number jetsam charges — excludes clean file-backed
    /// pages, so this half is very nearly free against that ceiling (architecture B23).
    public var mappedBytes: UInt64 { modelBytes }

    /// Dirty and anonymous: KV cache, compute buffer, runtime overhead, and a repacked copy of the
    /// weights if the profile asks for one. **This is what gets the app killed.**
    ///
    /// Mirrors `arivu_profile_footprint_bytes`. Repacking *adds* the copy rather than moving it,
    /// because the file mapping stays — which is the whole reason D-015 leaves repacking off.
    public var footprintBytes: UInt64 {
        let kv = kvBytesPerToken * UInt64(max(nCtx, 0))
        let repacked = repack ? modelBytes : 0
        return repacked + kv + computeBufferBytes + runtimeOverheadBytes
    }

    /// mapped + footprint: the worst case where nothing has been evicted. The number M3 is measured
    /// against (≤ 800 MB). Mirrors `arivu_profile_estimated_peak_bytes`.
    public var estimatedPeakBytes: UInt64 { mappedBytes + footprintBytes }

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

/// How good the available-memory number is. Raw values match `arivu_memory_source`.
///
/// The two platforms are not equally able to answer "how much may this process use before it is
/// killed", and the asymmetry must be visible rather than hidden behind a zero: a platform that does
/// not know says so, and the arithmetic then declines to invent a ceiling (architecture B23).
public enum MemorySource: Int32, Sendable, CaseIterable {
    /// The platform declined to answer; only the RAM floor applies. Android always reports this.
    case unmeasured = 0
    /// Derived from total RAM or a device class, not asked of the OS.
    case inferred = 1
    /// The OS was asked directly (`os_proc_available_memory()`).
    case probed = 2

    /// Headroom required over the estimated footprint, in parts per thousand.
    ///
    /// A probed number needs *more* headroom, not less: `os_proc_available_memory()` is an
    /// instantaneous reading taken at the calmest moment in the app's life, and it shrinks under
    /// system pressure. An inferred number is already a conservative derivation. Mirrors
    /// `arivu_headroom_permille`.
    public var headroomPermille: UInt32 {
        switch self {
        case .probed: return 1400
        case .inferred: return 1250
        case .unmeasured: return 0
        }
    }
}

public extension Profile {
    /// The room this profile needs before it will be attempted, given how the ceiling was measured.
    ///
    /// The ceiling applies to the **charged footprint plus headroom, never to the peak**: charging a
    /// device for clean file-backed pages it can evict and re-read would refuse phones that would
    /// have run the profile perfectly well (architecture B23).
    ///
    /// The arithmetic is `footprint/1000*permille + footprint%1000*permille/1000` rather than the
    /// obvious multiply — integer, in that order, to match `arivu_profile_fits` bit for bit and to
    /// keep a large footprint from overflowing on the way through.
    /// - Parameter observedFootprintBytes: the largest charged footprint this profile has ever
    ///   actually cost on this device, or 0 if it has never run here.
    ///
    /// Mirrors `arivu_profile_required_available_bytes`. When the device has run this profile, what
    /// it cost replaces what was predicted — in both directions. `runtimeOverheadBytes` is one
    /// provisional number standing in for every phone that will ever run this, so shipping it
    /// static to thousands of device models guarantees being wrong twice: refusing phones that
    /// would have worked, and admitting phones that then get killed.
    func requiredAvailableBytes(_ source: MemorySource,
                                observedFootprintBytes: UInt64 = 0) -> UInt64 {
        let permille = UInt64(source.headroomPermille)
        guard permille != 0 else { return 0 }
        // Measurement beats prediction. The headroom still applies on top, so adapting the
        // magnitude never removes the margin.
        let basis = observedFootprintBytes != 0 ? observedFootprintBytes : footprintBytes
        return basis / 1000 * permille + basis % 1000 * permille / 1000
    }

    /// "Can this device run this profile", answered from measured numbers only.
    ///
    /// A `memorySource` of `.unmeasured` — or an `availableMemoryBytes` of 0 — skips the ceiling
    /// check entirely rather than guessing one: on Android there is no equivalent reading, and on
    /// iOS a transient value must never condemn a device (design.md §5.4). The checks run in the
    /// order leaves/BRIEF.md lists them and the first failure wins, so the user is told which one.
    ///
    /// Mirrors `arivu_profile_fits`; `CoreParityTests.fitMatchesCore` runs both over the same inputs.
    func fits(_ device: DeviceFacts,
              availableMemoryBytes: UInt64 = 0,
              memorySource: MemorySource = .unmeasured,
              observedFootprintBytes: UInt64 = 0) -> ProfileFit {
        if let problem = validationError { return .invalidProfile(problem) }
        if !device.arm64 { return .noArm64 }
        if device.lowRamFlagged { return .lowRamDevice }
        // Zero is "not measured", not "measured as none" — `arivu_profile_fits` guards both of
        // these with `!= 0` and this copy did not, which is how a Simulator that would not report
        // its free space got told it had 0 B and was refused.
        if device.totalRamBytes != 0 && device.totalRamBytes < minTotalRamBytes {
            return .totalRam(actual: device.totalRamBytes, required: minTotalRamBytes)
        }
        let required = requiredAvailableBytes(memorySource, observedFootprintBytes: observedFootprintBytes)
        if required > 0 && availableMemoryBytes > 0 && availableMemoryBytes < required {
            return .availableMemory(actual: availableMemoryBytes, required: required)
        }
        if device.freeStorageBytes != 0 && device.freeStorageBytes < minFreeStorageBytes {
            return .storage(actual: device.freeStorageBytes, required: minFreeStorageBytes)
        }
        return .ok
    }

    /// The first profile in `candidates` that fits, richest first; `nil` if none does.
    /// The candidate list is a product decision; this is only the arithmetic (C11).
    static func select(from candidates: [Profile], for device: DeviceFacts,
                       availableMemoryBytes: UInt64 = 0,
                       memorySource: MemorySource = .unmeasured) -> Int? {
        candidates.firstIndex {
            $0.fits(device, availableMemoryBytes: availableMemoryBytes, memorySource: memorySource) == .ok
        }
    }
}

/// What this profile has actually cost on this device.
///
/// The one thing Arivu learns about the phone it is on. Not a preference and not settable by the
/// user, so C8 still holds — the same footing as `GatePassStore` ("this phone already passed") and
/// `LoadedBeforeFlag` ("a model has been mapped here before").
///
/// Kept as a **maximum**, never a last-value: a generation that happened to run cheaply must not
/// relax the bar for every generation after it. Keyed by profile id, because a different profile
/// has a different footprint and its measurement says nothing about this one.
///
/// Why one observation is enough: llama.cpp allocates the whole KV cache for `n_ctx` when the
/// context is created, so the footprint once a context exists is already the steady-state peak. It
/// does not grow as the conversation does.
public final class MemoryCalibrationStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let prefix = "io.github.brettleehari.arivu.calibration.footprint."

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public static let standard = MemoryCalibrationStore()

    /// The largest footprint recorded for `profileID`, or 0 if this profile has never run here.
    public func observedFootprintBytes(for profileID: String) -> UInt64 {
        let stored = defaults.object(forKey: prefix + profileID) as? NSNumber
        return stored?.uint64Value ?? 0
    }

    /// Records a footprint, keeping the larger of it and whatever was already known.
    /// Ignores 0, which means "the platform would not say" rather than "it cost nothing".
    public func record(_ bytes: UInt64, for profileID: String) {
        guard bytes > 0, bytes > observedFootprintBytes(for: profileID) else { return }
        defaults.set(NSNumber(value: bytes), forKey: prefix + profileID)
    }

    public func forget(_ profileID: String) { defaults.removeObject(forKey: prefix + profileID) }
}
