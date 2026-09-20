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

// ---------------------------------------------------------------------------------------------
// The model card, read from the GGUF rather than written down.
//
// Everything here comes out of the file the app shipped, at the moment it is asked. That is the
// whole point: a model card typed into the UI is true on the day it is typed and quietly wrong
// after the next model change, and a page whose purpose is to explain the model is the worst place
// for a stale number. Swapping the model updates this by itself.
//
// Requires a loaded model; returns false if there is none.
typedef struct {
    char     description[128];   // llama's own summary, e.g. "qwen3 0.6B Q4_K_M"
    char     architecture[32];   // general.architecture, e.g. "qwen3"
    char     name[96];           // general.name from the GGUF
    uint64_t parameters;         // total weights, counted from the file
    uint64_t size_bytes;         // what those weights occupy once mapped
    int32_t  n_layer;
    int32_t  n_head;             // attention heads
    int32_t  n_head_kv;          // KV heads; fewer than n_head means grouped-query attention,
                                 // which is what makes the KV cache small enough for a phone
    int32_t  n_embd;
    // Head dimension, read from the file and NOT derived. Qwen3 sets it explicitly and decoupled
    // from n_embd / n_head: 0.6B is n_embd 1024 over 16 heads, which would give 64, while the real
    // key_length is 128. Deriving it halved the KV estimate — on a page whose purpose is to explain
    // the model, that is the worst possible place for a confident wrong number.
    int32_t  key_length;
    int32_t  value_length;
    int32_t  n_ctx_train;        // the context the model was TRAINED for, not the one Arivu uses
    int32_t  n_vocab;
} arivu_model_info;

bool arivu_model_info_get(const arivu_engine * engine, arivu_model_info * out);

// KV cache cost per token, in bytes. Takes the head dimensions rather than deriving them, for the
// reason given on key_length above. The platform shows this; the profile predicts it; comparing the
// two is how a wrong profile figure gets noticed instead of shipped.
uint64_t arivu_kv_bytes_per_token(int32_t n_layer, int32_t n_head_kv,
                                  int32_t key_length, int32_t value_length, bool kv_q8_0);

// ---------------------------------------------------------------------------------------------
// Device profiles (spine: C11, C8; MULTIPLATFORM.md appendix "the device tier is a config object").
//
// What the app can do is chosen by what the device can carry, never by which platform it is.
// An 8GB Android phone and an 8GB iPhone get the same profile. Nothing here is #ifdef'd by
// platform; the platform layer only *measures* the device and hands the numbers in.

typedef enum {
    ARIVU_CAP_CHAT     = 1u << 0,  // the shipped product: one screen, user's own text
    ARIVU_CAP_TOOLS    = 1u << 1,  // reserved; SPINE R2 refuses it in iteration-1
    ARIVU_CAP_LONGFORM = 1u << 2,  // reserved; needs a context a 4GB phone cannot hold
} arivu_capability;

// A tier, not a platform. Every number is either a decision already made (spine: C8) or a
// measurement; see leaves/NOTES.md for where the memory figures come from.
typedef struct {
    const char * id;            // "compact"
    const char * model_id;      // "qwen3-0.6b-q4km"
    uint64_t     model_bytes;   // weights on disk, and the mapped size of the weights

    int32_t  n_ctx;
    int32_t  n_batch;
    int32_t  n_threads;
    bool     kv_q8_0;
    bool     repack;

    int32_t  reply_reserve_tokens;  // held back for the reply when fitting history
    int32_t  max_reply_tokens;      // may exceed the reserve; overrun is reported, never silent (C7)

    // Memory model, in bytes. Peak working set is estimated as
    //   model_bytes + kv_bytes_per_token * n_ctx + compute_buffer_bytes + runtime_overhead_bytes.
    uint64_t kv_bytes_per_token;
    uint64_t compute_buffer_bytes;
    uint64_t runtime_overhead_bytes;

    // Floors the platform gate also enforces before the engine is ever created.
    uint64_t min_total_ram_bytes;
    uint64_t min_free_storage_bytes;

    uint32_t capabilities;      // bitmask of arivu_capability
} arivu_profile;

// How good the available-memory number is. The two platforms are not equally able to answer
// "how much may this process use before it is killed", and the asymmetry must be visible rather
// than hidden behind a zero: a platform that does not know says so, and the core then declines to
// invent a ceiling instead of guessing one (architecture B23).
typedef enum {
    ARIVU_MEM_UNMEASURED = 0,  // the platform declined to answer; only the RAM floor applies
    ARIVU_MEM_INFERRED   = 1,  // derived from total RAM or a device class, not asked of the OS
    ARIVU_MEM_PROBED     = 2,  // the OS was asked directly (os_proc_available_memory())
} arivu_memory_source;

