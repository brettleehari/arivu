// C API over the C++ engine (see include/arivu/arivu.h). No platform SDK headers: the only
// conditional code is how a process reads its own memory use, which differs between Linux and
// Apple kernels but needs no SDK.
#include "arivu/arivu.h"

#include "arivu/engine.h"
#include "llama.h"

#include <atomic>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>

#if defined(__APPLE__)
#include <mach/mach.h>
#else
#include <cstdlib>
#include <fstream>
#endif

namespace {

std::atomic<int64_t> g_compute_buffer_kib{-1};
std::mutex           g_log_mutex;
arivu_log_fn         g_log_fn = nullptr;
void *               g_log_ud = nullptr;

void core_log_cb(ggml_log_level level, const char * text, void *) {
    if (text != nullptr) {
        // llama.cpp reports the compute buffer only in its log; it is the number that decides
        // whether the memory budget holds, so the core captures it rather than losing it.
        const char * p = std::strstr(text, "compute buffer size =");
        if (p != nullptr) {
            g_compute_buffer_kib.store((int64_t) (std::strtod(p + std::strlen("compute buffer size ="), nullptr) * 1024.0));
        }
    }
    arivu_log_fn fn;
    void * ud;
    {
        std::lock_guard<std::mutex> lock(g_log_mutex);
        fn = g_log_fn;
        ud = g_log_ud;
    }
    if (fn != nullptr && text != nullptr) fn((int) level, text, ud);
}

void install_log_hook_once() {
    static std::once_flag once;
    std::call_once(once, [] { llama_log_set(core_log_cb, nullptr); });
}

void set_err(char * buf, size_t len, const std::string & msg) {
    if (buf == nullptr || len == 0) return;
    std::snprintf(buf, len, "%s", msg.c_str());
}

arivu::Engine * as_engine(arivu_engine * e) { return reinterpret_cast<arivu::Engine *>(e); }
const arivu::Engine * as_engine(const arivu_engine * e) { return reinterpret_cast<const arivu::Engine *>(e); }

arivu::ContextConfig to_config(arivu_context_params p) {
    arivu::ContextConfig cfg;
    cfg.n_ctx = p.n_ctx;
    cfg.n_batch = p.n_batch;
    cfg.n_threads = p.n_threads;
    cfg.kv_q8_0 = p.kv_q8_0;
    return cfg;
}

}  // namespace

extern "C" {

arivu_context_params arivu_default_context_params(void) {
    // Mirrors the shipped profile; the app layer overrides per device (spine: C8, C11).
    arivu_context_params p;
    p.n_ctx = 2048;
    p.n_batch = 512;
    p.n_threads = 4;
    p.kv_q8_0 = true;
    p.repack = false;
    return p;
}

arivu_sampling_params arivu_default_sampling_params(void) {
    arivu_sampling_params p;
    p.temperature = 0.7f;
    p.top_k = 20;
    p.top_p = 0.8f;
    p.seed = 0xA417;
    return p;
}

arivu_engine * arivu_engine_create(void) {
    install_log_hook_once();
    return reinterpret_cast<arivu_engine *>(new arivu::Engine());
}

void arivu_engine_free(arivu_engine * engine) { delete as_engine(engine); }

bool arivu_load_model_fd(arivu_engine * engine, int fd, uint64_t offset, uint64_t length,
                         bool repack, char * err_buf, size_t err_len) {
    std::string err;
    const bool ok = as_engine(engine)->load_model_fd(fd, offset, length, repack, &err);
    if (!ok) set_err(err_buf, err_len, err);
    return ok;
}

bool arivu_load_model_path(arivu_engine * engine, const char * path, bool repack,
                           char * err_buf, size_t err_len) {
    std::string err;
    const bool ok = as_engine(engine)->load_model_path(path, repack, &err);
    if (!ok) set_err(err_buf, err_len, err);
    return ok;
}

bool arivu_has_model(const arivu_engine * engine) { return as_engine(engine)->has_model(); }
void arivu_free_model(arivu_engine * engine) { as_engine(engine)->free_model(); }

bool arivu_ensure_context(arivu_engine * engine, arivu_context_params params, char * err_buf, size_t err_len) {
    std::string err;
    const bool ok = as_engine(engine)->ensure_context(to_config(params), &err);
    if (!ok) set_err(err_buf, err_len, err);
    return ok;
}

bool arivu_has_context(const arivu_engine * engine) { return as_engine(engine)->has_context(); }
void arivu_free_context(arivu_engine * engine) { as_engine(engine)->free_context(); }
int32_t arivu_n_ctx(const arivu_engine * engine) { return as_engine(engine)->n_ctx(); }

int32_t arivu_count_tokens(const arivu_engine * engine, const char * utf8, size_t len) {
    return as_engine(engine)->count_tokens(std::string(utf8, len));
}

arivu_stats arivu_generate(arivu_engine * engine, const char * prompt_utf8, size_t prompt_len,
                           int32_t max_new_tokens, arivu_sampling_params sampling,
                           arivu_piece_fn on_piece, void * user_data,
                           char * err_buf, size_t err_len) {
    arivu::Sampling s;
    s.temperature = sampling.temperature;
    s.top_k = sampling.top_k;
    s.top_p = sampling.top_p;
    s.seed = sampling.seed;

    const arivu::GenerationStats st = as_engine(engine)->generate(
        std::string(prompt_utf8, prompt_len), max_new_tokens, s,
        [&](const char * bytes, size_t len) {
            if (on_piece != nullptr) on_piece(bytes, len, user_data);
        });
    if (!st.error.empty()) set_err(err_buf, err_len, st.error);

    arivu_stats out;
    out.stop = (arivu_stop_reason) st.stop;
    out.prompt_tokens = st.prompt_tokens;
    out.reused_tokens = st.reused_tokens;
    out.generated = st.generated;
    out.prefill_ms = st.prefill_ms;
    out.decode_ms = st.decode_ms;
    out.first_token_ms = st.first_token_ms;
    return out;
}

void arivu_cancel(arivu_engine * engine) { as_engine(engine)->request_cancel(); }

void arivu_memory_kb(int64_t * rss_kb, int64_t * peak_kb) {
    int64_t rss = -1;
    int64_t peak = -1;
#if defined(__APPLE__)
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t) &info, &count) == KERN_SUCCESS) {
        rss = (int64_t) (info.phys_footprint / 1024);
    }
    struct rusage_info_v4 * unused = nullptr;
    (void) unused;  // no portable high-water mark on Apple; callers use rss
#else
    std::ifstream f("/proc/self/status");
    std::string line;
    while (std::getline(f, line)) {
        if (line.compare(0, 6, "VmRSS:") == 0) rss = std::strtol(line.c_str() + 6, nullptr, 10);
        if (line.compare(0, 6, "VmHWM:") == 0) peak = std::strtol(line.c_str() + 6, nullptr, 10);
    }
#endif
    if (rss_kb != nullptr) *rss_kb = rss;
    if (peak_kb != nullptr) *peak_kb = peak;
}

int64_t arivu_compute_buffer_kib(const arivu_engine * engine) {
    return as_engine(engine)->has_context() ? g_compute_buffer_kib.load() : -1;
}

void arivu_set_log_fn(arivu_log_fn fn, void * user_data) {
    install_log_hook_once();
    std::lock_guard<std::mutex> lock(g_log_mutex);
    g_log_fn = fn;
    g_log_ud = user_data;
}

const char * arivu_version(void) { return "0.1.0"; }

}  // extern "C"
