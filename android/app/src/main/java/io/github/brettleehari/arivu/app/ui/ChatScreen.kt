package io.github.brettleehari.arivu.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.displayCutout
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.InterceptPlatformTextInput
import androidx.compose.ui.platform.PlatformTextInputMethodRequest
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.isCtrlPressed
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.flow.drop
import io.github.brettleehari.arivu.app.R
import io.github.brettleehari.arivu.app.chat.ChatUiState
import io.github.brettleehari.arivu.app.chat.Message
import io.github.brettleehari.arivu.app.chat.Notice
import io.github.brettleehari.arivu.app.chat.Stop
import io.github.brettleehari.arivu.app.inference.EngineState

/** Insets the Scaffold pads for; the IME is added separately so it is never counted twice. */
internal val ScreenInsets: WindowInsets
    @Composable get() = WindowInsets.systemBars.union(WindowInsets.displayCutout)

internal val TopBarInsets: WindowInsets
    @Composable get() = WindowInsets.safeDrawing.only(WindowInsetsSides.Horizontal + WindowInsetsSides.Top)

/** The single screen: message list, input, Send, Stop, Copy. Nothing else (SPINE §3, R5). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    state: ChatUiState,
    onSend: (String) -> Unit,
    onStop: () -> Unit,
    onAbout: () -> Unit,
    onDismissNotice: () -> Unit,
    onReported: (String) -> Unit,
) {
    var input by rememberSaveable { mutableStateOf("") }
    // spine: C9 — id of the reply whose report sheet is open; saveable so rotation keeps the sheet.
    var reportingId by rememberSaveable { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()
    val lastId = state.messages.lastOrNull()?.id

    // Follow the newest line only while the user is at the bottom. Scrolling up to read an older or
    // very long message stops the follow; scrolling back to the end (or sending) resumes it.
    var follow by remember { mutableStateOf(true) }
    LaunchedEffect(listState) {
        snapshotFlow { listState.isScrollInProgress }.drop(1).collect { scrolling ->
            if (!scrolling) follow = !listState.canScrollForward
        }
    }
    LaunchedEffect(lastId) { if (state.messages.lastOrNull()?.fromUser == true) follow = true }
    // Also keyed on generating/stop/reported: when a reply ends, its label and Copy/Report row appear without the text
    // changing, and must be scrolled into view too (found on the emulator run: "Stopped" was clipped under the input).
    val last = state.messages.lastOrNull()
    LaunchedEffect(state.messages.size, last?.text?.length, last?.stop, last?.reported, state.generating, follow) {
        // Offset past the end is clamped by the list: lands on the last line of a long reply, not its top.
        if (follow && !listState.isScrollInProgress && state.messages.isNotEmpty()) listState.scrollToItem(state.messages.size - 1, Int.MAX_VALUE)
    }

    val send = {
        if (input.isNotBlank() && !state.generating) {
            onSend(input)
            input = ""
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.app_name), maxLines = 1, overflow = TextOverflow.Ellipsis) },
                actions = { TextButton(onClick = onAbout) { Text(stringResource(R.string.about)) } },
                windowInsets = TopBarInsets,
            )
        },
        contentWindowInsets = ScreenInsets,
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .consumeWindowInsets(padding)
                .imePadding(),
        ) {
            if (!state.loaded) {
                // History is still being read from disk: show nothing rather than flash the empty state.
                Box(Modifier.weight(1f).fillMaxWidth())
            } else if (state.messages.isEmpty()) {
                EmptyState(Modifier.weight(1f))
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.weight(1f).fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(state.messages, key = { it.id }) { m ->
                        if (m.id == state.contextStartId) ContextDivider()
                        MessageBubble(
                            m,
                            streaming = state.generating && m.id == lastId && !m.fromUser,
                            engine = state.engine,
                            onReport = { reportingId = m.id },
                        )
                    }
                }
            }

            reportingId?.let { id ->
                val reply = state.messages.firstOrNull { it.id == id }
                if (reply == null) {
                    reportingId = null
                } else {
                    ReportSheet(replyText = reply.text, onDismiss = { reportingId = null }, onReported = { onReported(id) })
                }
            }

            ReplyStatusAnnouncer(state)
            state.notice?.let { NoticeBar(it, onDismissNotice) }

            val compact = with(LocalDensity.current) { LocalWindowInfo.current.containerSize.height.toDp() } < 480.dp
            Row(
                Modifier.fillMaxWidth().padding(12.dp),
                verticalAlignment = Alignment.Bottom,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                NoPersonalizedLearning {
                OutlinedTextField(
                    value = input,
                    onValueChange = { input = it },
                    modifier = Modifier
                        .weight(1f)
                        // Enter is a new line (pasted text has paragraphs); Ctrl+Enter sends on a hardware keyboard.
                        .onPreviewKeyEvent {
                            if (it.type == KeyEventType.KeyDown && it.key == Key.Enter && it.isCtrlPressed) {
                                send(); true
                            } else {
                                false
                            }
                        },
                    placeholder = { Text(stringResource(R.string.input_hint)) },
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    maxLines = if (compact) 3 else 6,
                )
                }
                // spine: C10 — Send and Stop share one slot, same size; there is never a moment with neither.
                val slot = Modifier.heightIn(min = 56.dp).defaultMinSize(minWidth = 88.dp)
                if (state.generating) {
                    val stopDescription = stringResource(R.string.a11y_stop)
                    OutlinedButton(onClick = onStop, modifier = slot.semantics { contentDescription = stopDescription }) {
                        Text(stringResource(R.string.stop))
                    }
                } else {
                    Button(onClick = send, enabled = input.isNotBlank() && state.loaded, modifier = slot) {
                        Text(stringResource(R.string.send))
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyState(modifier: Modifier) {
    // Scrolls so the whole honesty statement (C5) stays readable at 200% text or with the keyboard open.
    BoxWithConstraints(modifier.fillMaxWidth()) {
        Column(
            Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .heightIn(min = maxHeight)
                .padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                stringResource(R.string.empty_title),
                style = MaterialTheme.typography.titleLarge,
                textAlign = TextAlign.Center,
                modifier = Modifier.semantics { heading() },
            )
            Text(
                stringResource(R.string.empty_body),
                style = MaterialTheme.typography.bodyMedium,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 12.dp),
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Text(
                stringResource(R.string.empty_examples_label),
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 20.dp),
            )
            // Examples are plain text, not buttons (D-011 sibling; see leaves/design.md open questions).
            Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(R.string.empty_example_1, R.string.empty_example_2, R.string.empty_example_3).forEach {
                    Text(
                        stringResource(it),
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .background(MaterialTheme.colorScheme.surfaceVariant, RoundedCornerShape(8.dp))
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    )
                }
            }
        }
    }
}

/** spine: C7 — the visible edge of what the model can see. */
@Composable
private fun ContextDivider() {
    Column(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        HorizontalDivider(color = MaterialTheme.colorScheme.outline)
        Text(
            stringResource(R.string.context_divider),
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun MessageBubble(m: Message, streaming: Boolean, engine: EngineState, onReport: () -> Unit) {
    val context = LocalContext.current
    val copiedText = stringResource(R.string.copied)
    val clipLabel = stringResource(R.string.app_name)
    val copyDescription = stringResource(R.string.a11y_copy_message)
    val writing = stringResource(R.string.a11y_writing)
    val reportDescription = stringResource(R.string.a11y_report_reply)
    Box(
        Modifier
            .fillMaxWidth()
            // Start/end, not left/right: mirrors correctly in RTL.
            .padding(start = if (m.fromUser) 40.dp else 0.dp, end = if (m.fromUser) 0.dp else 24.dp),
        contentAlignment = if (m.fromUser) Alignment.CenterEnd else Alignment.CenterStart,
    ) {
        Surface(
            color = if (m.fromUser) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
            shape = RoundedCornerShape(14.dp),
            modifier = Modifier.widthIn(max = 560.dp),
        ) {
            Column(Modifier.padding(start = 12.dp, end = 12.dp, top = 8.dp, bottom = if (m.text.isNotEmpty() && !streaming) 0.dp else 8.dp)) {
                if (m.text.isEmpty() && streaming) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        CircularProgressIndicator(Modifier.size(16.dp).clearAndSetSemantics {}, strokeWidth = 2.dp)
                        Text(
                            stringResource(if (engine == EngineState.STARTING) R.string.state_starting else R.string.state_reading),
                            style = MaterialTheme.typography.bodyMedium,
                        )
                    }
                } else if (m.text.isNotEmpty()) {
                    val spoken = stringResource(if (m.fromUser) R.string.a11y_from_user else R.string.a11y_from_arivu, m.text)
                    SelectionContainer {
                        Text(
                            m.text,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.semantics {
                                contentDescription = spoken
                                if (streaming) stateDescription = writing
                            },
                        )
                    }
                }
                stopLabel(m.stop)?.let {
                    Text(
                        stringResource(it),
                        style = MaterialTheme.typography.labelMedium,
                        color = if (m.stop == Stop.ERROR || m.stop == Stop.CONTEXT_FULL) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                if (!m.fromUser && m.reported) {
                    Text(
                        stringResource(R.string.reported),
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }
                if (m.text.isNotEmpty() && !streaming) {
                  Row(Modifier.align(Alignment.End), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    if (!m.fromUser) {
                        // spine: C9 — Report sits on the reply itself, next to Copy (Play AI-generated content policy).
                        TextButton(
                            onClick = onReport,
                            contentPadding = ButtonDefaults.TextButtonContentPadding,
                            modifier = Modifier.semantics { contentDescription = reportDescription },
                        ) { Text(stringResource(R.string.report), style = MaterialTheme.typography.labelLarge) }
                    }
                    TextButton(
                        onClick = {
                            val cm = context.getSystemService(ClipboardManager::class.java)
                            cm.setPrimaryClip(ClipData.newPlainText(clipLabel, m.text))
                            // Android 13+ shows its own clipboard confirmation.
                            if (android.os.Build.VERSION.SDK_INT < 33) Toast.makeText(context, copiedText, Toast.LENGTH_SHORT).show()
                        },
                        contentPadding = ButtonDefaults.TextButtonContentPadding,
                        modifier = Modifier.semantics { contentDescription = copyDescription },
                    ) { Text(stringResource(R.string.copy), style = MaterialTheme.typography.labelLarge) }
                  }
                }
            }
        }
    }
}

/**
 * spine: C3 — asks the keyboard app not to learn from what is typed here (EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING;
 * Compose's KeyboardOptions cannot set imeOptions flags, so the platform input request is wrapped).
 * Honoured by Gboard; other keyboards may ignore it (threat-model T14).
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun NoPersonalizedLearning(content: @Composable () -> Unit) {
    InterceptPlatformTextInput(
        interceptor = { request, nextHandler ->
            val wrapped = object : PlatformTextInputMethodRequest {
                override fun createInputConnection(outAttributes: EditorInfo): InputConnection =
                    request.createInputConnection(outAttributes).also {
                        outAttributes.imeOptions = outAttributes.imeOptions or EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING
                    }
            }
            nextHandler.startInputMethod(wrapped)
        },
        content = content,
    )
}

/**
 * One persistent, invisible live region for screen-reader users: says when Arivu starts writing and
 * how the reply ended. Per-token text is deliberately not live (it would read every word twice).
 * spine: C7, C10
 */
@Composable
private fun ReplyStatusAnnouncer(state: ChatUiState) {
    var sawGeneration by remember { mutableStateOf(false) }
    LaunchedEffect(state.generating) { if (state.generating) sawGeneration = true }
    val last = state.messages.lastOrNull()
    val status = when {
        state.generating -> stringResource(R.string.a11y_writing)
        !sawGeneration || last == null || last.fromUser -> ""
        else -> stopLabel(last.stop)?.let { stringResource(it) } ?: stringResource(R.string.a11y_reply_done)
    }
    Box(
        Modifier.size(1.dp).semantics {
            liveRegion = LiveRegionMode.Polite
            contentDescription = status
        },
    )
}

private fun stopLabel(stop: Stop?): Int? = when (stop) {
    null, Stop.END_OF_TURN -> null
    Stop.CANCELLED -> R.string.stopped_by_user
    Stop.CONTEXT_FULL -> R.string.stopped_context_full
    Stop.MAX_TOKENS -> R.string.stopped_max_tokens
    Stop.ERROR -> R.string.stopped_error
}

@Composable
private fun NoticeBar(notice: Notice, onDismiss: () -> Unit) {
    val text = when (notice) {
        // Users are not shown token counts; they are told how much shorter to make it. spine: C7
        is Notice.TooLong -> stringResource(
            R.string.message_too_long,
            (notice.limit * 100 / notice.tokens.coerceAtLeast(1)).coerceIn(1, 99),
        )
        Notice.LoadFailed -> stringResource(R.string.load_failed)
    }
    Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
        Row(
            Modifier.padding(horizontal = 12.dp, vertical = 8.dp).semantics { liveRegion = LiveRegionMode.Polite },
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text, Modifier.weight(1f), color = MaterialTheme.colorScheme.onErrorContainer, style = MaterialTheme.typography.bodyMedium)
            TextButton(onClick = onDismiss, colors = ButtonDefaults.textButtonColors(contentColor = MaterialTheme.colorScheme.onErrorContainer)) {
                Text(stringResource(R.string.ok))
            }
        }
    }
}
