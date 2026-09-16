package io.github.brettleehari.arivu.app.model

import android.content.Context
import io.github.brettleehari.arivu.app.Policy
import io.github.brettleehari.arivu.llama.ModelWindow

/**
 * Where the shipped GGUF comes from. Two implementations per BRIEF.md "Build artifact";
 * iteration-1 wires only [PadInstallTimeModelSource]. decisions.yml D-005 records that both
 * end up as an uncompressed asset read through AssetManager.openFd().
 */
interface ModelSource {
    /** Opens the model as an fd window. Caller closes. */
    fun open(): ModelWindow
}

/**
 * spine: C1 — install-time Play Asset Delivery pack. Play installs the pack as a split APK with the
 * app; its assets are visible through the app's AssetManager and never extracted to storage.
 */
class PadInstallTimeModelSource(private val context: Context) : ModelSource {
    override fun open(): ModelWindow {
        val afd = context.assets.openFd(Policy.MODEL_ASSET)
        return ModelWindow(afd.parcelFileDescriptor, afd.startOffset, afd.length)
    }
}

/** Iteration-2: the universal, shareable APK with the model embedded in the base `assets/`. */
class EmbeddedApkModelSource(@Suppress("unused") private val context: Context) : ModelSource {
    override fun open(): ModelWindow =
        TODO("iteration-2 (SPINE R1): universal APK. Same openFd() path; verify offset alignment on that artifact.")
}
