package io.github.brettleehari.arivu.app.chat

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.github.brettleehari.arivu.app.ArivuApp
import io.github.brettleehari.arivu.app.inference.BuiltPrompt
import io.github.brettleehari.arivu.app.inference.EngineState
import io.github.brettleehari.arivu.app.inference.MemoryPressure
import io.github.brettleehari.arivu.app.inference.Turn
import io.github.brettleehari.arivu.llama.GenerationEvent
import io.github.brettleehari.arivu.llama.StopReason
import java.util.UUID

/**
 * A send that failed before the model wrote anything, offered back to the input box (D-060).
 *
 * An *offer*, not an action: the view model cannot see the input field, so it cannot know whether
 * taking the text back would overwrite something the user has since typed. The screen answers with
 * [ChatViewModel.acceptRetry] or [ChatViewModel.declineRetry], and only an accept removes anything
 * from the conversation. Declining leaves the message where it was — the behaviour this replaces —
 * so the worst case is the old behaviour rather than lost words.
 */
data class PendingRetry(val text: String, val userId: String, val replyId: String)

data class ChatUiState(
    /** False until history has been read from disk, so returning users never see the empty state flash. */
    val loaded: Boolean = false,
    val messages: List<Message> = emptyList(),
    /** Id of the oldest message the model saw on the last send; null when nothing was dropped. spine: C7 */
    val contextStartId: String? = null,
    val generating: Boolean = false,
    val engine: EngineState = EngineState.COLD,
    /** Transient notice shown above the input (e.g. message too long). */
    val notice: Notice? = null,
    /** Set when a send failed before the model wrote anything. spine: C1, C6 (D-060) */
    val pendingRetry: PendingRetry? = null,
)

sealed interface Notice {
    data class TooLong(val tokens: Int, val limit: Int) : Notice
    data object LoadFailed : Notice

    /** The phone ran out of memory before Arivu could start or finish. spine: C6 */
    data object LowMemory : Notice
}

class ChatViewModel(app: Application) : AndroidViewModel(app) {
    private val arivu = app as ArivuApp
    private val repo = arivu.chatRepository
    private val inference = arivu.inference

    private val _state = MutableStateFlow(ChatUiState())
    val state: StateFlow<ChatUiState> = _state.asStateFlow()

    private var generation: Job? = null

    init {
        viewModelScope.launch {
            val loaded = withContext(Dispatchers.IO) { repo.load() }
            // A reply interrupted by process death is kept, and marked as stopped.
            val repaired = loaded.map { if (!it.fromUser && it.stop == null) it.copy(stop = Stop.CANCELLED) else it }
            _state.update { it.copy(messages = repaired + it.messages, loaded = true) }
        }
        viewModelScope.launch {
            inference.state.collect { s -> _state.update { it.copy(engine = s) } }
        }
    }

    /** Set by Stop; checked before generation starts and on every event, so Stop works during model load too. spine: C10 */
    @Volatile private var stopRequested = false

    fun send(text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty() || _state.value.generating || !_state.value.loaded) return
        stopRequested = false
        val now = System.currentTimeMillis()
        val user = Message(UUID.randomUUID().toString(), fromUser = true, text = trimmed, createdAt = now)
        // The reply bubble exists from the first moment, so "Starting Arivu…" shows while the model loads and the
        // prompt is measured (spine: C1). Before the emulator run it was only added after both had finished.
        val reply = Message(UUID.randomUUID().toString(), fromUser = false, text = "", createdAt = now)
        _state.update { it.copy(messages = it.messages + user + reply, generating = true, notice = null, pendingRetry = null) }
        persist()

