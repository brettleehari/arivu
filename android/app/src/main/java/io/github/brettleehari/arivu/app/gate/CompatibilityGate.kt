package io.github.brettleehari.arivu.app.gate

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import io.github.brettleehari.arivu.app.BuildConfig

/** spine: C6 — layer 3 of the compatibility gate (CLAUDE.md "Device compatibility gate"). */
sealed interface GateResult {
    data object Pass : GateResult
    data class Fail(val failure: GateFailure) : GateResult
}

sealed interface GateFailure {
    data object NoArm64 : GateFailure
    data object LowRamDevice : GateFailure
    data class TotalRam(val actualBytes: Long, val requiredBytes: Long) : GateFailure
    data class Storage(val actualBytes: Long, val requiredBytes: Long) : GateFailure
}

data class DeviceFacts(
    val supportedAbis: List<String>,
    val isLowRamDevice: Boolean,
    val totalMemBytes: Long,
    val freeStorageBytes: Long,
)

data class GateThresholds(val minTotalRamBytes: Long, val minFreeStorageBytes: Long)

object CompatibilityGate {
    /** Pure: checks run in the order CLAUDE.md lists them; first failure wins. */
    fun evaluate(facts: DeviceFacts, t: GateThresholds): GateResult = when {
        "arm64-v8a" !in facts.supportedAbis -> GateResult.Fail(GateFailure.NoArm64)
        facts.isLowRamDevice -> GateResult.Fail(GateFailure.LowRamDevice)
        facts.totalMemBytes < t.minTotalRamBytes -> GateResult.Fail(GateFailure.TotalRam(facts.totalMemBytes, t.minTotalRamBytes))
        facts.freeStorageBytes < t.minFreeStorageBytes -> GateResult.Fail(GateFailure.Storage(facts.freeStorageBytes, t.minFreeStorageBytes))
        else -> GateResult.Pass
    }

    val thresholds = GateThresholds(BuildConfig.MIN_TOTAL_RAM_BYTES, BuildConfig.MIN_FREE_STORAGE_BYTES)

    /**
     * Cached: a pass is remembered per app version and RAM size, so later launches cost one
     * SharedPreferences read. Failures are not cached (storage can be freed).
     *
     * Debug builds accept `--el arivu.fakeTotalMem <bytes>` on the launch intent to exercise
     * the failure screen (W10): adb shell am start -n <pkg>/io.github.brettleehari.arivu.app.MainActivity --el arivu.fakeTotalMem 2000000000
     */
    fun check(context: Context, fakeTotalMem: Long? = null): GateResult {
        val am = context.getSystemService(ActivityManager::class.java)
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val totalMem = if (BuildConfig.DEBUG && fakeTotalMem != null) fakeTotalMem else mi.totalMem

        val prefs = context.getSharedPreferences("gate", Context.MODE_PRIVATE)
        val key = "pass:${BuildConfig.VERSION_CODE}:$totalMem"
        if (prefs.getBoolean(key, false)) return GateResult.Pass

        val facts = DeviceFacts(
            supportedAbis = Build.SUPPORTED_ABIS.toList(),
            isLowRamDevice = am.isLowRamDevice,
            totalMemBytes = totalMem,
            freeStorageBytes = StatFs(context.filesDir.absolutePath).availableBytes,
        )
        val result = evaluate(facts, thresholds)
        if (result == GateResult.Pass) prefs.edit().clear().putBoolean(key, true).apply()
        return result
    }
}
