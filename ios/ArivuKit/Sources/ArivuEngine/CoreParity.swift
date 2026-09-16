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
    public static func fit(_ profile: Profile, on device: DeviceFacts, availableMemoryBytes: UInt64 = 0) -> ProfileFit {
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
