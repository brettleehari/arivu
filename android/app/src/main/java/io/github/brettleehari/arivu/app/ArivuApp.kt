// spine: C2 — process-wide lifecycle wiring: UI visibility and trim-memory go to InferenceController.
package io.github.brettleehari.arivu.app

import android.app.Application
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import io.github.brettleehari.arivu.app.chat.ChatRepository
import io.github.brettleehari.arivu.app.inference.InferenceController
import io.github.brettleehari.arivu.app.model.PadInstallTimeModelSource
import java.io.File

class ArivuApp : Application() {
    val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    // Constructing these touches no native code and loads no model (leaves/BRIEF.md "never at app start").
    val inference: InferenceController by lazy { InferenceController(this, PadInstallTimeModelSource(this)) }
    val chatRepository: ChatRepository by lazy { ChatRepository(File(filesDir, "conversation.json")) }

    override fun onCreate() {
        super.onCreate()
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStart(owner: LifecycleOwner) = inference.onUiVisible()
            override fun onStop(owner: LifecycleOwner) = inference.onUiHidden()
        })
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        inference.onTrimMemory(level)
    }
}
