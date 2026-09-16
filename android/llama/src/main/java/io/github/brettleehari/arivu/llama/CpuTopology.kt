// spine: C2 — thread count = performance cores (leaves/BRIEF.md "Lifecycle").
package io.github.brettleehari.arivu.llama

import java.io.File

/**
 * Thread count = performance cores, not availableProcessors() (leaves/BRIEF.md "Lifecycle").
 * Cores are grouped by cpufreq max frequency; the lowest-frequency cluster is treated as
 * efficiency cores. Clamped to [2, 4]: a Helio G85 has 2 big cores, an SD680 has 4.
 * The benchmark sweeps thread counts to check this heuristic on the real phone.
 */
object CpuTopology {
    fun performanceCoreCount(): Int {
        val maxFreqs = (0 until Runtime.getRuntime().availableProcessors()).mapNotNull { cpu ->
            runCatching {
                File("/sys/devices/system/cpu/cpu$cpu/cpufreq/cpuinfo_max_freq").readText().trim().toLong()
            }.getOrNull()
        }
        if (maxFreqs.isEmpty()) return 4
        val lowest = maxFreqs.min()
        val fast = maxFreqs.count { it > lowest }
        val count = if (fast == 0) maxFreqs.size else fast
        return count.coerceIn(2, 4)
    }
}
