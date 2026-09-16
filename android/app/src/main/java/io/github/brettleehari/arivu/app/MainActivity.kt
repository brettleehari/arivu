package io.github.brettleehari.arivu.app

import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import io.github.brettleehari.arivu.app.chat.ChatViewModel
import io.github.brettleehari.arivu.app.gate.CompatibilityGate
import io.github.brettleehari.arivu.app.gate.GateResult
import io.github.brettleehari.arivu.app.ui.AboutScreen
import io.github.brettleehari.arivu.app.ui.ArivuTheme
import io.github.brettleehari.arivu.app.ui.ChatScreen
import io.github.brettleehari.arivu.app.ui.IncompatibleScreen

class MainActivity : ComponentActivity() {
    private val vm: ChatViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // spine: C3 — the recents thumbnail would otherwise show a private letter or contract to whoever picks
        // up the phone next (threat-model T13). API 33+.
        if (Build.VERSION.SDK_INT >= 33) setRecentsScreenshotEnabled(false)

        // Gate before anything can touch the model (leaves/BRIEF.md "Run this check before any model load").
        val fake = intent.takeIf { BuildConfig.DEBUG && it.hasExtra(EXTRA_FAKE_TOTAL_MEM) }?.getLongExtra(EXTRA_FAKE_TOTAL_MEM, 0L)
        val gate = CompatibilityGate.check(this, fake)

        setContent {
            ArivuTheme {
                when (gate) {
                    is GateResult.Fail -> IncompatibleScreen(gate.failure)
                    GateResult.Pass -> ChatRoot()
                }
            }
        }
    }

    @androidx.compose.runtime.Composable
    private fun ChatRoot() {
        val state by vm.state.collectAsStateWithLifecycle()
        var showAbout by rememberSaveable { mutableStateOf(false) }

        if (showAbout) {
            BackHandler { showAbout = false }
            AboutScreen(onBack = { showAbout = false })
        } else {
            ChatScreen(
                state = state,
                onSend = vm::send,
                onStop = vm::stop,
                onAbout = { showAbout = true },
                onDismissNotice = vm::dismissNotice,
                onReported = vm::markReported,
            )
        }
    }

    private companion object {
        const val EXTRA_FAKE_TOTAL_MEM = "arivu.fakeTotalMem"
    }
}
