// The gate, the profile arithmetic, and the stop-reason mapping.
//
// The gate cases mirror android/app/src/test/.../CompatibilityGateTest.kt. The two iOS-specific
// facts — that an iPhone can never fail the ABI or low-RAM checks — are asserted rather than
// assumed, because they are the reason the iOS screen carries only two sentences (design.md §5.4).
//
// spine: C6, C7, C10, C11

import Foundation
import Testing
@testable import ArivuCore

@Suite("Device gate")
struct DeviceGateTests {
    private let thresholds = GateThresholds(minTotalRamBytes: 3_500_000_000, minFreeStorageBytes: 256_000_000)
    private let good = DeviceFacts(arm64: true, lowRamFlagged: false,
                                   totalRamBytes: 3_700_000_000, freeStorageBytes: 10_000_000_000)

    @Test func passes() {
        #expect(CompatibilityGate.evaluate(good, thresholds) == .pass)
    }

    @Test func notArm64() {
        var facts = good
        facts.arm64 = false
        #expect(CompatibilityGate.evaluate(facts, thresholds) == .fail(.noArm64))
    }

    @Test func lowRamFlag() {
        var facts = good
        facts.lowRamFlagged = true
        #expect(CompatibilityGate.evaluate(facts, thresholds) == .fail(.lowRamDevice))
    }

    @Test func totalRam() {
        var facts = good
        facts.totalRamBytes = 2_000_000_000
        #expect(CompatibilityGate.evaluate(facts, thresholds)
                == .fail(.totalRam(actual: 2_000_000_000, required: thresholds.minTotalRamBytes)))
    }

    @Test func storage() {
        var facts = good
        facts.freeStorageBytes = 1_000
        #expect(CompatibilityGate.evaluate(facts, thresholds)
                == .fail(.storage(actual: 1_000, required: thresholds.minFreeStorageBytes)))
    }

    /// First failure wins, in the order leaves/BRIEF.md lists the checks.
    @Test func abiIsCheckedBeforeRam() {
        let bad = DeviceFacts(arm64: false, lowRamFlagged: true, totalRamBytes: 1, freeStorageBytes: 1)
        #expect(CompatibilityGate.evaluate(bad, thresholds) == .fail(.noArm64))
    }

    /// design.md §5.4: on iOS the first two checks cannot fire, which is why the gate screen has
    /// only two possible sentences there. If this ever fails, the screen needs more copy.
    @Test func iOSDeviceCanOnlyFailTheTwoChecksItHasCopyFor() {
        var facts = CompatibilityGate.measure()
        facts.arm64 = true          // every iPhone that runs iOS 17 is arm64
        facts.lowRamFlagged = false // iOS has no low-RAM flag
        facts.totalRamBytes = 1
        #expect(CompatibilityGate.evaluate(facts, thresholds) == .fail(.totalRam(actual: 1, required: thresholds.minTotalRamBytes)))
        facts.totalRamBytes = 8_000_000_000
        facts.freeStorageBytes = 1
        #expect(CompatibilityGate.evaluate(facts, thresholds) == .fail(.storage(actual: 1, required: thresholds.minFreeStorageBytes)))
    }

    /// A pass is remembered per app version and RAM size; a failure never is, because storage can
    /// be freed and the user deserves a second look.
    @Test func passIsCachedAndFailureIsNot() {
        let defaults = UserDefaults(suiteName: "arivu.gate.tests.\(UUID().uuidString)")!
        let store = GatePassStore(defaults: defaults)

        #expect(CompatibilityGate.check(appVersion: "1.0", facts: good, thresholds: thresholds, store: store) == .pass)
        // A device that would now fail still passes, because the pass was remembered.
        var worse = good
        worse.totalRamBytes = 1
        #expect(CompatibilityGate.check(appVersion: "1.0", facts: good, thresholds: thresholds, store: store) == .pass)
        // A different RAM size, or a new version, is a different question.
        #expect(CompatibilityGate.check(appVersion: "1.0", facts: worse, thresholds: thresholds, store: store)
                == .fail(.totalRam(actual: 1, required: thresholds.minTotalRamBytes)))
        #expect(CompatibilityGate.check(appVersion: "1.0", facts: worse, thresholds: thresholds, store: store)
                == .fail(.totalRam(actual: 1, required: thresholds.minTotalRamBytes)))
    }

    /// Android formats sizes in SI units, so the 3.3 GiB floor reads "3.5 GB". The iOS screen must
    /// show the same number for the same phone.
    @Test func sizesReadTheSameAsOnAndroid() {
        #expect(ByteSize.si(3_543_348_019) == "3.5 GB")
        #expect(ByteSize.si(2_000_000_000) == "2.0 GB")
        #expect(ByteSize.si(268_435_456) == "268 MB")
        #expect(ByteSize.si(180_000_000) == "180 MB")
        #expect(ByteSize.si(512) == "512 B")
    }
}

