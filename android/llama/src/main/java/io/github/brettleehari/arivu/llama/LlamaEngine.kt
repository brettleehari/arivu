// spine: C2, C10 — single-thread engine owner: lazy load, streaming, cancel at any token.
package io.github.brettleehari.arivu.llama

import android.content.Context
import android.os.ParcelFileDescriptor
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.launch
import kotlinx.coroutines.newSingleThreadContext
import kotlinx.coroutines.withContext
import java.io.Closeable

/** Where the GGUF bytes live: a window of an open file (e.g. an uncompressed APK asset). */
class ModelWindow(val pfd: ParcelFileDescriptor, val offset: Long, val length: Long) : Closeable {
    override fun close() = pfd.close()
}

data class ContextSpec(
    val nCtx: Int,
    val nBatch: Int,
    val nThreads: Int,
    val kvQ8: Boolean,
)

data class SamplingSpec(
    val temperature: Float,
    val topK: Int,
    val topP: Float,
    val seed: Int,
)

enum class StopReason { END_OF_TURN, CANCELLED, CONTEXT_FULL, MAX_TOKENS, ERROR }

data class GenerationStats(
    val stop: StopReason,
    val promptTokens: Int,
    val reusedTokens: Int,
    val generated: Int,
    val prefillMicros: Long,
    val decodeMicros: Long,
    /** generate() to first visible text. Add model load time for a cold-start figure (M1). */
    val firstTokenMicros: Long,
    val error: String?,
) {
    val prefillTokensPerSec: Double
        get() = if (prefillMicros > 0) (promptTokens - reusedTokens) * 1e6 / prefillMicros else 0.0
    val timeToFirstTokenMs: Double
        get() = firstTokenMicros / 1000.0

    val decodeTokensPerSec: Double
        get() = if (decodeMicros > 0) generated * 1e6 / decodeMicros else 0.0
}

sealed interface GenerationEvent {
    data class Text(val text: String) : GenerationEvent
    data class Done(val stats: GenerationStats) : GenerationEvent
}

class LlamaException(message: String) : RuntimeException(message)

/**
 * Owns one native engine. All native calls except [cancel] run on a single dedicated thread,
 * so model/context lifetime changes can never race a running decode.
 */
@OptIn(ExperimentalCoroutinesApi::class, kotlinx.coroutines.DelicateCoroutinesApi::class)
class LlamaEngine(context: Context) : Closeable {
    private val thread: CoroutineDispatcher = newSingleThreadContext("arivu-llama")
    private val handle: Long

    init {
        LlamaNative.nativeInit(context.applicationInfo.nativeLibraryDir)
        handle = LlamaNative.nativeCreate()
    }

    suspend fun loadModel(window: ModelWindow, repack: Boolean = false) = withContext(thread) {
        val err = arrayOfNulls<String>(1)
        if (!LlamaNative.nativeLoadModelFd(handle, window.pfd.fd, window.offset, window.length, repack, err)) {
            throw LlamaException(err[0] ?: "model load failed")
        }
    }

    suspend fun loadModel(path: String, repack: Boolean = false) = withContext(thread) {
        val err = arrayOfNulls<String>(1)
        if (!LlamaNative.nativeLoadModelPath(handle, path, repack, err)) {
            throw LlamaException(err[0] ?: "model load failed")
        }
    }

    suspend fun hasModel(): Boolean = withContext(thread) { LlamaNative.nativeHasModel(handle) }
    suspend fun hasContext(): Boolean = withContext(thread) { LlamaNative.nativeHasContext(handle) }

    suspend fun ensureContext(spec: ContextSpec) = withContext(thread) {
        val err = arrayOfNulls<String>(1)
        if (!LlamaNative.nativeEnsureContext(handle, spec.nCtx, spec.nBatch, spec.nThreads, spec.kvQ8, err)) {
            throw LlamaException(err[0] ?: "context creation failed")
        }
    }

    /** Frees the KV cache and compute buffers. The mmap'd weights stay. */
    suspend fun freeContext() = withContext(thread) { LlamaNative.nativeFreeContext(handle) }

    /** Frees context and weights. */
    suspend fun freeModel() = withContext(thread) { LlamaNative.nativeFreeModel(handle) }

    suspend fun countTokens(text: String): Int =
        withContext(thread) { LlamaNative.nativeCountTokens(handle, text.toByteArray(Charsets.UTF_8)) }

    /** Thread-safe; takes effect mid-prefill or at the next token. */
    fun cancel() = LlamaNative.nativeCancel(handle)

    fun generate(prompt: String, maxNewTokens: Int, sampling: SamplingSpec): Flow<GenerationEvent> = callbackFlow {
        val job = launch {
            val err = arrayOfNulls<String>(1)
            val r = LlamaNative.nativeGenerate(
                handle, prompt.toByteArray(Charsets.UTF_8), maxNewTokens,
                sampling.temperature, sampling.topK, sampling.topP, sampling.seed,
                { bytes -> trySend(GenerationEvent.Text(String(bytes, Charsets.UTF_8))) },
                err,
            )
            trySend(
                GenerationEvent.Done(
                    GenerationStats(
                        // getOrNull, not [ordinal]. The index comes from the C enum, so a stop
                        // reason added to core/include/arivu/arivu.h would throw
                        // IndexOutOfBoundsException here and take the reply with it. iOS already
                        // degrades — `StopReason(rawValue:) ?? .error` — and the two platforms must
                        // not differ in whether a core change crashes the app (spine: C11).
                        stop = StopReason.entries.getOrNull(r[0].toInt()) ?: StopReason.ERROR,
                        promptTokens = r[1].toInt(),
                        reusedTokens = r[2].toInt(),
                        generated = r[3].toInt(),
                        prefillMicros = r[4],
                        decodeMicros = r[5],
                        firstTokenMicros = r[6],
                        error = err[0],
                    ),
                ),
            )
            close()
        }
        awaitClose {
            if (job.isActive) cancel()
        }
    }.flowOn(thread)

    override fun close() {
        LlamaNative.nativeCancel(handle)
        LlamaNative.nativeDestroy(handle)
        (thread as? Closeable)?.close()
    }

    companion object {
        /** VmRSS and VmHWM of this process, in kB. */
        fun memoryKb(): Pair<Long, Long> = LlamaNative.nativeMemoryKb().let { it[0] to it[1] }

        /** Compute (scratch) buffer llama.cpp reserved for the most recent context, in KiB; -1 before any. */
        fun computeBufferKib(): Long = LlamaNative.nativeMemoryKb()[2]
    }
}
