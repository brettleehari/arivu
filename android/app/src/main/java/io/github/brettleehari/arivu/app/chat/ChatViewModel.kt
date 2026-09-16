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
import io.github.brettleehari.arivu.app.Policy
import io.github.brettleehari.arivu.app.inference.BuiltPrompt
import io.github.brettleehari.arivu.app.inference.EngineState
import io.github.brettleehari.arivu.app.inference.Turn
import io.github.brettleehari.arivu.llama.GenerationEvent
import io.github.brettleehari.arivu.llama.StopReason
import java.util.UUID

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
)

sealed interface Notice {
    data class TooLong(val tokens: Int, val limit: Int) : Notice
    data object LoadFailed : Notice
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
        _state.update { it.copy(messages = it.messages + user + reply, generating = true, notice = null) }
        persist()

        generation = viewModelScope.launch {
            val history = _state.value.messages.filter { it.text.isNotEmpty() }
            val built = try {
                inference.promptBuilder.build(history.map { Turn(it.id, it.fromUser, it.text) })
            } catch (e: Exception) {
                if (e is kotlinx.coroutines.CancellationException) throw e
                removeMessage(reply.id)
                _state.update { it.copy(generating = false, notice = Notice.LoadFailed) }
                persist()
                return@launch
            }
            when (built) {
                is BuiltPrompt.TooLong -> {
                    // Leave the message in place so the user can copy and shorten it.
                    removeMessage(reply.id)
                    _state.update { it.copy(generating = false, notice = Notice.TooLong(built.messageTokens, built.limitTokens)) }
                    persist()
                }
                is BuiltPrompt.Ok -> {
                    val startId = if (built.firstIncluded > 0) history[built.firstIncluded].id else null
                    _state.update { it.copy(contextStartId = startId) }
                    val maxNew = minOf(Policy.MAX_REPLY_TOKENS, Policy.N_CTX - built.promptTokens)
                    runGeneration(reply.id, built.text, maxNew)
                }
            }
        }
    }

    private suspend fun runGeneration(replyId: String, prompt: String, maxNew: Int) {
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
                    is GenerationEvent.Done -> stop = ev.stats.stop.toStop()
                }
            }
        } catch (e: Exception) {
            stop = if (e is kotlinx.coroutines.CancellationException) Stop.CANCELLED else Stop.ERROR
            if (e !is kotlinx.coroutines.CancellationException) _state.update { it.copy(notice = Notice.LoadFailed) }
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

    /** spine: C9 — the reply is marked on the phone when the user confirms the report sheet. */
    fun markReported(id: String) {
        updateMessage(id) { it.copy(reported = true) }
        persist()
    }

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