@Suite("Profiles — capability by device, never by platform (C11)")
struct ProfileTests {
    @Test("the shipped profile is the shipped policy")
    func shippedProfileMatchesPolicy() {
        let p = Profile.compact
        #expect(p.nCtx == Policy.nCtx)
        #expect(p.nBatch == Policy.nBatch)
        #expect(p.kvQ8_0 == Policy.kvQ8_0)
        #expect(p.repack == Policy.repackWeights)
        #expect(p.replyReserveTokens == Policy.replyReserveTokens)
        #expect(p.maxReplyTokens == Policy.maxReplyTokens)
        #expect(p.capabilities == [.chat])
        #expect(p.validationError == nil)
    }

    /// M3: peak working set ≤ 800 MB. The estimate is what the gate uses before anything is loaded.
    @Test("the estimated peak fits the M3 budget")
    func estimatedPeak() {
        #expect(Profile.compact.estimatedPeakBytes <= 800_000_000)
    }

    @Test("an internally inconsistent profile is rejected before a device is ever consulted")
    func invalidProfile() {
        var p = Profile.compact
        p.nBatch = p.nCtx + 1
        #expect(p.validationError != nil)
        let anyDevice = DeviceFacts(arm64: true, lowRamFlagged: false,
                                    totalRamBytes: 8_000_000_000, freeStorageBytes: 8_000_000_000)
        if case .invalidProfile = p.fits(anyDevice) {} else { Issue.record("expected .invalidProfile") }
    }

    /// The whole point of C11: the same 8 GB device gets the same answer whatever OS it runs.
    @Test("fit depends only on the numbers the platform measured")
    func fitIsPlatformFree() {
        let phone = DeviceFacts(arm64: true, lowRamFlagged: false,
                                totalRamBytes: 8_000_000_000, freeStorageBytes: 8_000_000_000)
        #expect(Profile.compact.fits(phone) == .ok)

        // The ceiling applies to the charged footprint plus headroom, never to the peak: the mapped
        // weights are clean file-backed pages the kernel can evict and re-read, and charging a
        // device for them would refuse phones that would have run this profile perfectly (B23).
        let required = Profile.compact.requiredAvailableBytes(.probed)
        #expect(required == Profile.compact.footprintBytes * 14 / 10)
        #expect(required < Profile.compact.estimatedPeakBytes, "the peak must not be the ceiling")
        #expect(Profile.compact.fits(phone, availableMemoryBytes: 300_000_000, memorySource: .probed)
                == .availableMemory(actual: 300_000_000, required: required))
        #expect(Profile.compact.fits(phone, availableMemoryBytes: required, memorySource: .probed) == .ok)

        // A probed reading earns *more* headroom than an inferred one, because it is an
        // instantaneous best case taken at the calmest moment in the app's life.
        #expect(Profile.compact.requiredAvailableBytes(.inferred) < required)

        // Zero means "not measured", which is what Android always reports. It is not a failure —
        // and neither is a tiny reading when the platform admits it did not measure.
        #expect(Profile.compact.fits(phone, availableMemoryBytes: 0, memorySource: .probed) == .ok)
        #expect(Profile.compact.fits(phone, availableMemoryBytes: 1, memorySource: .unmeasured) == .ok)
        #expect(Profile.compact.requiredAvailableBytes(.unmeasured) == 0)
    }

    @Test("selection takes the first profile that fits, richest first")
    func selection() {
        var rich = Profile.compact
        rich.id = "rich"
        rich.minTotalRamBytes = 7_000_000_000
        let phone = DeviceFacts(arm64: true, lowRamFlagged: false,
                                totalRamBytes: 4_000_000_000, freeStorageBytes: 8_000_000_000)
        #expect(Profile.select(from: [rich, .compact], for: phone) == 1)
        #expect(Profile.select(from: [rich], for: phone) == nil)
    }

    @Test("the reply budget never overruns the context")
    func replyBudget() {
        let p = Profile.compact
        #expect(p.replyBudget(promptTokens: 100) == Policy.maxReplyTokens)
        #expect(p.replyBudget(promptTokens: p.nCtx - 10) == 10)
        #expect(p.replyBudget(promptTokens: p.nCtx + 100) == 0)
    }
}

