package io.github.brettleehari.arivu.app

import android.content.ComponentCallbacks2.TRIM_MEMORY_BACKGROUND
import android.content.ComponentCallbacks2.TRIM_MEMORY_COMPLETE
import android.content.ComponentCallbacks2.TRIM_MEMORY_MODERATE
import android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL
import android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_LOW
import android.content.ComponentCallbacks2.TRIM_MEMORY_RUNNING_MODERATE
import android.content.ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN
import io.github.brettleehari.arivu.app.inference.MemoryPressure
import io.github.brettleehari.arivu.app.inference.TrimAction
import io.github.brettleehari.arivu.llama.LlamaException
import io.github.brettleehari.arivu.llama.StopReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * spine: C6 — being stopped for memory is a thing the user is told, in those words.
 * spine: C2, C10 — and telling them must not cost the lifecycle behaviour already verified on the
 * emulator: a reply survives a brief app switch, and only an idle process gives memory back.
 */
@Suppress("DEPRECATION")  // the TRIM_MEMORY_* levels below UI_HIDDEN are deprecated from API 34; see MemoryPressure.
class MemoryPressureTest {

    // --- the signal: onTrimMemory ------------------------------------------------------------

    @Test
    fun foregroundCriticalStopsTheReply() {
        assertEquals(TrimAction.STOP_FOR_MEMORY, MemoryPressure.classify(TRIM_MEMORY_RUNNING_CRITICAL, generating = true))
    }

    @Test
    fun aboutToBeKilledStopsTheReply() {
        assertEquals(TrimAction.STOP_FOR_MEMORY, MemoryPressure.classify(TRIM_MEMORY_COMPLETE, generating = true))
    }

    /** spine: C10 — the foreground service exists so a reply survives a brief app switch. */
    @Test
    fun ordinaryBackgroundTrimNeverInterruptsAReply() {
        listOf(TRIM_MEMORY_RUNNING_MODERATE, TRIM_MEMORY_RUNNING_LOW, TRIM_MEMORY_UI_HIDDEN, TRIM_MEMORY_BACKGROUND, TRIM_MEMORY_MODERATE)
            .forEach { assertEquals("level $it", TrimAction.NONE, MemoryPressure.classify(it, generating = true)) }
    }

    /** The behaviour the emulator run recorded: hidden frees the context, background frees the model (D-012). */
    @Test
    fun idleProcessGivesMemoryBackAsBefore() {
        assertEquals(TrimAction.NONE, MemoryPressure.classify(TRIM_MEMORY_RUNNING_MODERATE, generating = false))
        assertEquals(TrimAction.NONE, MemoryPressure.classify(TRIM_MEMORY_RUNNING_LOW, generating = false))
        assertEquals(TrimAction.FREE_CONTEXT, MemoryPressure.classify(TRIM_MEMORY_UI_HIDDEN, generating = false))
        assertEquals(TrimAction.FREE_CONTEXT, MemoryPressure.classify(TRIM_MEMORY_UI_HIDDEN + 1, generating = false))
        assertEquals(TrimAction.FREE_MODEL, MemoryPressure.classify(TRIM_MEMORY_BACKGROUND, generating = false))
        assertEquals(TrimAction.FREE_MODEL, MemoryPressure.classify(TRIM_MEMORY_MODERATE, generating = false))
        assertEquals(TrimAction.FREE_MODEL, MemoryPressure.classify(TRIM_MEMORY_COMPLETE, generating = false))
    }

    /** Idle in the foreground under critical pressure: hand the weights back rather than be killed. */
    @Test
    fun foregroundCriticalWhileIdleFreesTheModel() {
        assertEquals(TrimAction.FREE_MODEL, MemoryPressure.classify(TRIM_MEMORY_RUNNING_CRITICAL, generating = false))
    }

    // --- the signal: an allocation that failed -------------------------------------------------

