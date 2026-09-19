// The fake core. See include/arivu_stub.h for what this is and is not.
//
// The header comes in by relative path rather than through a search path, deliberately: the core's
// header is the contract and this file must break loudly if the contract moves, rather than compile
// against a stale copy vendored into /ios.
#include "../../../../core/include/arivu/arivu.h"
#include "include/arivu_stub.h"

#include <stdatomic.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

// ---------------------------------------------------------------------------- stub state

static char   g_script[4096] = "Dear parents, the trip is on Friday. Please sign the form.";
static int    g_piece_delay_us = 0;
static char   g_fail_load[256];
static char   g_fail_context[256];
static bool   g_next_context_full = false;
static atomic_int g_live_engines = 0;

void arivu_stub_set_script(const char * utf8) {
    snprintf(g_script, sizeof(g_script), "%s", utf8 ? utf8 : "");
}

void arivu_stub_set_piece_delay_us(int micros) { g_piece_delay_us = micros; }

void arivu_stub_fail_next_load(const char * message) {
    snprintf(g_fail_load, sizeof(g_fail_load), "%s", message ? message : "");
}

void arivu_stub_fail_next_context(const char * message) {
    snprintf(g_fail_context, sizeof(g_fail_context), "%s", message ? message : "");
}

void arivu_stub_next_stop_context_full(void) { g_next_context_full = true; }

int arivu_stub_live_engines(void) { return atomic_load(&g_live_engines); }

void arivu_stub_reset(void) {
    arivu_stub_set_script("Dear parents, the trip is on Friday. Please sign the form.");
    g_piece_delay_us = 0;
    g_fail_load[0] = 0;
    g_fail_context[0] = 0;
    g_next_context_full = false;
}

// ---------------------------------------------------------------------------- the engine

struct arivu_engine {
    bool    has_model;
    bool    has_context;
    int32_t n_ctx;
    atomic_bool cancelled;
};

static void set_err(char * err_buf, size_t err_len, const char * message) {
    if (err_buf && err_len > 0) snprintf(err_buf, err_len, "%s", message);
}

arivu_context_params arivu_default_context_params(void) {
    arivu_context_params p;
    p.n_ctx = 2048;
    p.n_batch = 512;
    p.n_threads = 4;
    p.kv_q8_0 = true;
    p.repack = false;
    return p;
}

arivu_sampling_params arivu_default_sampling_params(void) {
    arivu_sampling_params s;
    s.temperature = 0.7f;
    s.top_k = 20;
    s.top_p = 0.8f;
    s.seed = 0;
    return s;
}

arivu_engine * arivu_engine_create(void) {
    arivu_engine * e = (arivu_engine *) calloc(1, sizeof(arivu_engine));
    if (!e) return NULL;
    atomic_store(&e->cancelled, false);
    atomic_fetch_add(&g_live_engines, 1);
    return e;
}

void arivu_engine_free(arivu_engine * engine) {
    if (!engine) return;
    atomic_fetch_sub(&g_live_engines, 1);
    free(engine);
}

bool arivu_load_model_fd(arivu_engine * engine, int fd, uint64_t offset, uint64_t length,
                         bool repack, char * err_buf, size_t err_len) {
    (void) repack;
    if (!engine) return false;
    if (g_fail_load[0]) {
        set_err(err_buf, err_len, g_fail_load);
        g_fail_load[0] = 0;
        return false;
    }
    // The real core rejects a misaligned offset; the fake one at least insists the window is real,
    // so a test that passes a closed descriptor or a zero length fails here rather than later.
    if (fd < 0 || length == 0) {
        set_err(err_buf, err_len, "stub: bad model window");
        return false;
    }
    (void) offset;
    engine->has_model = true;
    return true;
}

bool arivu_load_model_path(arivu_engine * engine, const char * path, bool repack,
                           char * err_buf, size_t err_len) {
    (void) repack;
    if (!engine) return false;
    if (g_fail_load[0]) {
        set_err(err_buf, err_len, g_fail_load);
        g_fail_load[0] = 0;
        return false;
    }
    if (!path || !path[0]) {
        set_err(err_buf, err_len, "stub: empty path");
        return false;
    }
    engine->has_model = true;
    return true;
}