@Suite("Stop reasons")
struct StopReasonTests {
    @Test("the engine's reasons map one-to-one onto what the file records")
    func mapping() {
        #expect(StopReason.endOfTurn.stop == .endOfTurn)
        #expect(StopReason.cancelled.stop == .cancelled)
        #expect(StopReason.contextFull.stop == .contextFull)
        #expect(StopReason.maxTokens.stop == .maxTokens)
        #expect(StopReason.error.stop == .error)
    }

    @Test("raw values match the C enum in core/include/arivu/arivu.h")
    func rawValues() {
        #expect(StopReason.endOfTurn.rawValue == 0)
        #expect(StopReason.cancelled.rawValue == 1)
        #expect(StopReason.contextFull.rawValue == 2)
        #expect(StopReason.maxTokens.rawValue == 3)
        #expect(StopReason.error.rawValue == 4)
    }

    /// The engine only ever says "cancelled". Who asked for it is what the user is shown, and the
    /// user's own Stop is never relabelled (leaves/design.md §7).
    @Test("a cancel is labelled by why it happened")
    func cancelCause() {
        #expect(resolveStop(.cancelled, cancelCause: .user) == .cancelled)
        #expect(resolveStop(.cancelled, cancelCause: .memoryPressure) == .lowMemory)
        #expect(resolveStop(.cancelled, cancelCause: .backgroundExpiring) == .backgrounded)
        #expect(resolveStop(.cancelled, cancelCause: nil) == .cancelled)
        // A cause hanging around from an earlier stop must not relabel a normal ending.
        #expect(resolveStop(.endOfTurn, cancelCause: .memoryPressure) == .endOfTurn)
        #expect(resolveStop(.contextFull, cancelCause: .user) == .contextFull)
    }

    @Test("a reply found unfinished after process death is labelled Stopped, and nothing more")
    func processDeath() {
        #expect(stopAfterProcessDeath == .cancelled)
    }

    @Test("tokens-per-second arithmetic")
    func rates() {
        let stats = GenerationStats(stop: .endOfTurn, promptTokens: 200, reusedTokens: 50, generated: 100,
                                    prefillMs: 1000, decodeMs: 5000, firstTokenMs: 900)
        #expect(stats.prefillTokensPerSecond == 150)
        #expect(stats.decodeTokensPerSecond == 20)
        #expect(GenerationStats(stop: .error).decodeTokensPerSecond == 0)
    }

    /// The one thing Arivu learns about the phone it runs on.
    @Test("a measured footprint replaces the estimate, in both directions")
    func calibrationBeatsTheEstimate() {
        let p = Profile.compact
        let estimate = p.requiredAvailableBytes(.probed)

        // Hungrier than predicted: demand more. This is the only thing between the user and a kill
        // on a device whose runtime overhead the profile under-guessed.
        let hungry = p.requiredAvailableBytes(.probed, observedFootprintBytes: p.footprintBytes * 2)
        #expect(hungry > estimate)

        // Cheaper than predicted: demand less. Refusing a phone this app has already run on is the
        // other half of the same mistake.
        let lean = p.requiredAvailableBytes(.probed, observedFootprintBytes: p.footprintBytes / 2)
        #expect(lean < estimate)

        // The headroom survives either way: adapting the magnitude must not remove the margin.
        #expect(lean > p.footprintBytes / 2)

        // No observation yet, or a platform that never measures: unchanged, and no ceiling at all.
        #expect(p.requiredAvailableBytes(.probed, observedFootprintBytes: 0) == estimate)
        #expect(p.requiredAvailableBytes(.unmeasured, observedFootprintBytes: p.footprintBytes * 99) == 0)
    }

    @Test("the calibration store keeps the maximum, per profile, and ignores nothing-readings")
    func calibrationStoreKeepsTheWorstCase() throws {
        let defaults = try #require(UserDefaults(suiteName: "arivu.calibration.\(UUID().uuidString)"))
        let store = MemoryCalibrationStore(defaults: defaults)

        #expect(store.observedFootprintBytes(for: "compact") == 0)
        store.record(300_000_000, for: "compact")
        #expect(store.observedFootprintBytes(for: "compact") == 300_000_000)

        // A cheaper run must not relax the bar — the store is a high-water mark, not a last value.
        store.record(100_000_000, for: "compact")
        #expect(store.observedFootprintBytes(for: "compact") == 300_000_000)

        store.record(400_000_000, for: "compact")
        #expect(store.observedFootprintBytes(for: "compact") == 400_000_000)

        // 0 means "the platform would not say", not "it cost nothing".
        store.record(0, for: "compact")
        #expect(store.observedFootprintBytes(for: "compact") == 400_000_000)

        // A different profile has a different footprint; its measurement says nothing about this one.
        #expect(store.observedFootprintBytes(for: "standard") == 0)
    }
}