    @Test
    fun recognisesAllocationFailuresFromEveryLayer() {
        listOf(
            "ggml_backend_cpu_buffer_type_alloc_buffer: failed to allocate buffer of size 452984832",
            "llama_init_from_model: failed to initialize the context: cannot allocate memory",
            "mmap failed: Cannot allocate memory (ENOMEM)",
            "std::bad_alloc",
            "Insufficient memory for the KV cache",
            "Out of memory",
        ).forEach { assertTrue(it, MemoryPressure.isAllocationFailure(it)) }

        assertTrue(MemoryPressure.isAllocationFailure(OutOfMemoryError("Failed to allocate a 4194304 byte allocation")))
        assertTrue(MemoryPressure.isAllocationFailure(LlamaException("context creation failed: cannot allocate memory")))
        // Wrapped one level down — how a native failure usually reaches the ViewModel.
        assertTrue(MemoryPressure.isAllocationFailure(RuntimeException("generate failed", OutOfMemoryError())))
    }

    @Test
    fun doesNotBlameMemoryForOtherFailures() {
        listOf(
            "model file not found",
            "offset 12345 is not a multiple of 32",
            "there is plenty of room in this bedroom",
            "unknown model architecture",
            null,
        ).forEach { assertFalse("$it", MemoryPressure.isAllocationFailure(it)) }
        assertFalse(MemoryPressure.isAllocationFailure(null as Throwable?))
        assertFalse(MemoryPressure.isAllocationFailure(IllegalStateException("no context")))
    }

    // --- the signal: a reply that died mid-flight after a trim ----------------------------------

    @Test
    fun replyThatDiesJustAfterACriticalTrimIsBlamedOnMemory() {
        val trim = 1_000_000L
        assertTrue(MemoryPressure.endedForMemory(StopReason.CANCELLED, null, trim, trim + 200))
        assertTrue(MemoryPressure.endedForMemory(StopReason.ERROR, null, trim, trim + MemoryPressure.ATTRIBUTION_WINDOW_MILLIS))
    }

    @Test
    fun replyThatDiesLongAfterATrimIsAnOrdinaryFailure() {
        val trim = 1_000_000L
        assertFalse(MemoryPressure.endedForMemory(StopReason.ERROR, null, trim, trim + MemoryPressure.ATTRIBUTION_WINDOW_MILLIS + 1))
        assertFalse(MemoryPressure.endedForMemory(StopReason.ERROR, null, 0L, trim))
    }

    @Test
    fun aReplyThatEndedNormallyIsNeverRelabelled() {
        val trim = 1_000_000L
        listOf(StopReason.END_OF_TURN, StopReason.CONTEXT_FULL, StopReason.MAX_TOKENS).forEach {
            assertFalse("$it", MemoryPressure.endedForMemory(it, null, trim, trim + 100))
        }
    }

    /** No trim at all, but the engine said the allocation failed: still memory, and still says so. */
    @Test
    fun anAllocationFailureAloneIsEnough() {
        assertTrue(MemoryPressure.endedForMemory(StopReason.ERROR, "failed to allocate compute buffer", 0L, 9_999_999L))
    }

    /**
     * API 34+ may deliver no trim level at all. `ActivityManager.MemoryInfo.lowMemory` still answers,
     * so a reply that dies while the system says it is low on memory is still attributed correctly.
     */
    @Test
    fun theSystemsOwnLowMemoryFlagIsEnoughWhenNoTrimArrives() {
        assertTrue(MemoryPressure.endedForMemory(StopReason.ERROR, null, 0L, 9_999_999L, systemLowMemory = true))
        assertTrue(MemoryPressure.endedForMemory(StopReason.CANCELLED, null, 0L, 9_999_999L, systemLowMemory = true))
        // ...but it never turns a reply that finished into a failure.
        assertFalse(MemoryPressure.endedForMemory(StopReason.END_OF_TURN, null, 0L, 9_999_999L, systemLowMemory = true))
        assertFalse(MemoryPressure.endedForMemory(StopReason.MAX_TOKENS, null, 0L, 9_999_999L, systemLowMemory = true))
    }
}
