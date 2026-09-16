// The guard against three implementations of the same rule drifting apart.
//
// `PromptBuilder`, `Profile.fits` and the stop-reason numbering exist in Kotlin, in Swift, and now
// in C inside the core (`arivu_prompt_builder_*`, `arivu_profile_fits`, `arivu_stop_reason`). Two
// implementations that are never compared have already drifted; this file is the comparison.
//
// It is a thin binding, nothing more. The Swift versions stay authoritative on iOS *today*, because
// they are the ones that can be tested with no native library on a machine with no Xcode. The moment
// a real core is linked — on a device, or on a Mac after tools/ios/build_core.sh — CoreParityTests
// runs the same inputs through both and fails if the answers differ. Proposed decision: once that
// check has run green on hardware, the core's builder becomes the one implementation and this Swift
// one becomes the reference used by tests (see leaves/engineering-ios.md).
//
// spine: C7, C11

import ArivuCore
import CArivuCore
import Foundation

public enum CoreParity {
    /// False when the fake core from CArivuStub is linked, so a parity test can skip rather than
    /// compare a real implementation against a deliberately empty one.
    public static var isRealCore: Bool { !ArivuEngine.coreVersion.hasPrefix("stub") }

    /// The core's own name for a stop reason. Used to check the Swift enum's raw values against the
    /// C enum rather than trusting that two lists were typed in the same order.
    public static func stopReasonName(_ reason: StopReason) -> String {
        String(cString: arivu_stop_reason_name(arivu_stop_reason(UInt32(reason.rawValue))))
    }

    /// The template opening, from the core. If Qwen's template ever changes, this is where the two
    /// copies stop agreeing.
    public static var assistantOpen: String { String(cString: arivu_assistant_open()) }

    /// The core's headroom table, so `MemorySource.headroomPermille` is checked against it rather
    /// than trusted to have been typed in the same order.
    public static func headroomPermille(_ source: MemorySource) -> UInt32 {
        arivu_headroom_permille(arivu_memory_source(UInt32(source.rawValue)))
    }

