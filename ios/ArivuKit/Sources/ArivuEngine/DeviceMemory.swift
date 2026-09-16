// What the phone will actually kill us for.
//
// Architecture's correction, and it is the single most important number on this platform: **jetsam
// charges `phys_footprint`, not resident size.** `phys_footprint` excludes clean file-backed pages,
// so the ~396 MB of mmap'd weights is very nearly free against the limit, while the KV cache and the
// compute buffer are charged in full. Reading RSS instead would say Arivu uses 750 MB when jetsam
// thinks it uses 200, and every lifecycle decision taken from that number would be wrong.
//
// Consequences that are written into the code rather than into a comment:
//   - the weights stay mmap'd and are never mlock'd, and `Policy.repackWeights` stays false: repacked
//     weights are dirty, i.e. charged (D-015).
//   - `n_gpu_layers` stays 0. Metal buffers are dirty memory, so offloading would convert ~373 MB of
//     uncharged clean pages into charged memory and delete the property the whole budget rests on.
//     That is a build-time switch in tools/ios/build_core.sh (GGML_METAL=OFF), not a setting (C8).
//
// spine: C2, C6

import ArivuCore
import Darwin
import Foundation

public enum DeviceMemory {
    /// Bytes this process is charged for by jetsam. `nil` if the kernel would not say.
    ///
    /// This is the number to compare against a budget, and the number to log. It is available on
    /// macOS too, which is why it can be exercised here rather than only on a device.
    public static func footprintBytes() -> UInt64? {
        // `proc_pid_rusage` rather than `task_info(TASK_VM_INFO)`: it reports `ri_phys_footprint`
        // directly, it is the same number, and it needs no read of `mach_task_self_`, which Swift 6
        // refuses from a concurrent context because the Darwin overlay declares it a global `var`.
        var info = rusage_info_current()
        let result = withUnsafeMutablePointer(to: &info) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(getpid(), RUSAGE_INFO_CURRENT, rebound)
            }
        }
        guard result == 0 else { return nil }
        return info.ri_phys_footprint
    }

    /// What this process may still allocate before it is killed, as of this instant.
    ///
    /// iOS only: `os_proc_available_memory()` is `API_UNAVAILABLE(macos)`, so on macOS this is nil
    /// and callers fall back to "not measured", which every caller already handles because Android
    /// has no equivalent reading either (C11: a missing measurement is not a platform branch).
    ///
    /// It is a reading of this second. It gates a *load attempt*, never a device: a transient low
    /// value must not condemn a phone permanently (leaves/design.md §5.4).
    public static func availableBytes() -> UInt64? {
        #if os(iOS)
        let available = os_proc_available_memory()
        return available > 0 ? UInt64(available) : nil
        #else
        return nil
        #endif
    }

    /// Total RAM. A tier signal only — it says which profile a device belongs to, never how much
    /// room there is right now. Re-read on every cold start rather than cached across launches.
    public static func physicalBytes() -> UInt64 { ProcessInfo.processInfo.physicalMemory }

    /// Is there room to create a context right now? `nil` where the platform cannot say, which is
    /// treated as "go ahead and try" — the allocation failing is itself an answer, and it produces
    /// `load_failed_low_memory` rather than a guess.
    public static func hasRoomForContext(_ required: UInt64 = Policy.minAvailableMemoryForContextBytes) -> Bool? {
        guard let available = availableBytes() else { return nil }
        return available >= required
    }

    /// Thread count = performance cores, not `activeProcessorCount`. Saturating the efficiency cores
    /// of a budget SoC is slower and hotter (leaves/BRIEF.md "Lifecycle"; D-008). Apple silicon
    /// reports its performance cluster directly, so there is no cpufreq scan as on Android.
    /// Clamped to the same [2, 4] band the Android heuristic uses, so the two platforms use the same
    /// number of threads on comparable hardware (C11).
    public static func performanceCoreCount() -> Int32 {
        let reported = sysctlInt("hw.perflevel0.logicalcpu")
            ?? sysctlInt("hw.perflevel0.physicalcpu")
            ?? Int32(ProcessInfo.processInfo.activeProcessorCount)
        return min(max(reported, Policy.minThreads), Policy.maxThreads)
    }

    private static func sysctlInt(_ name: String) -> Int32? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0, value > 0 else { return nil }
        return value
    }

    /// One line for the log when a reply ends, so M3 has evidence from real devices.
    /// Anything measured on the Simulator is non-representative and is labelled so here, for the
    /// same reason the Android side labels emulator results (leaves/NOTES.md).
    public static func summary() -> String {
        let footprint = footprintBytes().map { ByteSize.si($0) } ?? "?"
        let available = availableBytes().map { ByteSize.si($0) } ?? "not measured"
        return "memory: footprint=\(footprint) available=\(available) total=\(ByteSize.si(physicalBytes()))\(isSimulator ? " [SIMULATOR — NOT REPRESENTATIVE]" : "")"
    }

    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
}
