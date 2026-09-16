package io.github.brettleehari.arivu.app.inference

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import io.github.brettleehari.arivu.app.Policy
import io.github.brettleehari.arivu.app.model.ModelSource
import io.github.brettleehari.arivu.app.profile.DeviceProbe
import io.github.brettleehari.arivu.app.profile.Profile
import io.github.brettleehari.arivu.llama.ContextSpec
import io.github.brettleehari.arivu.llama.GenerationEvent
import io.github.brettleehari.arivu.llama.GenerationStats
import io.github.brettleehari.arivu.llama.StopReason
import io.github.brettleehari.arivu.llama.LlamaEngine
import io.github.brettleehari.arivu.llama.SamplingSpec

enum class EngineState { COLD, STARTING, READY, GENERATING }

/**
 * Owns the engine and enforces leaves/BRIEF.md "Lifecycle — load only during operation":
 *  - model + context created lazily on the first message, never at app start
 *  - context freed after [Policy.CONTEXT_IDLE_MILLIS] idle, and when the UI is hidden
 *  - UI_HIDDEN frees the context; BACKGROUND and above also free the (mmap'd) model (D-012)
 *  - a foreground service runs from the first prefill to the last token (D-003)
 *  - a foreground-critical trim stops the reply and says why, instead of being killed (spine: C6)
 * Sizes, threads and sampling come from the device's [Profile], never from a setting (spine: C11).
 * spine: C2, C10
 */
