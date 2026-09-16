package io.github.brettleehari.arivu.llama

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.filterIsInstance
import kotlinx.coroutines.flow.last
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * spine: C2 (M2, M3)
 * W01 — benchmark harness. JNI + llama.cpp, no UI. Run only on the physical test phone:
 *
 *   tools/bench.sh                      # full run incl. 10-minute thermal soak
 *   tools/bench.sh -e thermalMinutes 0  # quick pass
 *
 * Decides 0.6B vs 1.7B (M2), the RAM floor for the compatibility gate (M3, D-009),
 * the thread-count heuristic (D-008) and weight repacking (D-015).
 * Output: JSON in logcat (tag arivu-bench) and in the test app's files dir.
 *
 * Arguments (instrumentation -e):
 *   threads         comma list, default "2,4,<perf-core-heuristic>"
 *   repack          comma list of true/false, default "false"
 *   nCtx            default 2048
 *   thermalMinutes  default 10
 *   modelAsset      default "model/Qwen3-0.6B-Q4_K_M.gguf.so"
 */
@RunWith(AndroidJUnit4::class)
class Benchmark {
    private val instr = InstrumentationRegistry.getInstrumentation()
    private val args = InstrumentationRegistry.getArguments()
    private val ctx: Context = instr.context  // test APK: holds the model asset
    private val app: Context = instr.targetContext

    @Test
    fun run() = runBlocking {
        val heuristic = CpuTopology.performanceCoreCount()
        val threads = (args.getString("threads") ?: "2,4,$heuristic").split(",").map { it.trim().toInt() }.distinct()
        val repacks = (args.getString("repack") ?: "false").split(",").map { it.trim().toBoolean() }.distinct()
        val nCtx = args.getString("nCtx")?.toInt() ?: 2048
        val thermalMinutes = args.getString("thermalMinutes")?.toDouble() ?: 10.0
        val assetName = args.getString("modelAsset") ?: "model/Qwen3-0.6B-Q4_K_M.gguf.so"

        val report = JSONObject()
        report.put("device", deviceJson(heuristic))

        val afd = ctx.assets.openFd(assetName)
        report.put("asset", JSONObject().apply {
            put("name", assetName)
            put("offset", afd.startOffset)
            put("length", afd.length)
            put("offsetMod32", afd.startOffset % 32)
            put("offsetMod4096", afd.startOffset % 4096)
            put("offsetMod16384", afd.startOffset % 16384)
        })

        val runs = JSONArray()
        for (repack in repacks) {
            for (t in threads) {
                val engine = LlamaEngine(app)
                val window = ModelWindow(afd.parcelFileDescriptor.dup(), afd.startOffset, afd.length)
                val loadStart = SystemClock.elapsedRealtime()
                engine.loadModel(window, repack)
                window.close()
                val loadMs = SystemClock.elapsedRealtime() - loadStart
                engine.ensureContext(ContextSpec(nCtx = nCtx, nBatch = 512, nThreads = t, kvQ8 = true))
                val afterContext = LlamaEngine.memoryKb()

                val cases = JSONArray()
                for (case in BenchmarkPrompts.cases) {
                    engine.freeContext()  // cold prefill per case: no prefix reuse across cases
                    engine.ensureContext(ContextSpec(nCtx = nCtx, nBatch = 512, nThreads = t, kvQ8 = true))
                    val stats = generate(engine, BenchmarkPrompts.chatml(case.user), case.maxNew)
                    cases.put(statsJson(case.id, stats))
                    log("threads=$t repack=$repack ${case.id}: prefill %.1f tok/s, decode %.1f tok/s".format(stats.prefillTokensPerSec, stats.decodeTokensPerSec))
                }
                engine.freeContext()
                val afterFree = LlamaEngine.memoryKb()
                runs.put(JSONObject().apply {
                    put("threads", t)
                    put("repack", repack)
                    put("loadMs", loadMs)
                    put("rssKbAfterContext", afterContext.first)
                    put("computeBufferKib", LlamaEngine.computeBufferKib())  // host: 26.6 MiB with n_outputs_max = 1
                    put("rssKbAfterFreeContext", afterFree.first)
                    put("peakRssKb", afterFree.second)
                    put("cases", cases)
                })
                engine.close()
            }
        }
        report.put("runs", runs)

        if (thermalMinutes > 0) {
            report.put("thermal", thermalSoak(afd, heuristic, nCtx, thermalMinutes))
        }
        afd.close()

        val out = File(app.getExternalFilesDir(null) ?: app.filesDir, "bench-${System.currentTimeMillis()}.json")
        out.writeText(report.toString(2))
        log("wrote ${out.absolutePath}")
        report.toString().chunked(3000).forEach { Log.i(TAG, "ARIVU_BENCH_JSON $it") }
    }

