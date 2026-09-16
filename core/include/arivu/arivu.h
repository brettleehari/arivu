// Arivu core — C API.
//
// The platform boundary (MULTIPLATFORM.md). Everything above this line is C++ and shared;
// everything below it is JNI on Android and Swift on iOS. C, not C++, because Swift imports C
// directly and JNI has no reason to care either way.
//
// Model bytes always arrive as fd + offset + length: Android passes a window inside the APK,
// iOS passes offset 0 and the whole file. One signature covers both.
//
// Threading: one handle is used from one thread at a time, except arivu_cancel, which is safe
// from any thread and is the whole point of having it.
#ifndef ARIVU_H
#define ARIVU_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct arivu_engine arivu_engine;

typedef enum {
    ARIVU_STOP_END_OF_TURN   = 0,
    ARIVU_STOP_CANCELLED     = 1,
    ARIVU_STOP_CONTEXT_FULL  = 2,
    ARIVU_STOP_MAX_TOKENS    = 3,
    ARIVU_STOP_ERROR         = 4,
} arivu_stop_reason;

// Everything that could have been a setting, in one struct (spine: C8, C11).
// A profile is chosen from what the device can carry, never from which platform it is.
typedef struct {
    int32_t n_ctx;
    int32_t n_batch;
    int32_t n_threads;
    bool    kv_q8_0;      // quantized KV cache; requires flash attention
    bool    repack;       // faster ARM kernels, but weights stop being evictable
} arivu_context_params;

typedef struct {
    float    temperature;
    int32_t  top_k;
    float    top_p;
    uint32_t seed;
} arivu_sampling_params;

typedef struct {
    arivu_stop_reason stop;
    int32_t prompt_tokens;
    int32_t reused_tokens;
    int32_t generated;
    double  prefill_ms;
    double  decode_ms;
    double  first_token_ms;   // generate() to first visible text
} arivu_stats;

// Complete UTF-8 byte sequences only; never a partial character.
typedef void (*arivu_piece_fn)(const char * bytes, size_t len, void * user_data);

arivu_context_params  arivu_default_context_params(void);
arivu_sampling_params arivu_default_sampling_params(void);

arivu_engine * arivu_engine_create(void);
void           arivu_engine_free(arivu_engine * engine);

// err_buf receives a NUL-terminated message on failure; pass NULL to ignore.
bool arivu_load_model_fd(arivu_engine * engine, int fd, uint64_t offset, uint64_t length,
                         bool repack, char * err_buf, size_t err_len);
bool arivu_load_model_path(arivu_engine * engine, const char * path, bool repack,
                           char * err_buf, size_t err_len);
bool arivu_has_model(const arivu_engine * engine);
void arivu_free_model(arivu_engine * engine);   // frees the context too

bool arivu_ensure_context(arivu_engine * engine, arivu_context_params params,
                          char * err_buf, size_t err_len);
bool arivu_has_context(const arivu_engine * engine);
void arivu_free_context(arivu_engine * engine); // releases the KV cache; weights stay mapped
int32_t arivu_n_ctx(const arivu_engine * engine);

// Token count of UTF-8 text as the model sees it; negative on failure.
int32_t arivu_count_tokens(const arivu_engine * engine, const char * utf8, size_t len);

arivu_stats arivu_generate(arivu_engine * engine, const char * prompt_utf8, size_t prompt_len,
                           int32_t max_new_tokens, arivu_sampling_params sampling,
                           arivu_piece_fn on_piece, void * user_data,
                           char * err_buf, size_t err_len);

void arivu_cancel(arivu_engine * engine);  // thread-safe

// Resident and peak resident set size of this process in kB; -1 where unavailable.
void arivu_memory_kb(int64_t * rss_kb, int64_t * peak_kb);

// Compute-buffer size of the live context in KiB; -1 if there is no context.
int64_t arivu_compute_buffer_kib(const arivu_engine * engine);

// Optional log sink; Android forwards to logcat, iOS to os_log. Also lets the core record the
// compute-buffer size that llama.cpp only reports through its log.
typedef void (*arivu_log_fn)(int level, const char * text, void * user_data);
void arivu_set_log_fn(arivu_log_fn fn, void * user_data);

const char * arivu_version(void);

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // ARIVU_H