bool arivu_has_model(const arivu_engine * engine) { return engine && engine->has_model; }

void arivu_free_model(arivu_engine * engine) {
    if (!engine) return;
    engine->has_model = false;
    engine->has_context = false;
    engine->n_ctx = 0;
}

bool arivu_ensure_context(arivu_engine * engine, arivu_context_params params,
                          char * err_buf, size_t err_len) {
    if (!engine) return false;
    if (!engine->has_model) {
        set_err(err_buf, err_len, "stub: no model");
        return false;
    }
    if (g_fail_context[0]) {
        set_err(err_buf, err_len, g_fail_context);
        g_fail_context[0] = 0;
        return false;
    }
    engine->has_context = true;
    engine->n_ctx = params.n_ctx;
    return true;
}

bool arivu_has_context(const arivu_engine * engine) { return engine && engine->has_context; }

void arivu_free_context(arivu_engine * engine) {
    if (!engine) return;
    engine->has_context = false;
}

int32_t arivu_n_ctx(const arivu_engine * engine) { return engine ? engine->n_ctx : 0; }

// One token per byte. Not how a tokenizer works, and deliberately so: it keeps the arithmetic in a
// test obvious, exactly as PromptBuilderTest.kt uses one token per character.
int32_t arivu_count_tokens(const arivu_engine * engine, const char * utf8, size_t len) {
    if (!engine || !engine->has_model) return -1;
    (void) utf8;
    return (int32_t) len;
}

arivu_stats arivu_generate(arivu_engine * engine, const char * prompt_utf8, size_t prompt_len,
                           int32_t max_new_tokens, arivu_sampling_params sampling,
                           arivu_piece_fn on_piece, void * user_data,
                           char * err_buf, size_t err_len) {
    (void) sampling;
    (void) prompt_utf8;
    arivu_stats st;
    memset(&st, 0, sizeof(st));
    st.prompt_tokens = (int32_t) prompt_len;
    st.first_token_ms = 1.0;
    st.prefill_ms = 1.0;
    st.decode_ms = 1.0;

    if (!engine || !engine->has_context) {
        set_err(err_buf, err_len, "stub: no context");
        st.stop = ARIVU_STOP_ERROR;
        return st;
    }

    // A fresh generation clears the cancel flag, exactly as the real engine does. This is the
    // behaviour that made Stop-during-model-load a real bug on Android (leaves/NOTES.md, bug 2):
    // the app must hold its own "stop was asked for" flag, not rely on this one.
    atomic_store(&engine->cancelled, false);

    if (g_next_context_full) {
        g_next_context_full = false;
        st.stop = ARIVU_STOP_CONTEXT_FULL;
        return st;
    }

    const char * p = g_script;
    int32_t emitted = 0;
    char piece[256];
    while (*p) {
        if (atomic_load(&engine->cancelled)) {
            st.stop = ARIVU_STOP_CANCELLED;
            st.generated = emitted;
            return st;
        }
        if (max_new_tokens > 0 && emitted >= max_new_tokens) {
            st.stop = ARIVU_STOP_MAX_TOKENS;
            st.generated = emitted;
            return st;
        }
        const char * space = strchr(p, ' ');
        size_t n = space ? (size_t)(space - p) + 1 : strlen(p);
        if (n >= sizeof(piece)) n = sizeof(piece) - 1;
        memcpy(piece, p, n);
        piece[n] = 0;
        if (on_piece) on_piece(piece, n, user_data);
        emitted++;
        p += n;
        if (g_piece_delay_us > 0) usleep((useconds_t) g_piece_delay_us);
    }
    st.stop = ARIVU_STOP_END_OF_TURN;
    st.generated = emitted;
    return st;
}

void arivu_cancel(arivu_engine * engine) {
    if (!engine) return;
    atomic_store(&engine->cancelled, true);
}

