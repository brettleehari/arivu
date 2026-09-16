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
import io.github.brettleehari.arivu.app.profile.DeviceProbe
import io.github.brettleehari.arivu.app.profile.Profile
import io.github.brettleehari.arivu.app.profile.ProfileSelector
import java.io.File

class ArivuApp : Application() {
    val ioScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /**
     * What this phone can carry, and the profile chosen from it — read once, on first use, and never
     * again. Nothing branches on the platform; an 8GB Android phone and an 8GB iPhone run the same
     * selection over the same catalogue. spine: C11
     */
    private val deviceProbe: DeviceProbe by lazy { DeviceProbe.of(this) }
    val profile: Profile by lazy { ProfileSelector.select(deviceProbe) }

    // Constructing these touches no native code and loads no model (leaves/BRIEF.md "never at app start").
    val inference: InferenceController by lazy {
        InferenceController(this, PadInstallTimeModelSource(this, profile.modelAsset), profile, deviceProbe)
    }
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