// What the platform measured. Android fills this from ActivityManager.MemoryInfo / StatFs;
// iOS from os_proc_available_memory() and NSFileManager. Zero means "not measured".
typedef struct {
    uint64_t total_ram_bytes;
    uint64_t available_memory_bytes;  // what this process may use before it is killed
    uint64_t free_storage_bytes;
    int32_t  performance_cores;
    bool     arm64;
    bool     low_ram_flagged;         // Android isLowRamDevice(); false on iOS
    // ZERO-INITIALISE THIS STRUCT. `arivu_device d = {0};`, `arivu_device d{};`, memset, or Swift's
    // `arivu_device()` — never a bare declaration followed by field assignments. Every field's
    // zero is deliberately the safe answer (ARIVU_MEM_UNMEASURED, "not measured", "never observed"),
    // and fields get added here: a caller that assigns each one by hand silently inherits garbage
    // in whatever is newer than it is.
    arivu_memory_source memory_source;

    // The largest charged footprint this profile has ever actually cost ON THIS DEVICE, in bytes;
    // 0 if it has never run here. See arivu_profile_required_available_bytes.
    uint64_t observed_footprint_bytes;
} arivu_device;

typedef enum {
    ARIVU_FIT_OK                 = 0,
    ARIVU_FIT_INVALID_PROFILE    = 1,
    ARIVU_FIT_NO_ARM64           = 2,
    ARIVU_FIT_LOW_RAM_DEVICE     = 3,
    ARIVU_FIT_TOTAL_RAM          = 4,
    ARIVU_FIT_AVAILABLE_MEMORY   = 5,  // the charged footprint, plus headroom, does not fit
    ARIVU_FIT_STORAGE            = 6,
} arivu_fit;

typedef struct {
    arivu_fit fit;
    uint64_t  required_bytes;             // what the failing check needed; 0 if it is not a size check
    uint64_t  actual_bytes;               // what the device reported
    uint64_t  estimated_peak_bytes;       // whole working set, mapped weights included
    uint64_t  estimated_footprint_bytes;  // the charged half — what a memory ceiling applies to
} arivu_profile_check;

// The profile Arivu ships today: Qwen3-0.6B Q4_K_M, 2048 ctx, q8_0 KV, 4 threads, chat only.
arivu_profile arivu_default_profile(void);
arivu_context_params arivu_profile_context_params(const arivu_profile * profile);

// Internally consistent? (n_batch <= n_ctx, reserve < n_ctx, a capability the context can carry…)
// err_buf receives the first problem; pass NULL to ignore.
bool arivu_profile_valid(const arivu_profile * profile, char * err_buf, size_t err_len);
bool arivu_profile_has(const arivu_profile * profile, arivu_capability cap);

// The memory model, in two halves, because a memory ceiling charges only one of them
// (architecture B23):
//
//   mapped     clean, file-backed, evictable — the mmap'd weights. Counts against physical RAM
//              and against the page cache, but iOS jetsam charges phys_footprint, which excludes
//              clean file-backed pages, so this half does not count against that ceiling.
//   footprint  dirty and anonymous — KV cache, compute buffer, runtime overhead, and a repacked
//              copy of the weights if the profile asks for one. This is what gets the app killed.
//
// peak = mapped + footprint: the worst case where nothing has been evicted.
uint64_t arivu_profile_mapped_bytes(const arivu_profile * profile);
uint64_t arivu_profile_footprint_bytes(const arivu_profile * profile);
uint64_t arivu_profile_estimated_peak_bytes(const arivu_profile * profile);

// Headroom required over the estimated footprint, in parts per thousand, by how the ceiling was
// obtained. A probed number needs *more* headroom, not less: os_proc_available_memory() is an
// instantaneous reading taken at the calmest moment in the app's life, and it shrinks under system
// pressure. An inferred number is already a conservative derivation. Returns 0 for
// ARIVU_MEM_UNMEASURED, where no ceiling check is made at all.
uint32_t arivu_headroom_permille(arivu_memory_source source);