void arivu_memory_kb(int64_t * rss_kb, int64_t * peak_kb) {
    if (rss_kb) *rss_kb = -1;
    if (peak_kb) *peak_kb = -1;
}

int64_t arivu_compute_buffer_kib(const arivu_engine * engine) {
    return (engine && engine->has_context) ? 28758 : -1;
}

void arivu_set_log_fn(arivu_log_fn fn, void * user_data) { (void) fn; (void) user_data; }

const char * arivu_version(void) { return "stub-0"; }

// ---------------------------------------------------------------------------- profiles

arivu_profile arivu_default_profile(void) {
    arivu_profile p;
    memset(&p, 0, sizeof(p));
    p.id = "stub";
    p.model_id = "stub";
    p.n_ctx = 2048;
    p.n_batch = 512;
    p.n_threads = 4;
    p.kv_q8_0 = true;
    p.reply_reserve_tokens = 512;
    p.max_reply_tokens = 768;
    p.capabilities = ARIVU_CAP_CHAT;
    return p;
}

arivu_context_params arivu_profile_context_params(const arivu_profile * profile) {
    arivu_context_params c = arivu_default_context_params();
    if (profile) {
        c.n_ctx = profile->n_ctx;
        c.n_batch = profile->n_batch;
        c.n_threads = profile->n_threads;
        c.kv_q8_0 = profile->kv_q8_0;
        c.repack = profile->repack;
    }
    return c;
}

bool arivu_profile_valid(const arivu_profile * profile, char * err_buf, size_t err_len) {
    if (!profile) { set_err(err_buf, err_len, "stub: null profile"); return false; }
    return true;
}

bool arivu_profile_has(const arivu_profile * profile, arivu_capability cap) {
    return profile && (profile->capabilities & (uint32_t) cap) != 0;
}

// The memory model, in the two halves a ceiling charges separately (architecture B23). Present here
// only so the stub keeps its promise to implement every symbol in arivu.h — these three were
// missing, which meant the Swift wrapper could not so much as *reference* them without failing to
// link against the fake core. The arithmetic mirrors core/src/profile.cpp; the numbers it is given
// by arivu_default_profile() above are zeros, so nothing here stands in for a measurement.
uint64_t arivu_profile_mapped_bytes(const arivu_profile * profile) {
    return profile ? profile->model_bytes : 0;
}

uint64_t arivu_profile_footprint_bytes(const arivu_profile * profile) {
    if (!profile) return 0;
    const uint64_t kv = profile->kv_bytes_per_token * (uint64_t) (profile->n_ctx > 0 ? profile->n_ctx : 0);
    const uint64_t repacked = profile->repack ? profile->model_bytes : 0u;
    return repacked + kv + profile->compute_buffer_bytes + profile->runtime_overhead_bytes;
}

uint64_t arivu_profile_estimated_peak_bytes(const arivu_profile * profile) {
    if (!profile) return 0;
    return arivu_profile_mapped_bytes(profile) + arivu_profile_footprint_bytes(profile);
}

uint64_t arivu_profile_required_available_bytes(const arivu_profile * profile,
                                                const arivu_device * device) {
    if (!profile || !device) return 0;
    const uint32_t permille = arivu_headroom_permille(device->memory_source);
    if (permille == 0) return 0;
    const uint64_t basis = device->observed_footprint_bytes != 0
                         ? device->observed_footprint_bytes
                         : arivu_profile_footprint_bytes(profile);
    return basis / 1000ull * permille + basis % 1000ull * permille / 1000ull;
}

uint32_t arivu_headroom_permille(arivu_memory_source source) {
    switch (source) {
        case ARIVU_MEM_PROBED:     return 1400;
        case ARIVU_MEM_INFERRED:   return 1250;
        case ARIVU_MEM_UNMEASURED: return 0;
    }
    return 0;
}

arivu_profile_check arivu_profile_fits(const arivu_profile * profile, const arivu_device * device) {
    arivu_profile_check c;
    memset(&c, 0, sizeof(c));
    (void) profile;
    (void) device;
    c.fit = ARIVU_FIT_OK;
    return c;
}

