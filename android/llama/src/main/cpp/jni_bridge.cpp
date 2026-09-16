// JNI surface for io.github.brettleehari.arivu.llama.LlamaNative. One Engine per handle; calls on a handle
// are serialised by the Kotlin side (LlamaEngine), except cancel(), which is thread-safe.
#include "engine.h"

#include "ggml-backend.h"
#include "llama.h"

#include <android/log.h>
#include <jni.h>

#include <atomic>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <mutex>
#include <string>

#define TAG "arivu-llama"

namespace {

// Last "CPU compute buffer size = X MiB" reported by llama.cpp when a context is created, in KiB.
// spine: C2 (M3) — lets the benchmark record the non-reclaimable scratch size next to RSS.
std::atomic<long> g_compute_buffer_kib{-1};

void log_cb(ggml_log_level level, const char * text, void *) {
    if (const char * p = std::strstr(text, "compute buffer size =")) {
        g_compute_buffer_kib.store((long) (std::strtod(p + std::strlen("compute buffer size ="), nullptr) * 1024.0));
    }
    int prio = ANDROID_LOG_DEBUG;
    switch (level) {
        case GGML_LOG_LEVEL_ERROR: prio = ANDROID_LOG_ERROR; break;
        case GGML_LOG_LEVEL_WARN:  prio = ANDROID_LOG_WARN;  break;
        case GGML_LOG_LEVEL_INFO:  prio = ANDROID_LOG_INFO;  break;
        default: break;
    }
    __android_log_write(prio, TAG, text);
}

arivu::Engine * engine(jlong h) { return reinterpret_cast<arivu::Engine *>(h); }

void set_error(JNIEnv * env, jobjectArray out, const std::string & err) {
    if (out != nullptr && env->GetArrayLength(out) > 0) {
        jstring s = env->NewStringUTF(err.c_str());
        env->SetObjectArrayElement(out, 0, s);
        env->DeleteLocalRef(s);
    }
}

long read_kb(const char * key) {
    std::ifstream f("/proc/self/status");
    std::string line;
    const size_t klen = std::strlen(key);
    while (std::getline(f, line)) {
        if (line.compare(0, klen, key) == 0) return std::strtol(line.c_str() + klen, nullptr, 10);
    }
    return -1;
}

}  // namespace