    /** Repeated decode until thermalMinutes elapse; reports per-minute decode rate and thermal status. */
    private suspend fun thermalSoak(afd: android.content.res.AssetFileDescriptor, threads: Int, nCtx: Int, minutes: Double): JSONObject {
        val pm = app.getSystemService(PowerManager::class.java)
        val engine = LlamaEngine(app)
        ModelWindow(afd.parcelFileDescriptor.dup(), afd.startOffset, afd.length).use { engine.loadModel(it) }
        val spec = ContextSpec(nCtx = nCtx, nBatch = 512, nThreads = threads, kvQ8 = true)
        val prompt = BenchmarkPrompts.chatml(BenchmarkPrompts.cases[2].user)

        val windows = JSONArray()
        val start = SystemClock.elapsedRealtime()
        val end = start + (minutes * 60_000).toLong()
        var windowStart = start
        var tokens = 0
        var micros = 0L
        var baseline = -1.0
        var onsetSec = -1.0
        while (SystemClock.elapsedRealtime() < end) {
            engine.freeContext()
            engine.ensureContext(spec)
            val s = generate(engine, prompt, 192)
            tokens += s.generated
            micros += s.decodeMicros
            val now = SystemClock.elapsedRealtime()
            if (now - windowStart >= 60_000 || now >= end) {
                val rate = if (micros > 0) tokens * 1e6 / micros else 0.0
                if (baseline < 0) baseline = rate
                val status = pm.currentThermalStatus
                val headroom = pm.getThermalHeadroom(10)
                val elapsed = (now - start) / 1000.0
                if (onsetSec < 0 && (rate < baseline * 0.85 || status >= PowerManager.THERMAL_STATUS_MODERATE)) onsetSec = elapsed
                windows.put(JSONObject().apply {
                    put("elapsedSec", elapsed)
                    put("decodeTokPerSec", rate)
                    put("thermalStatus", status)
                    put("thermalHeadroom10s", headroom.toDouble())
                })
                log("thermal t=%.0fs decode %.1f tok/s status=%d headroom=%.2f".format(elapsed, rate, status, headroom))
                windowStart = now
                tokens = 0
                micros = 0
            }
        }
        engine.close()
        return JSONObject().apply {
            put("threads", threads)
            put("minutes", minutes)
            put("throttleOnsetSec", onsetSec)  // -1: no throttling observed
            put("windows", windows)
        }
    }

    private suspend fun generate(engine: LlamaEngine, prompt: String, maxNew: Int): GenerationStats {
        val sampling = SamplingSpec(temperature = 0.7f, topK = 20, topP = 0.8f, seed = 42)
        return engine.generate(prompt, maxNew, sampling).filterIsInstance<GenerationEvent.Done>().last().stats
    }

    private fun statsJson(id: String, s: GenerationStats) = JSONObject().apply {
        put("case", id)
        put("stop", s.stop.name)
        put("promptTokens", s.promptTokens)
        put("generated", s.generated)
        put("prefillTokPerSec", s.prefillTokensPerSec)
        put("decodeTokPerSec", s.decodeTokensPerSec)
        put("peakRssKb", LlamaEngine.memoryKb().second)
        s.error?.let { put("error", it) }
    }

    private fun deviceJson(heuristic: Int): JSONObject {
        val am = app.getSystemService(ActivityManager::class.java)
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        return JSONObject().apply {
            put("manufacturer", Build.MANUFACTURER)
            put("model", Build.MODEL)
            put("soc", if (Build.VERSION.SDK_INT >= 31) "${Build.SOC_MANUFACTURER} ${Build.SOC_MODEL}" else Build.HARDWARE)
            put("sdk", Build.VERSION.SDK_INT)
            put("totalMemBytes", mi.totalMem)
            put("isLowRamDevice", am.isLowRamDevice)
            put("cpus", Runtime.getRuntime().availableProcessors())
            put("perfCoreHeuristic", heuristic)
            put("pageSize", android.system.Os.sysconf(android.system.OsConstants._SC_PAGESIZE))
        }
    }

    private fun log(msg: String) = Log.i(TAG, msg)

    private companion object {
        const val TAG = "arivu-bench"
    }
}