int32_t arivu_profile_select(const arivu_profile * candidates, size_t n_candidates,
                             const arivu_device * device) {
    (void) candidates; (void) device;
    return n_candidates > 0 ? 0 : -1;
}

const char * arivu_fit_name(arivu_fit fit) {
    switch (fit) {
        case ARIVU_FIT_OK: return "ok";
        case ARIVU_FIT_INVALID_PROFILE: return "invalid_profile";
        case ARIVU_FIT_NO_ARM64: return "no_arm64";
        case ARIVU_FIT_LOW_RAM_DEVICE: return "low_ram_device";
        case ARIVU_FIT_TOTAL_RAM: return "total_ram";
        case ARIVU_FIT_AVAILABLE_MEMORY: return "available_memory";
        case ARIVU_FIT_STORAGE: return "storage";
    }
    return "unknown";
}

const char * arivu_stop_reason_name(arivu_stop_reason reason) {
    switch (reason) {
        case ARIVU_STOP_END_OF_TURN: return "end_of_turn";
        case ARIVU_STOP_CANCELLED: return "cancelled";
        case ARIVU_STOP_CONTEXT_FULL: return "context_full";
        case ARIVU_STOP_MAX_TOKENS: return "max_tokens";
        case ARIVU_STOP_ERROR: return "error";
    }
    return "unknown";
}

// ---------------------------------------------------------------------------- prompt building
//
// Not implemented: the Swift PromptBuilder is the iOS implementation today, and the parity tests
// that would compare it against the core's builder skip themselves when arivu_version() says "stub".

const char * arivu_assistant_open(void) { return "<|im_start|>assistant\n<think>\n\n</think>\n\n"; }

struct arivu_prompt_builder { int unused; };

arivu_prompt_builder * arivu_prompt_builder_create(const char * system_prompt, int32_t n_ctx,
                                                   int32_t reply_reserve, arivu_count_fn count,
                                                   void * user_data) {
    (void) system_prompt; (void) n_ctx; (void) reply_reserve; (void) count; (void) user_data;
    return NULL;
}

arivu_prompt_builder * arivu_prompt_builder_create_for_engine(const char * system_prompt,
                                                              int32_t n_ctx, int32_t reply_reserve,
                                                              const arivu_engine * engine) {
    (void) system_prompt; (void) n_ctx; (void) reply_reserve; (void) engine;
    return NULL;
}

void arivu_prompt_builder_free(arivu_prompt_builder * builder) { (void) builder; }

arivu_prompt_result arivu_prompt_builder_build(arivu_prompt_builder * builder,
                                               const arivu_turn * turns, size_t n_turns,
                                               char * out_buf, size_t out_cap, size_t * out_len) {
    (void) builder; (void) turns; (void) n_turns; (void) out_buf; (void) out_cap;
    arivu_prompt_result r;
    memset(&r, 0, sizeof(r));
    r.status = ARIVU_PROMPT_INVALID;
    if (out_len) *out_len = 0;
    return r;
}

// The real rule, implemented for real: a test compares the Swift streaming buffer against it.
size_t arivu_utf8_complete_prefix(const char * bytes, size_t len) {
    if (!bytes || len == 0) return 0;
    // Walk back over continuation bytes to the start of the last sequence.
    size_t start = len;
    size_t back = 0;
    while (start > 0 && back < 4) {
        start--;
        back++;
        unsigned char c = (unsigned char) bytes[start];
        if ((c & 0xC0) != 0x80) break;  // not a continuation byte: this is the lead
    }
    unsigned char lead = (unsigned char) bytes[start];
    size_t needed = 1;
    if ((lead & 0x80) == 0) needed = 1;
    else if ((lead & 0xE0) == 0xC0) needed = 2;
    else if ((lead & 0xF0) == 0xE0) needed = 3;
    else if ((lead & 0xF8) == 0xF0) needed = 4;
    else return len;  // stray continuation byte; nothing sensible to hold back
    if (start + needed <= len) return len;
    return start;   // hold back the incomplete tail
}
