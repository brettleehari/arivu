// spine: C2, C6 — when the phone runs out of memory, Arivu says so in those words and stays usable.
package io.github.brettleehari.arivu.app.inference

import android.content.ComponentCallbacks2
import io.github.brettleehari.arivu.llama.StopReason

/** What a trim callback should make the controller do. */
enum class TrimAction {
    NONE,

    /** Release the KV cache and compute buffers; the mmap'd weights stay. */
    FREE_CONTEXT,

    /** Release weights as well (they are file-backed, so this is cheap to undo). */
    FREE_MODEL,

    /** Stop the reply being written and tell the user why, rather than be killed mid-word. */
    STOP_FOR_MEMORY,
}

/**
 * Pure rules for Android's memory signals. Pure so they can be tested without a device: the
 * emulator and the test phone both misreport memory pressure (leaves/NOTES.md), so the *decision*
 * has to be verifiable on its own.
 */
object MemoryPressure {
    /**
     * A reply that ends badly within this long after a critical trim was ended by the phone, not by
     * the model. Wide enough to cover a prefill that was already in flight, short enough that an
     * unrelated failure a minute later is still reported as an ordinary error.
     */
    const val ATTRIBUTION_WINDOW_MILLIS = 15_000L

    /**
     * [level] is a `ComponentCallbacks2.TRIM_MEMORY_*` value; [generating] is whether a reply is
     * being written right now.
     *
     * The two foreground-critical levels — `RUNNING_CRITICAL` (the system is about to start killing
     * processes) and `COMPLETE` (we are next) — are the only ones that stop a reply. Everything
     * below them keeps the behaviour the emulator run verified: a reply survives a brief app
     * switch because the foreground service holds it up (spine: C10), and only an idle process
     * gives its context or weights back (D-012).
     *
     * Every level except `UI_HIDDEN` is deprecated from API 34 and may never be delivered, which is
     * why it is not the only signal: [isAllocationFailure] and the system's own low-memory flag
     * ([endedForMemory]'s `systemLowMemory`) work on every version. This one is the early warning,
     * cheap when it arrives and harmless when it does not.
     */
    @Suppress("DEPRECATION")
    fun classify(level: Int, generating: Boolean): TrimAction = when {
        level == ComponentCallbacks2.TRIM_MEMORY_RUNNING_CRITICAL || level >= ComponentCallbacks2.TRIM_MEMORY_COMPLETE ->
            if (generating) TrimAction.STOP_FOR_MEMORY else TrimAction.FREE_MODEL
        generating -> TrimAction.NONE
        level >= ComponentCallbacks2.TRIM_MEMORY_BACKGROUND -> TrimAction.FREE_MODEL
        level >= ComponentCallbacks2.TRIM_MEMORY_UI_HIDDEN -> TrimAction.FREE_CONTEXT
        else -> TrimAction.NONE
    }

    /**
     * True when a throwable — or anything that caused it — is the phone running out of memory
     * rather than Arivu being broken. Covers the JVM's own error and the native allocator's
     * message, which reaches Kotlin as a [io.github.brettleehari.arivu.llama.LlamaException] string.
     */
    fun isAllocationFailure(t: Throwable?): Boolean {
        var cause = t
        var depth = 0
        while (cause != null && depth < 8) {
            if (cause is OutOfMemoryError || isAllocationFailure(cause.message)) return true
            cause = cause.cause
            depth++
        }
        return false
    }

    /** True when an engine error string names an allocation that failed. */
    fun isAllocationFailure(message: String?): Boolean {
        val m = message?.lowercase() ?: return false
        return NEEDLES.any { it in m }
    }

    /**
     * True when the phone's memory, not the user and not the model, ended this reply. Three signals,
     * because no one of them is available everywhere:
     *  - the engine said an allocation failed — the only signal that is always exact;
     *  - a critical trim landed within [ATTRIBUTION_WINDOW_MILLIS] ([criticalTrimAt] is 0 when none
     *    has been seen), which API 34+ may never deliver;
     *  - [systemLowMemory] — `ActivityManager.MemoryInfo.lowMemory`, read at the moment the reply
     *    died, which every version still answers.
     *
     * The last two only reinterpret a reply that already failed or was cancelled by something other
     * than the user. A user-requested Stop is decided before this is asked (ChatViewModel): the
     * user's own action is never relabelled, and a reply that finished is never called a failure.
     */
    fun endedForMemory(
        stop: StopReason,
        error: String?,
        criticalTrimAt: Long,
        now: Long,
        systemLowMemory: Boolean = false,
    ): Boolean = when {
        isAllocationFailure(error) -> true
        stop != StopReason.ERROR && stop != StopReason.CANCELLED -> false
        systemLowMemory -> true
        else -> criticalTrimAt > 0L && now - criticalTrimAt in 0..ATTRIBUTION_WINDOW_MILLIS
    }

    /**
     * Substrings, not patterns: llama.cpp, ggml, the NDK allocator and the JVM each phrase this
     * differently, and none of them is going to standardise. Deliberately excludes bare "oom",
     * which matches "room" and "zoom".
     */
    private val NEEDLES = listOf(
        "out of memory",
        "enomem",
        "cannot allocate",
        "can't allocate",
        "failed to allocate",
        "unable to allocate",
        "alloc failed",
        "allocation failed",
        "insufficient memory",
        "not enough memory",
        "mmap failed",
        "bad_alloc",
    )
}
