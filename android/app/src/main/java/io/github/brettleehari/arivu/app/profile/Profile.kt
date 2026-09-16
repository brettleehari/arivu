// spine: C11 — what Arivu does is chosen by what the device can carry (a profile), never by which
// platform it runs on. Nothing in this file mentions Android, and nothing outside it may branch on
// the platform: an 8GB Android phone and an 8GB iPhone must be able to receive the same profile.
package io.github.brettleehari.arivu.app.profile

import android.app.ActivityManager
import android.content.Context
import io.github.brettleehari.arivu.app.BuildConfig
import io.github.brettleehari.arivu.llama.CpuTopology

/**
 * What a feature is allowed to gate on. One value today, because iteration-1 is chat and nothing
 * else (SPINE R2, R4, R6). A richer device earns a value here; it never earns an `if (platform)`.
 */
enum class Capability { CHAT }

/**
 * What the phone can carry, in two numbers. Both exist on every platform — Android reads them from
 * ActivityManager and cpufreq, iOS will read them from `sysctl hw.memsize` and `hw.perflevel0` —
 * so the *selection* below stays identical on both (leaves/MULTIPLATFORM.md).
 */
data class DeviceProbe(val totalRamBytes: Long, val performanceCores: Int) {
    companion object {
        fun of(context: Context): DeviceProbe {
            val am = context.getSystemService(ActivityManager::class.java)
            val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
            return DeviceProbe(mi.totalMem, CpuTopology.performanceCoreCount())
        }
    }
}

/**
 * Every value the *device* gets a say in, in one immutable object — the shape
 * leaves/MULTIPLATFORM.md calls "a config object, not a code fork". The *user* still gets no say:
 * there is no settings screen and no model picker (spine: C8, SPINE R3, R5).
 *
 * `leaves/Policy.kt`'s remaining constants are the decisions no device gets a say in. The split is
 * the whole point: a second profile changes this object, not the code that reads it.
 *
 * /core is growing a matching `arivu_context_params`; when the C API carries a profile, this object
 * feeds it whole instead of being unpacked field by field (a later pass, not this one).
 */
data class Profile(
    /** Stable identifier. Logged, never shown to the user — it is not a setting they chose. */
    val name: String,
    /** Asset path of the GGUF. The ".so" suffix is D-013: bundletool page-aligns stored `*.so` entries. */
    val modelAsset: String,
    /** What the device must have to carry this profile. */
    val minTotalRamBytes: Long,
    val minPerformanceCores: Int,
    val nCtx: Int,
    val nBatch: Int,
    val kvQ8_0: Boolean,
    /** Ceiling on decode threads; the device's own performance-core count decides the rest. */
    val maxThreads: Int,
    val replyReserveTokens: Int,
    val maxReplyTokens: Int,
    val repackWeights: Boolean,
    val temperature: Float,
    val topK: Int,
    val topP: Float,
    val capabilities: Set<Capability>,
) {
    init {
        require(minPerformanceCores in 1..maxThreads) { "$name: minPerformanceCores must be 1..maxThreads" }
        require(replyReserveTokens < nCtx) { "$name: reply reserve does not fit in the context" }
    }

    fun fits(probe: DeviceProbe): Boolean =
        probe.totalRamBytes >= minTotalRamBytes && probe.performanceCores >= minPerformanceCores

    /** Threads for this device: its performance cores, never more than this profile allows. */
    fun threads(probe: DeviceProbe): Int = probe.performanceCores.coerceIn(minPerformanceCores, maxThreads)

    fun can(capability: Capability): Boolean = capability in capabilities
}

object Profiles {
    /**
     * The one profile that ships today: Qwen3 0.6B Q4_K_M, 2048-token context, q8_0 KV
     * (leaves/BRIEF.md "Context"; D-007 sampling; D-013 asset name; D-015 no repack).
     * Its RAM floor *is* the compatibility gate's floor (D-009), so every device the gate lets
     * through can carry it.
     */
    val COMPACT = Profile(
        name = "compact",
        modelAsset = "model/qwen3-0.6b-q4_k_m.gguf.so",
        minTotalRamBytes = BuildConfig.MIN_TOTAL_RAM_BYTES,
        minPerformanceCores = 2,
        nCtx = 2048,
        nBatch = 512,
        kvQ8_0 = true,
        maxThreads = 4,
        replyReserveTokens = 512,
        maxReplyTokens = 768,
        repackWeights = false,
        temperature = 0.7f,
        topK = 20,
        topP = 0.8f,
        capabilities = setOf(Capability.CHAT),
    )

    /**
     * Ordered most demanding → least demanding. Exactly one entry today, and a second one is a
     * Spine question (SPINE R3: no model picker, no second model in iteration-1), not a build tweak.
     */
    val SHIPPED: List<Profile> = listOf(COMPACT)
}

object ProfileSelector {
    /**
     * The most demanding profile this device can carry. [catalogue] is ordered most → least
     * demanding, so the first fit wins.
     *
     * If nothing fits, the floor profile is returned rather than null: a device below the floor
     * never reaches here, because the compatibility gate refuses it and offers to uninstall
     * (spine: C6, SPINE R8 — there is no "run it badly anyway" path for this to invent).
     */
    fun select(probe: DeviceProbe, catalogue: List<Profile> = Profiles.SHIPPED): Profile {
        require(catalogue.isNotEmpty()) { "no profiles to choose from" }
        return catalogue.firstOrNull { it.fits(probe) } ?: catalogue.last()
    }
}
