package io.github.brettleehari.arivu.app.inference

import android.content.ComponentCallbacks2
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
import io.github.brettleehari.arivu.llama.ContextSpec
import io.github.brettleehari.arivu.llama.CpuTopology
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
 * spine: C2, C10
 */
class InferenceController(
    private val context: Context,
    private val modelSource: ModelSource,
) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val lock = Mutex()
    private var engine: LlamaEngine? = null
    private var idleJob: Job? = null
    @Volatile private var uiVisible = true

    private val _state = MutableStateFlow(EngineState.COLD)
    val state: StateFlow<EngineState> = _state.asStateFlow()

    private val threads = CpuTopology.performanceCoreCount()

    val promptBuilder = PromptBuilder(Policy.SYSTEM_PROMPT, Policy.N_CTX, Policy.REPLY_RESERVE_TOKENS) { text ->
        lock.withLock { ensureEngine().countTokens(text) }
    }

    /** Emits text pieces and one Done. Collecting on the caller's scope; cancel the collector to stop. */
    fun generate(prompt: String, maxNew: Int, isCancelled: () -> Boolean = { false }): Flow<GenerationEvent> = flow {
        idleJob?.cancel()
        val e = lock.withLock {
            val e = ensureEngine()
            e.ensureContext(ContextSpec(Policy.N_CTX, Policy.N_BATCH, threads, Policy.KV_Q8_0))
            e
        }
        _state.value = EngineState.GENERATING
        GenerationService.start(context)
        try {
            val sampling = SamplingSpec(Policy.TEMPERATURE, Policy.TOP_K, Policy.TOP_P, seed = (System.nanoTime() and 0x7fffffff).toInt())
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
                        "generated=${st.generated} ttft=%.0f ms prefill=%.1f tok/s decode=%.1f tok/s threads=$threads"
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
        when {
            _state.value == EngineState.GENERATING -> Unit  // the foreground service keeps us alive; finish first
            level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND -> scope.launch { freeModel("trim level $level") }
            level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> scope.launch { freeContext("trim level $level") }
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
        modelSource.open().use { window -> e.loadModel(window, Policy.REPACK_WEIGHTS) }
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