extern "C" {

JNIEXPORT void JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeInit(JNIEnv * env, jclass, jstring native_lib_dir) {
    static std::once_flag once;
    const char * dir = env->GetStringUTFChars(native_lib_dir, nullptr);
    std::string d(dir);
    env->ReleaseStringUTFChars(native_lib_dir, dir);
    std::call_once(once, [&] {
        llama_log_set(log_cb, nullptr);
        ggml_backend_load_all_from_path(d.c_str());
        llama_backend_init();
    });
}

JNIEXPORT jlong JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeCreate(JNIEnv *, jclass) {
    return reinterpret_cast<jlong>(new arivu::Engine());
}

JNIEXPORT void JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeDestroy(JNIEnv *, jclass, jlong h) {
    delete engine(h);
}

JNIEXPORT jboolean JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeLoadModelFd(JNIEnv * env, jclass, jlong h, jint fd, jlong offset, jlong length,
                                                    jboolean repack, jobjectArray err_out) {
    std::string err;
    const bool ok = engine(h)->load_model_fd(fd, (uint64_t) offset, (uint64_t) length, repack, &err);
    if (!ok) set_error(env, err_out, err);
    return ok;
}

JNIEXPORT jboolean JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeLoadModelPath(JNIEnv * env, jclass, jlong h, jstring path, jboolean repack,
                                                      jobjectArray err_out) {
    const char * p = env->GetStringUTFChars(path, nullptr);
    std::string err;
    const bool ok = engine(h)->load_model_path(p, repack, &err);
    env->ReleaseStringUTFChars(path, p);
    if (!ok) set_error(env, err_out, err);
    return ok;
}

JNIEXPORT void JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeFreeModel(JNIEnv *, jclass, jlong h) { engine(h)->free_model(); }

JNIEXPORT jboolean JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeEnsureContext(JNIEnv * env, jclass, jlong h, jint n_ctx, jint n_batch,
                                                      jint n_threads, jboolean kv_q8, jobjectArray err_out) {
    arivu::ContextConfig cfg;
    cfg.n_ctx = n_ctx;
    cfg.n_batch = n_batch;
    cfg.n_threads = n_threads;
    cfg.kv_q8_0 = kv_q8;
    std::string err;
    const bool ok = engine(h)->ensure_context(cfg, &err);
    if (!ok) set_error(env, err_out, err);
    return ok;
}

JNIEXPORT void JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeFreeContext(JNIEnv *, jclass, jlong h) { engine(h)->free_context(); }

JNIEXPORT jboolean JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeHasContext(JNIEnv *, jclass, jlong h) { return engine(h)->has_context(); }

JNIEXPORT jboolean JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeHasModel(JNIEnv *, jclass, jlong h) { return engine(h)->has_model(); }

JNIEXPORT jint JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeCountTokens(JNIEnv * env, jclass, jlong h, jbyteArray text_utf8) {
    const jsize n = env->GetArrayLength(text_utf8);
    std::string s((size_t) n, '\0');
    env->GetByteArrayRegion(text_utf8, 0, n, reinterpret_cast<jbyte *>(s.data()));
    return engine(h)->count_tokens(s);
}

JNIEXPORT void JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeCancel(JNIEnv *, jclass, jlong h) { engine(h)->request_cancel(); }

// prompt arrives as UTF-8 bytes; pieces go back as UTF-8 bytes via sink.onBytes([B)
// Returns long[7]: stop, promptTokens, reusedTokens, generated, prefillMicros, decodeMicros, firstTokenMicros
JNIEXPORT jlongArray JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeGenerate(JNIEnv * env, jclass, jlong h, jbyteArray prompt_utf8, jint max_new,
                                                 jfloat temperature, jint top_k, jfloat top_p, jint seed,
                                                 jobject sink, jobjectArray err_out) {
    const jsize n = env->GetArrayLength(prompt_utf8);
    std::string prompt((size_t) n, '\0');
    env->GetByteArrayRegion(prompt_utf8, 0, n, reinterpret_cast<jbyte *>(prompt.data()));

    jclass sink_cls = env->GetObjectClass(sink);
    jmethodID on_bytes = env->GetMethodID(sink_cls, "onBytes", "([B)V");

    arivu::Sampling s;
    s.temperature = temperature;
    s.top_k = top_k;
    s.top_p = top_p;
    s.seed = (uint32_t) seed;

    const arivu::GenerationStats st = engine(h)->generate(prompt, max_new, s, [&](const char * b, size_t len) {
        jbyteArray arr = env->NewByteArray((jsize) len);
        env->SetByteArrayRegion(arr, 0, (jsize) len, reinterpret_cast<const jbyte *>(b));
        env->CallVoidMethod(sink, on_bytes, arr);
        env->DeleteLocalRef(arr);
        if (env->ExceptionCheck()) {
            env->ExceptionClear();
            engine(h)->request_cancel();
        }
    });
    if (!st.error.empty()) set_error(env, err_out, st.error);

    jlong vals[7] = {
        (jlong) st.stop, st.prompt_tokens, st.reused_tokens, st.generated,
        (jlong) (st.prefill_ms * 1000.0), (jlong) (st.decode_ms * 1000.0),
        (jlong) (st.first_token_ms * 1000.0),
    };
    jlongArray out = env->NewLongArray(7);
    env->SetLongArrayRegion(out, 0, 7, vals);
    return out;
}

// VmRSS, VmHWM (kB) and the last compute buffer size (KiB, -1 if none yet), for the benchmark and lifecycle verification.
JNIEXPORT jlongArray JNICALL
Java_io_github_brettleehari_arivu_llama_LlamaNative_nativeMemoryKb(JNIEnv * env, jclass) {
    jlong vals[3] = { read_kb("VmRSS:"), read_kb("VmHWM:"), (jlong) g_compute_buffer_kib.load() };
    jlongArray out = env->NewLongArray(3);
    env->SetLongArrayRegion(out, 0, 3, vals);
    return out;
}

}  // extern "C"
