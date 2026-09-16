package io.github.brettleehari.arivu.app

import io.github.brettleehari.arivu.app.gate.CompatibilityGate
import io.github.brettleehari.arivu.app.gate.DeviceFacts
import io.github.brettleehari.arivu.app.gate.GateFailure
import io.github.brettleehari.arivu.app.gate.GateResult
import io.github.brettleehari.arivu.app.gate.GateThresholds
import org.junit.Assert.assertEquals
import org.junit.Test

// spine: C6 — layer 3 checks, in order, first failure wins.
class CompatibilityGateTest {
    private val t = GateThresholds(minTotalRamBytes = 3_500_000_000, minFreeStorageBytes = 256_000_000)
    private val good = DeviceFacts(listOf("arm64-v8a", "armeabi-v7a"), false, 3_700_000_000, 10_000_000_000)

    @Test fun passes() = assertEquals(GateResult.Pass, CompatibilityGate.evaluate(good, t))

    @Test fun noArm64() = assertEquals(
        GateResult.Fail(GateFailure.NoArm64),
        CompatibilityGate.evaluate(good.copy(supportedAbis = listOf("armeabi-v7a")), t),
    )

    @Test fun lowRamFlag() = assertEquals(
        GateResult.Fail(GateFailure.LowRamDevice),
        CompatibilityGate.evaluate(good.copy(isLowRamDevice = true), t),
    )

    @Test fun fakeLowTotalMem() = assertEquals(
        GateResult.Fail(GateFailure.TotalRam(2_000_000_000, t.minTotalRamBytes)),
        CompatibilityGate.evaluate(good.copy(totalMemBytes = 2_000_000_000), t),
    )

    @Test fun storage() = assertEquals(
        GateResult.Fail(GateFailure.Storage(1_000, t.minFreeStorageBytes)),
        CompatibilityGate.evaluate(good.copy(freeStorageBytes = 1_000), t),
    )

    @Test fun orderAbiBeforeRam() = assertEquals(
        GateResult.Fail(GateFailure.NoArm64),
        CompatibilityGate.evaluate(DeviceFacts(listOf("x86"), true, 1, 1), t),
    )
}