class InferenceController(
    private val context: Context,
    private val modelSource: ModelSource,
    private val profile: Profile,
    probe: DeviceProbe,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val lock = Mutex()
    private var engine: LlamaEngine? = null
    private var idleJob: Job? = null
    @Volatile private var uiVisible = true

    private val _state = MutableStateFlow(EngineState.COLD)
    val state: StateFlow<EngineState> = _state.asStateFlow()

    private val threads = profile.threads(probe)

    /** `SystemClock`-free: compared only with other wall-clock stamps. 0 until a critical trim lands. */
    @Volatile private var criticalTrimAt = 0L

    val promptBuilder = PromptBuilder(Policy.SYSTEM_PROMPT, profile.nCtx, profile.replyReserveTokens) { text ->
        lock.withLock { ensureEngine().countTokens(text) }
    }

    /** Longest reply this profile allows, once the prompt has taken its share of the context. */
    fun maxReplyTokens(promptTokens: Int): Int = minOf(profile.maxReplyTokens, profile.nCtx - promptTokens)

    /**
     * True when the phone's memory ended this reply. The caller decides first whether the *user*
     * ended it; a Stop the user pressed is never relabelled. spine: C6
     */
    fun endedForMemory(stop: StopReason, error: String?, now: Long = System.currentTimeMillis()): Boolean =
        MemoryPressure.endedForMemory(stop, error, criticalTrimAt, now, systemLowMemory())

    /**
     * Android's own answer to "is this phone out of memory right now". Unlike the trim callbacks it
     * is not deprecated and is available on every supported version, so it is what makes the
     * low-memory message work on an Android 14+ phone that never delivers a trim level.
     */
    private fun systemLowMemory(): Boolean = runCatching {
        val am = context.getSystemService(ActivityManager::class.java)
        ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }.lowMemory
    }.getOrDefault(false)

    /** Emits text pieces and one Done. Collecting on the caller's scope; cancel the collector to stop. */
    fun generate(prompt: String, maxNew: Int, isCancelled: () -> Boolean = { false }): Flow<GenerationEvent> = flow {
        idleJob?.cancel()
        val e = lock.withLock {
            val e = ensureEngine()
            e.ensureContext(ContextSpec(profile.nCtx, profile.nBatch, threads, profile.kvQ8_0))
            e
        }
        _state.value = EngineState.GENERATING
        GenerationService.start(context)
        try {
            val sampling = SamplingSpec(profile.temperature, profile.topK, profile.topP, seed = (System.nanoTime() and 0x7fffffff).toInt())
            // Stop pressed while the model loaded or the context was created: the native cancel flag is reset when a
            // generation starts, so honour the request here instead. spine: C10
            if (isCancelled()) {
                emit(GenerationEvent.Done(GenerationStats(StopReason.CANCELLED, 0, 0, 0, 0, 0, 0, null)))
                return@flow
            }
            e.generate(prompt, maxNew, sampling).collect {
                if (isCancelled()) e.cancel()  // closes the microsecond window between the check above and native start
                if (it is GenerationEvent.Done) {
                    // One line per reply: the on-device evidence for M1/M2 (no text content is logged). spine: C2
                    val st = it.stats
                    Log.i(TAG, "generation done: stop=${st.stop} prompt=${st.promptTokens} reused=${st.reusedTokens} " +
                        "generated=${st.generated} ttft=%.0f ms prefill=%.1f tok/s decode=%.1f tok/s threads=$threads profile=${profile.name}"
                            .format(st.timeToFirstTokenMs, st.prefillTokensPerSec, st.decodeTokensPerSec))
                }
                emit(it)
            }
        } finally {
            GenerationService.stop(context)
            _state.value = EngineState.READY
            if (uiVisible) scheduleIdleFree() else scope.launch { freeContext("generation finished while hidden") }
        }
    }

    fun cancel() {
        engine?.cancel()
    }

    fun onUiVisible() {
        uiVisible = true
    }

    /** Activity/process onStop. The context goes now unless a reply is still being written. */
    fun onUiHidden() {
        uiVisible = false
        if (_state.value != EngineState.GENERATING) scope.launch { freeContext("ui hidden") }
    }

    fun onTrimMemory(level: Int) {
        when (MemoryPressure.classify(level, _state.value == EngineState.GENERATING)) {
            TrimAction.NONE -> Unit  // below critical while writing: the foreground service holds us up (C10)
            TrimAction.FREE_CONTEXT -> scope.launch { freeContext("trim level $level") }
            TrimAction.FREE_MODEL -> scope.launch { freeModel("trim level $level") }
            TrimAction.STOP_FOR_MEMORY -> {
                // spine: C6 — end the reply ourselves, with a sentence the user can act on, rather than
                // let Android kill the process mid-word and leave a half-written bubble behind.
                criticalTrimAt = System.currentTimeMillis()
                Log.w(TAG, "stopping generation for memory: trim level $level")
                cancel()
            }
        }
    }

    /** Called by the service when Android's shortService time limit is hit (D-003). */
    fun onServiceTimeout() {
        if (!uiVisible) cancel()
    }

    private suspend fun ensureEngine(): LlamaEngine {
        engine?.let { if (it.hasModel()) return it }
        _state.value = EngineState.STARTING
        val e = engine ?: LlamaEngine(context).also { engine = it }
        modelSource.open().use { window -> e.loadModel(window, profile.repackWeights) }
        _state.value = EngineState.READY
        return e
    }

    private fun scheduleIdleFree() {
        idleJob?.cancel()
        idleJob = scope.launch {
            delay(Policy.CONTEXT_IDLE_MILLIS)
            freeContext("idle ${Policy.CONTEXT_IDLE_MILLIS}ms")
        }
    }

    private suspend fun freeContext(reason: String) = lock.withLock {
        val e = engine ?: return@withLock
        if (_state.value == EngineState.GENERATING) return@withLock
        if (e.hasContext()) {
            e.freeContext()
            Log.i(TAG, "context freed: $reason")
        }
    }

    private suspend fun freeModel(reason: String) = lock.withLock {
        val e = engine ?: return@withLock
        if (_state.value == EngineState.GENERATING) return@withLock
        e.freeModel()
        _state.value = EngineState.COLD
        Log.i(TAG, "model freed: $reason")
    }

    private companion object {
        const val TAG = "arivu-lifecycle"
    }
}

internal fun Context.generationServiceIntent() = Intent(this, GenerationService::class.java)
