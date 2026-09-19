// Layer 3 of the compatibility gate — the only layer iOS has.
//
// Android gets three layers: manifest filtering, Play Console device exclusion, and this runtime
// check. The App Store has no device-exclusion catalogue (leaves/architecture/ios-port.md), so on
// iOS the first two layers collapse into "a minimum iOS version", and this check carries the rest.
// More iOS users will therefore reach the incompatible screen than Android users ever do
// (leaves/design.md §5.4), which is why the screen is written as a first impression.
//
// The evaluator is ONE function for both platforms (C11). It branches on measured facts, never on
// "am I on iOS": iOS simply reports `arm64 == true` and `lowRamFlagged == false`, because every
// supported iPhone is arm64 and iOS has no low-RAM flag, so those two checks cannot fire there.
// Writing it this way is what stops the two platforms drifting into two policies.
//
// What is deliberately NOT a gate: `os_proc_available_memory()`. It is a reading of this second, and
// a transient low value must never condemn a phone permanently. It is used at load time, where it
// produces `load_failed_low_memory` and the user can try again (leaves/design.md §5.4).
//
// spine: C6, C11, R8 (there is no "continue anyway")

import Foundation

public struct DeviceFacts: Equatable, Sendable {
    public var arm64: Bool
    public var lowRamFlagged: Bool
    public var totalRamBytes: UInt64
    public var freeStorageBytes: UInt64

    public init(arm64: Bool, lowRamFlagged: Bool, totalRamBytes: UInt64, freeStorageBytes: UInt64) {
        self.arm64 = arm64
        self.lowRamFlagged = lowRamFlagged
        self.totalRamBytes = totalRamBytes
        self.freeStorageBytes = freeStorageBytes
    }
}

public struct GateThresholds: Equatable, Sendable {
    public var minTotalRamBytes: UInt64
    public var minFreeStorageBytes: UInt64

    public init(minTotalRamBytes: UInt64, minFreeStorageBytes: UInt64) {
        self.minTotalRamBytes = minTotalRamBytes
        self.minFreeStorageBytes = minFreeStorageBytes
    }

    public static let shipped = GateThresholds(minTotalRamBytes: Policy.minTotalRamBytes,
                                               minFreeStorageBytes: Policy.minFreeStorageBytes)
}

public enum GateFailure: Equatable, Sendable {
    case noArm64
    case lowRamDevice
    case totalRam(actual: UInt64, required: UInt64)
    case storage(actual: UInt64, required: UInt64)
}

public enum GateResult: Equatable, Sendable {
    case pass
    case fail(GateFailure)
}

public enum CompatibilityGate {
    /// Pure: checks run in the order leaves/BRIEF.md lists them; first failure wins.
    public static func evaluate(_ facts: DeviceFacts, _ t: GateThresholds) -> GateResult {
        if !facts.arm64 { return .fail(.noArm64) }
        if facts.lowRamFlagged { return .fail(.lowRamDevice) }
        // Zero means "not measured", never "measured as none" — the same rule `arivu_profile_fits`
        // applies with its `d->total_ram_bytes != 0` and `d->free_storage_bytes != 0` guards. A
        // platform that cannot answer says so, and the check stands down rather than inventing a
        // verdict (architecture B23).
        //
        // Without this, the first run of the app said "This phone has 0 B of free storage. Arivu
        // needs at least 268 MB" and refused to start — on a Simulator with 600 GB free, because
        // `volumeAvailableCapacityForImportantUsage` does not answer there. Condemning a device we
        // failed to measure is the worst of the available mistakes: it is invisible, it is
        // permanent from the user's side, and there is no "continue anyway" (R8).
        if facts.totalRamBytes != 0 && facts.totalRamBytes < t.minTotalRamBytes {
            return .fail(.totalRam(actual: facts.totalRamBytes, required: t.minTotalRamBytes))
        }
        if facts.freeStorageBytes != 0 && facts.freeStorageBytes < t.minFreeStorageBytes {
            return .fail(.storage(actual: facts.freeStorageBytes, required: t.minFreeStorageBytes))
        }
        return .pass
    }

    /// The facts this device reports. `arm64` and `lowRamFlagged` are constants on iOS by fact, not
    /// by fiat: every iPhone that can run iOS 17 is arm64, and iOS has no low-memory device flag.
    public static func measure(fileManager: FileManager = .default) -> DeviceFacts {
        #if arch(arm64)
        let isArm64 = true
        #else
        // A simulator on an Intel Mac, or a Mac build. Not a shipping configuration; reported honestly.
        let isArm64 = false
        #endif
        return DeviceFacts(arm64: isArm64,
                           lowRamFlagged: false,
                           totalRamBytes: ProcessInfo.processInfo.physicalMemory,
                           freeStorageBytes: freeStorageBytes(fileManager: fileManager))
    }

    /// `volumeAvailableCapacityForImportantUsage` is the number iOS itself would use to decide
    /// whether a download may proceed: it counts space the system would purge if asked. The plain
    /// `volumeAvailableCapacity` under-reports on a phone full of purgeable caches.
    public static func freeStorageBytes(fileManager: FileManager = .default) -> UInt64 {
        let url = (try? fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                        appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSHomeDirectory())
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let important = values.volumeAvailableCapacityForImportantUsage {
            return UInt64(max(important, 0))
        }
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let available = values.volumeAvailableCapacity {
            return UInt64(max(available, 0))
        }
        return 0
    }

    /// A pass is remembered per app version and RAM size, so later launches cost one defaults read.
    /// Failures are not cached: storage can be freed. Same rule as `CompatibilityGate.check` on Android.
    public static func check(appVersion: String,
                             facts: DeviceFacts = measure(),
                             thresholds: GateThresholds = .shipped,
                             store: GatePassStore = .standard) -> GateResult {
        let key = "pass:\(appVersion):\(facts.totalRamBytes)"
        if store.isRemembered(key) { return .pass }
        let result = evaluate(facts, thresholds)
        if result == .pass { store.remember(key) }
        return result
    }
}

/// The one thing Arivu persists that is not the conversation: "this phone already passed".
/// It is not a user preference and the user cannot change it, which is why C8 still holds.
public final class GatePassStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let storageKey = "io.github.brettleehari.arivu.gate.pass"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    public static let standard = GatePassStore()

    public func isRemembered(_ key: String) -> Bool { defaults.string(forKey: storageKey) == key }
    public func remember(_ key: String) { defaults.set(key, forKey: storageKey) }
    public func forget() { defaults.removeObject(forKey: storageKey) }
}

/// Sizes as the user reads them. Android formats in SI units (`Formatter.formatShortFileSize`), so
/// the 3.3 GiB floor reads "3.5 GB"; iOS does the same arithmetic rather than switching to GiB,
/// because the two gate screens must show the same number for the same phone.
public enum ByteSize {
    public static func si(_ bytes: UInt64) -> String {
        let units = ["B", "kB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unit = 0
        while value >= 1000 && unit < units.count - 1 {
            value /= 1000
            unit += 1
        }
        let rounded = value < 10 && unit > 0 ? String(format: "%.1f", value) : String(format: "%.0f", value)
        return "\(rounded) \(units[unit])"
    }
}