    /// The core's rule for how many bytes at the front of a buffer form complete UTF-8 sequences.
    /// A platform doing its own streaming buffer must use the same rule, so this is testable.
    public static func utf8CompletePrefix(_ bytes: [UInt8]) -> Int {
        bytes.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return 0 }
            return base.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                arivu_utf8_complete_prefix($0, buffer.count)
            }
        }
    }

    /// Every way the Swift copies and the core disagree, as sentences, newest-caller-friendly.
    /// Empty means they agree.
    ///
    /// This is the comparison itself, not a test, because it has to be callable from two places
    /// that cannot share a test target: `ArivuKit`'s own suite (where it skips, the fake core being
    /// linked) and the app's test bundle (where the real `ArivuCore.xcframework` is linked and it
    /// therefore actually runs). Writing it twice is how the two would drift.
    ///
    /// Returns a single "not a real core" note rather than a false pass when the stub is linked.
    public static func disagreements() -> [String] {
        guard isRealCore else { return ["the fake core is linked (\(ArivuEngine.coreVersion)); nothing was compared"] }
        var found: [String] = []

        // The template. If Qwen's template ever changes, this is where the copies stop agreeing.
        if assistantOpen != PromptBuilder.assistantOpen {
            found.append("assistant opening differs: core \(assistantOpen.debugDescription) vs Swift \(PromptBuilder.assistantOpen.debugDescription)")
        }

        // Stop reasons, by name, so the raw values are checked against the C enum rather than
        // trusted to have been typed in the same order.
        let names = ["end_of_turn", "cancelled", "context_full", "max_tokens", "error"]
        for (index, reason) in StopReason.allCases.enumerated() where stopReasonName(reason) != names[index] {
            found.append("stop reason \(reason) is \(stopReasonName(reason)) in the core, expected \(names[index])")
        }

        // The shipped profile, including the memory model — the four fields that decide whether the
        // app is killed and that no parity check used to cover.
        let core = defaultProfile()
        let swift = Profile.compact
        let fields: [(String, UInt64, UInt64)] = [
            ("modelBytes", core.modelBytes, swift.modelBytes),
            ("kvBytesPerToken", core.kvBytesPerToken, swift.kvBytesPerToken),
            ("computeBufferBytes", core.computeBufferBytes, swift.computeBufferBytes),
            ("runtimeOverheadBytes", core.runtimeOverheadBytes, swift.runtimeOverheadBytes),
            ("minTotalRamBytes", core.minTotalRamBytes, swift.minTotalRamBytes),
            ("minFreeStorageBytes", core.minFreeStorageBytes, swift.minFreeStorageBytes),
            ("mappedBytes", core.mappedBytes, swift.mappedBytes),
            ("footprintBytes", core.footprintBytes, swift.footprintBytes),
            ("estimatedPeakBytes", core.estimatedPeakBytes, swift.estimatedPeakBytes),
        ]
        for (name, c, s) in fields where c != s {
            found.append("profile.\(name): core \(c) vs Swift \(s)")
        }
        let ints: [(String, Int32, Int32)] = [
            ("nCtx", core.nCtx, swift.nCtx),
            ("nBatch", core.nBatch, swift.nBatch),
            ("replyReserveTokens", core.replyReserveTokens, swift.replyReserveTokens),
            ("maxReplyTokens", core.maxReplyTokens, swift.maxReplyTokens),
        ]
        for (name, c, s) in ints where c != s {
            found.append("profile.\(name): core \(c) vs Swift \(s)")
        }
        if core.capabilities != swift.capabilities {
            found.append("profile.capabilities: core \(core.capabilities.rawValue) vs Swift \(swift.capabilities.rawValue)")
        }

        // The headroom table.
        for source in MemorySource.allCases where source.headroomPermille != headroomPermille(source) {
            found.append("headroom for \(source): core \(headroomPermille(source)) vs Swift \(source.headroomPermille)")
        }

        // The fit verdict, over readings that straddle the ceiling crossed with every measurement
        // quality — because the headroom demanded, and therefore the verdict, depends on it.
        let devices = [
            DeviceFacts(arm64: true, lowRamFlagged: false, totalRamBytes: 8_000_000_000, freeStorageBytes: 8_000_000_000),
            DeviceFacts(arm64: true, lowRamFlagged: false, totalRamBytes: 2_000_000_000, freeStorageBytes: 8_000_000_000),
            DeviceFacts(arm64: true, lowRamFlagged: false, totalRamBytes: 8_000_000_000, freeStorageBytes: 1_000),
            DeviceFacts(arm64: false, lowRamFlagged: false, totalRamBytes: 8_000_000_000, freeStorageBytes: 8_000_000_000),
        ]
        let required = swift.requiredAvailableBytes(.probed)
        let readings: [UInt64] = [0, 1_000, required > 1 ? required - 1 : 1, required, required + 1, 2_000_000_000]
        for device in devices {
            for source in MemorySource.allCases {
                for available in readings {
                    let fromCore = fit(swift, on: device, availableMemoryBytes: available, memorySource: source)
                    let fromSwift = swift.fits(device, availableMemoryBytes: available, memorySource: source)
                    if fromCore != fromSwift {
                        found.append("fit disagreement: ram=\(device.totalRamBytes) storage=\(device.freeStorageBytes) arm64=\(device.arm64) available=\(available) source=\(source): core \(fromCore) vs Swift \(fromSwift)")
                    }
                }
            }
        }

        // The UTF-8 rule the app relies on without owning it.
        let utf8Cases: [[UInt8]] = [
            [], Array("hello".utf8), Array("héllo".utf8), Array("नमस्ते".utf8), Array("🙂".utf8),
            Array(Array("🙂".utf8).dropLast()), Array(Array("é".utf8).dropLast()),
            Array(Array("ते".utf8).dropLast()), [0x80],
            Array("ok ".utf8) + Array(Array("🙂".utf8).dropLast()),
        ]
        // `ArivuCore.` and `CoreParity.` are both required here. A bare `utf8CompletePrefix` inside
        // this enum resolves to CoreParity's own static member — the core's rule — so the comparison
        // would be the core against itself and would pass however far Swift's copy had drifted.
        for bytes in utf8Cases
        where ArivuCore.utf8CompletePrefix(bytes) != CoreParity.utf8CompletePrefix(bytes) {
            found.append("utf8 prefix disagreement on \(bytes): core \(CoreParity.utf8CompletePrefix(bytes)) vs Swift \(ArivuCore.utf8CompletePrefix(bytes))")
        }

        return found
    }

    /// The core's shipped profile, as a Swift value. Compared field by field against
    /// `Profile.compact`, so a change to either is a test failure rather than a surprise on device.
    public static func defaultProfile() -> Profile {
        let p = arivu_default_profile()
        return Profile(id: p.id.map { String(cString: $0) } ?? "",
                       modelID: p.model_id.map { String(cString: $0) } ?? "",
                       modelBytes: p.model_bytes,
                       nCtx: p.n_ctx,
                       nBatch: p.n_batch,
                       nThreads: p.n_threads,
                       kvQ8_0: p.kv_q8_0,
                       repack: p.repack,
                       replyReserveTokens: p.reply_reserve_tokens,
                       maxReplyTokens: p.max_reply_tokens,
                       kvBytesPerToken: p.kv_bytes_per_token,
                       computeBufferBytes: p.compute_buffer_bytes,
                       runtimeOverheadBytes: p.runtime_overhead_bytes,
                       minTotalRamBytes: p.min_total_ram_bytes,
                       minFreeStorageBytes: p.min_free_storage_bytes,
                       capabilities: Capabilities(rawValue: p.capabilities))
    }

    /// The core's answer to "can this device run this profile".
    ///
    /// `memorySource` must be passed through, not defaulted away: `arivu_device` zero-initialises to
    /// `ARIVU_MEM_UNMEASURED`, for which `arivu_headroom_permille` returns 0 and the core skips the
    /// ceiling check altogether. Leaving it unset — as this function used to — made
    /// `availableMemoryBytes` a dead argument and put `ARIVU_FIT_AVAILABLE_MEMORY`, the one branch
    /// that exists for jetsam, permanently out of reach of the parity test.
    public static func fit(_ profile: Profile, on device: DeviceFacts,
                           availableMemoryBytes: UInt64 = 0,
                           memorySource: MemorySource = .unmeasured) -> ProfileFit {
        var c = arivu_profile()
        var id = Array(profile.id.utf8CString)
        var modelID = Array(profile.modelID.utf8CString)
        return id.withUnsafeMutableBufferPointer { idBuffer in
            modelID.withUnsafeMutableBufferPointer { modelBuffer in
                c.id = UnsafePointer(idBuffer.baseAddress)
                c.model_id = UnsafePointer(modelBuffer.baseAddress)
                c.model_bytes = profile.modelBytes
                c.n_ctx = profile.nCtx
                c.n_batch = profile.nBatch
                c.n_threads = profile.nThreads
                c.kv_q8_0 = profile.kvQ8_0
                c.repack = profile.repack
                c.reply_reserve_tokens = profile.replyReserveTokens
                c.max_reply_tokens = profile.maxReplyTokens
                c.kv_bytes_per_token = profile.kvBytesPerToken
                c.compute_buffer_bytes = profile.computeBufferBytes
                c.runtime_overhead_bytes = profile.runtimeOverheadBytes
                c.min_total_ram_bytes = profile.minTotalRamBytes
                c.min_free_storage_bytes = profile.minFreeStorageBytes
                c.capabilities = profile.capabilities.rawValue

                var d = arivu_device()
                d.total_ram_bytes = device.totalRamBytes
                d.available_memory_bytes = availableMemoryBytes
                d.free_storage_bytes = device.freeStorageBytes
                d.performance_cores = profile.nThreads
                d.arm64 = device.arm64
                d.low_ram_flagged = device.lowRamFlagged
                d.memory_source = arivu_memory_source(UInt32(memorySource.rawValue))

                let check = arivu_profile_fits(&c, &d)
                switch check.fit {
                case ARIVU_FIT_OK: return .ok
                case ARIVU_FIT_NO_ARM64: return .noArm64
                case ARIVU_FIT_LOW_RAM_DEVICE: return .lowRamDevice
                case ARIVU_FIT_TOTAL_RAM:
                    return .totalRam(actual: check.actual_bytes, required: check.required_bytes)
                case ARIVU_FIT_AVAILABLE_MEMORY:
                    return .availableMemory(actual: check.actual_bytes, required: check.required_bytes)
                case ARIVU_FIT_STORAGE:
                    return .storage(actual: check.actual_bytes, required: check.required_bytes)
                default:
                    return .invalidProfile(String(cString: arivu_fit_name(check.fit)))
                }
            }
        }
    }
}