        generation = viewModelScope.launch {
            val history = _state.value.messages.filter { it.text.isNotEmpty() }
            val built = try {
                inference.promptBuilder.build(history.map { Turn(it.id, it.fromUser, it.text) })
            } catch (e: Throwable) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                // spine: C6 — an allocation that failed is the phone being full, not Arivu being broken,
                // and the user is told which of the two it was.
                _state.update { it.copy(generating = false, notice = noticeFor(e)) }
                offerRetry(reply.id, user.id)
                persist()
                return@launch
            }
            when (built) {
                is BuiltPrompt.TooLong -> {
                    // Back to the input, where it can actually be shortened. It used to be left in
                    // the conversation "so the user can copy and shorten it" — but a bubble has no
                    // cursor, and the notice asked for an edit there was no way to make (D-060).
                    _state.update { it.copy(generating = false, notice = Notice.TooLong(built.messageTokens, built.limitTokens)) }
                    offerRetry(reply.id, user.id)
                    persist()
                }
                is BuiltPrompt.Ok -> {
                    val startId = if (built.firstIncluded > 0) history[built.firstIncluded].id else null
                    _state.update { it.copy(contextStartId = startId) }
                    val maxNew = inference.maxReplyTokens(built.promptTokens)
                    runGeneration(reply.id, user.id, built.text, maxNew)
                }
            }
        }
    }

    private suspend fun runGeneration(replyId: String, userId: String, prompt: String, maxNew: Int) {
        var stop = Stop.ERROR
        var lastSave = System.currentTimeMillis()
        try {
            inference.generate(prompt, maxNew) { stopRequested }.collect { ev ->
                when (ev) {
                    is GenerationEvent.Text -> {
                        updateMessage(replyId) { it.copy(text = it.text + ev.text) }
                        // spine: C7 — a reply cut short by process death keeps what was written (design.md). Throttled:
                        // one small file write every couple of seconds, not per token.
                        val now = System.currentTimeMillis()
                        if (now - lastSave >= STREAM_SAVE_MILLIS) { lastSave = now; persist() }
                    }
                    is GenerationEvent.Done -> {
                        stop = ev.stats.stop.toStop()
                        // The user's own Stop is never relabelled; anything else that died next to a
                        // critical trim, or on a failed allocation, says so plainly. spine: C6
                        if (!stopRequested && inference.endedForMemory(ev.stats.stop, ev.stats.error)) stop = Stop.LOW_MEMORY
                    }
                }
            }
        } catch (e: Throwable) {
            when {
                e is kotlinx.coroutines.CancellationException -> stop = Stop.CANCELLED
                MemoryPressure.isAllocationFailure(e) -> stop = Stop.LOW_MEMORY
                else -> {
                    stop = Stop.ERROR
                    _state.update { it.copy(notice = Notice.LoadFailed) }
                    // Nothing was written, so the whole send can be offered back (D-060).
                    offerRetry(replyId, userId)
                }
            }
        } finally {
            updateMessage(replyId) { it.copy(stop = stop, text = it.text.trimEnd()) }
            _state.update { it.copy(generating = false) }
            persist()
        }
    }

    fun stop() {
        stopRequested = true
        inference.cancel()
    }

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    // ---- Retrying a send that failed before anything was written (D-060) ----

    /**
     * The screen took the text into its input: drop the unanswered pair from the conversation, so
     * the user is not left looking at a message with no reply beside a copy of it they are about to
     * send again.
     */
    fun acceptRetry() {
        val retry = _state.value.pendingRetry ?: return
        _state.update { s ->
            s.copy(messages = s.messages.filterNot { it.id == retry.replyId || it.id == retry.userId },
                   pendingRetry = null)
        }
        persist()
    }

    /**
     * The screen could not take it — the user has typed something else since. Leave the conversation
     * exactly as it was: the message stays visible and copyable, which is what happened before D-060
     * and is the one outcome that cannot lose anything.
     */
    fun declineRetry() = _state.update { it.copy(pendingRetry = null) }

    /**
     * Refuses if anything was written: a reply with text in it is kept and labelled (spine: C7), and
     * resuming that is D-032, not this.
     */
    private fun offerRetry(replyId: String, userId: String) {
        val messages = _state.value.messages
        val reply = messages.firstOrNull { it.id == replyId } ?: return
        val user = messages.firstOrNull { it.id == userId } ?: return
        if (reply.text.isNotEmpty() || user.text.isEmpty()) return
        _state.update { it.copy(pendingRetry = PendingRetry(user.text, userId, replyId)) }
    }

    /** spine: C9 — the reply is marked on the phone when the user confirms the report sheet. */
    fun markReported(id: String) {
        updateMessage(id) { it.copy(reported = true) }
        persist()
    }

    /** spine: C6 — the phone being out of memory gets its own sentence, not the generic one. */
    private fun noticeFor(t: Throwable): Notice =
        if (MemoryPressure.isAllocationFailure(t)) Notice.LowMemory else Notice.LoadFailed

    private fun removeMessage(id: String) = _state.update { s -> s.copy(messages = s.messages.filterNot { it.id == id }) }

    private fun updateMessage(id: String, f: (Message) -> Message) =
        _state.update { s -> s.copy(messages = s.messages.map { if (it.id == id) f(it) else it }) }

    private fun persist() {
        val snapshot = _state.value.messages
        arivu.ioScope.launch { repo.save(snapshot) }
    }

    private companion object {
        const val STREAM_SAVE_MILLIS = 2_000L
    }

    private fun StopReason.toStop() = when (this) {
        StopReason.END_OF_TURN -> Stop.END_OF_TURN
        StopReason.CANCELLED -> Stop.CANCELLED
        StopReason.CONTEXT_FULL -> Stop.CONTEXT_FULL
        StopReason.MAX_TOKENS -> Stop.MAX_TOKENS
        StopReason.ERROR -> Stop.ERROR
    }
}
