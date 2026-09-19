// The parity suite, in the one target that links the real core.
//
// `ArivuKit`'s own `CoreParityTests` cannot do this job. Its test target links `CArivuStub`, and
// linking the real static library beside the fake one would duplicate every `arivu_*` symbol, so
// those tests guard themselves with `.enabled(if: CoreParity.isRealCore)` and skip — every time,
// everywhere, including in CI. The result was a safety net that had never once been under load:
// Swift's `kvBytesPerToken` had drifted from the core's by 3,584 bytes per token and nothing said so.
//
// This bundle is different. It links `ArivuCore.xcframework` through the app target, so
// `arivu_version()` does not begin "stub" and the comparison runs for real.
//
// The comparison itself lives in `CoreParity.disagreements()` rather than here, so that the two
// places it is invoked from cannot drift into two different ideas of what parity means.
//
// UNVERIFIED: not compiled. Runs on the Simulator or a device; CI runs it via
// `xcodebuild test -sdk iphonesimulator` after tools/ios/build_core.sh has produced the framework.
//
// spine: C7, C11

import ArivuCore
import ArivuEngine
import Testing

@Suite("Parity with the real core")
struct CoreParityTests {

    /// The whole of C11 in one assertion: the numbers and rules written down in Swift are the ones
    /// written down in C. A failure prints every disagreement, not just the first.
    @Test func theSwiftCopiesAgreeWithTheCore() {
        let disagreements = CoreParity.disagreements()
        // A literal with interpolation, not a concatenation: #expect's second argument is a
        // `Comment`, which is ExpressibleByStringInterpolation but not the result of `+`.
        #expect(disagreements.isEmpty,
                "the Swift copies and /core disagree:\n  - \(disagreements.joined(separator: "\n  - "))")
    }

    /// Guards the thing that made this suite worth writing: if the real core were not linked,
    /// `disagreements()` reports one note and compares nothing, and the test above would pass while
    /// proving nothing at all.
    @Test func theRealCoreIsLinked() {
        #expect(CoreParity.isRealCore,
                "this bundle linked the fake core (\(ArivuEngine.coreVersion)) — run tools/ios/build_core.sh")
    }

    /// The jetsam ceiling, end to end through the C. `memory_source` left unset is the mistake that
    /// made `availableMemoryBytes` a dead argument, so it is asserted to bite rather than assumed to.
    @Test func theProbedCeilingIsLive() {
        let phone = DeviceFacts(arm64: true, lowRamFlagged: false,
                                totalRamBytes: 8_000_000_000, freeStorageBytes: 8_000_000_000)
        let required = Profile.compact.requiredAvailableBytes(.probed)
        #expect(required > 0)
        // The ceiling charges the footprint, never the peak: the mapped weights are clean
        // file-backed pages the kernel can evict, and charging for them would refuse phones that
        // would have run this profile perfectly well (architecture B23).
        #expect(required < Profile.compact.estimatedPeakBytes)
        #expect(CoreParity.fit(.compact, on: phone,
                               availableMemoryBytes: required - 1, memorySource: .probed)
                == .availableMemory(actual: required - 1, required: required))
        #expect(CoreParity.fit(.compact, on: phone,
                               availableMemoryBytes: required, memorySource: .probed) == .ok)
        // A platform that admits it did not measure gets no ceiling, however small the reading.
        #expect(CoreParity.fit(.compact, on: phone,
                               availableMemoryBytes: 1, memorySource: .unmeasured) == .ok)
    }
}