// How much available memory this profile needs on THIS device, headroom included. 0 means no
// ceiling applies, because the platform did not measure one.
//
// The estimate in a profile is an estimate. `runtime_overhead_bytes` in particular is one number
// standing in for ART, Compose, SwiftUI and an allocator across every phone that will ever run
// this, and it is marked provisional for that reason. Shipping a single static figure to thousands
// of device models guarantees being wrong in both directions: refusing phones that would have run
// it, and admitting phones that are then killed.
//
// So when the device has actually run this profile, what it cost is used instead of what was
// predicted. `observed_footprint_bytes` is the largest charged footprint ever seen here — the
// platform keeps the maximum, so one lucky reading cannot relax the bar for good.
//
// Trusted in BOTH directions, deliberately:
//   higher than the estimate  the estimate was optimistic on this device; demanding more is the
//                             only thing standing between the user and a kill.
//   lower than the estimate   the estimate was pessimistic here; demanding more would refuse a
//                             phone this app has already demonstrably run on.
//
// The headroom multiplier still applies on top, so adapting the magnitude never removes the margin.
//
// Safe to calibrate from a single observation because llama.cpp allocates the whole KV cache for
// n_ctx when the context is created: the footprint right after a context exists is already the
// steady-state peak, not a figure that grows with the conversation.
uint64_t arivu_profile_required_available_bytes(const arivu_profile * profile,
                                                const arivu_device * device);

// "Can this device run this profile", answered from measured numbers only. The memory ceiling is
// applied to the charged footprint plus headroom, never to the peak: charging a device for clean
// file-backed pages it can evict would refuse phones that would have run the profile perfectly.
arivu_profile_check arivu_profile_fits(const arivu_profile * profile, const arivu_device * device);

// Picks the first profile in `candidates` that fits, richest first. Returns the index, or -1 if
// none fits. The candidate list is the caller's product decision; this function is only the
// arithmetic (spine: C11).
int32_t arivu_profile_select(const arivu_profile * candidates, size_t n_candidates,
                             const arivu_device * device);

const char * arivu_fit_name(arivu_fit fit);
const char * arivu_stop_reason_name(arivu_stop_reason reason);

// ---------------------------------------------------------------------------------------------
// Prompt building and token-budget truncation (spine: C7, C11).
//
// Shared because "keep whole turns" is a product decision, not a platform one
// (MULTIPLATFORM.md appendix). Qwen3 ChatML, non-thinking mode (decisions.yml D-007).
// History is dropped oldest-first, whole turns only; the caller is told which turn is the
// oldest one the model can see, so dropped history is shown and never silently lost.

typedef struct {
    const char * id;         // stable per turn; keys the token-count cache
    const char * text;       // UTF-8, not NUL-terminated necessarily
    size_t       text_len;
    bool         from_user;
} arivu_turn;

typedef enum {
    ARIVU_PROMPT_OK       = 0,
    ARIVU_PROMPT_TOO_LONG = 1,  // the newest user message alone does not fit
    ARIVU_PROMPT_INVALID  = 2,  // empty history, newest turn not the user's, or counting failed
} arivu_prompt_status;

typedef struct {
    arivu_prompt_status status;
    int32_t prompt_tokens;    // OK: system + included turns + assistant open
    int32_t first_included;   // OK: index of the oldest turn the model sees
    int32_t message_tokens;   // TOO_LONG: what the newest message costs
    int32_t limit_tokens;     // TOO_LONG: what was available for it
    size_t  text_len;         // full prompt length in bytes, whatever out_cap was
    bool    output_truncated; // out_buf was NULL or too small; text_len says how much was needed
} arivu_prompt_result;

// Counts tokens in UTF-8 text as the model sees it; negative means the count failed.
typedef int32_t (*arivu_count_fn)(const char * utf8, size_t len, void * user_data);

typedef struct arivu_prompt_builder arivu_prompt_builder;

const char * arivu_assistant_open(void);

arivu_prompt_builder * arivu_prompt_builder_create(const char * system_prompt, int32_t n_ctx,
                                                   int32_t reply_reserve, arivu_count_fn count,
                                                   void * user_data);
// Same, counting with the engine's own tokenizer. The engine must outlive the builder.
arivu_prompt_builder * arivu_prompt_builder_create_for_engine(const char * system_prompt,
                                                              int32_t n_ctx, int32_t reply_reserve,
                                                              const arivu_engine * engine);
void arivu_prompt_builder_free(arivu_prompt_builder * builder);

// Writes a NUL-terminated prompt into out_buf (pass NULL/0 to measure first; text_len is always
// set to the full length). Only ARIVU_PROMPT_OK writes anything to out_buf — on TOO_LONG or
// INVALID the caller has a status to show the user (spine: C7), not a prompt to send.
arivu_prompt_result arivu_prompt_builder_build(arivu_prompt_builder * builder,
                                               const arivu_turn * turns, size_t n_turns,
                                               char * out_buf, size_t out_cap, size_t * out_len);

// Bytes at the front of buf that form complete UTF-8 sequences. Exposed because a platform that
// does its own streaming buffer must use the same rule the engine uses.
size_t arivu_utf8_complete_prefix(const char * bytes, size_t len);


#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // ARIVU_H
