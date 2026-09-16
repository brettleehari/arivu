// spine: C2 — JNI declarations for the engine (jni_bridge.cpp).
package io.github.brettleehari.arivu.llama

/** Raw JNI surface. Use [LlamaEngine]; it serialises calls and owns the handle. */
internal object LlamaNative {
    init {
        System.loadLibrary("arivu_llama")
    }

    @JvmStatic external fun nativeInit(nativeLibDir: String)
    @JvmStatic external fun nativeCreate(): Long
    @JvmStatic external fun nativeDestroy(handle: Long)
    @JvmStatic external fun nativeLoadModelFd(handle: Long, fd: Int, offset: Long, length: Long, repack: Boolean, err: Array<String?>): Boolean
    @JvmStatic external fun nativeLoadModelPath(handle: Long, path: String, repack: Boolean, err: Array<String?>): Boolean
    @JvmStatic external fun nativeFreeModel(handle: Long)
    @JvmStatic external fun nativeHasModel(handle: Long): Boolean
    @JvmStatic external fun nativeEnsureContext(handle: Long, nCtx: Int, nBatch: Int, nThreads: Int, kvQ8: Boolean, err: Array<String?>): Boolean
    @JvmStatic external fun nativeFreeContext(handle: Long)
    @JvmStatic external fun nativeHasContext(handle: Long): Boolean
    @JvmStatic external fun nativeCountTokens(handle: Long, textUtf8: ByteArray): Int
    @JvmStatic external fun nativeCancel(handle: Long)
    @JvmStatic external fun nativeGenerate(
        handle: Long, promptUtf8: ByteArray, maxNew: Int,
        temperature: Float, topK: Int, topP: Float, seed: Int,
        sink: TokenSink, err: Array<String?>,
    ): LongArray
    @JvmStatic external fun nativeMemoryKb(): LongArray
}

/** Receives complete UTF-8 byte sequences from native generation. */
internal fun interface TokenSink {
    fun onBytes(bytes: ByteArray)
}
