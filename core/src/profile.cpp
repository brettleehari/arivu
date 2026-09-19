// Device profiles: the config object that replaces a platform code fork (spine: C11, C8).
//
// MULTIPLATFORM.md appendix: "The engine reads a profile; features gate on capability flags.
// Nothing is #ifdef'd by platform, because the tiers will not stay platform-aligned." So this
// file contains no platform check of any kind — only arithmetic over numbers the platform
// measured, and the one profile Arivu ships today.
//
// No llama.cpp: core/tests links this with neither llama nor a platform SDK.
#include "arivu/arivu.h"

#include "arivu/engine.h"
#include "arivu/prompt.h"

#include <cstdio>
#include <cstring>

// The C enum and the C++ enum are the same contract; a divergence would be a silent
// mistranslation at the boundary, so it is a build error instead.
static_assert((int) ARIVU_STOP_END_OF_TURN  == (int) arivu::StopReason::EndOfTurn,   "stop reason drift");
static_assert((int) ARIVU_STOP_CANCELLED    == (int) arivu::StopReason::Cancelled,   "stop reason drift");
static_assert((int) ARIVU_STOP_CONTEXT_FULL == (int) arivu::StopReason::ContextFull, "stop reason drift");
static_assert((int) ARIVU_STOP_MAX_TOKENS   == (int) arivu::StopReason::MaxTokens,   "stop reason drift");
static_assert((int) ARIVU_STOP_ERROR        == (int) arivu::StopReason::Error,       "stop reason drift");
static_assert((int) ARIVU_PROMPT_OK         == (int) arivu::PromptStatus::Ok,        "prompt status drift");
static_assert((int) ARIVU_PROMPT_TOO_LONG   == (int) arivu::PromptStatus::TooLong,   "prompt status drift");
static_assert((int) ARIVU_PROMPT_INVALID    == (int) arivu::PromptStatus::Invalid,   "prompt status drift");

namespace {

void set_err(char * buf, size_t len, const char * msg) {
    if (buf != nullptr && len > 0) std::snprintf(buf, len, "%s", msg);
}

constexpr uint64_t kMiB = 1024ull * 1024ull;

}  // namespace

extern "C" {

arivu_context_params arivu_default_context_params(void) {
    // The shipped profile's context, as a plain struct for callers that do not want a profile
    // (spine: C8, C11). arivu_default_profile() and this function must not drift; core/tests
    // checks that they agree.
    const arivu_profile p = arivu_default_profile();
    arivu_context_params c;
    c.n_ctx     = p.n_ctx;
    c.n_batch   = p.n_batch;
    c.n_threads = p.n_threads;
    c.kv_q8_0   = p.kv_q8_0;
    c.repack    = p.repack;
    return c;
}

arivu_sampling_params arivu_default_sampling_params(void) {
    // decisions.yml D-007: Qwen3 non-thinking mode with Qwen's recommended sampling.
    arivu_sampling_params p;
    p.temperature = 0.7f;
    p.top_k       = 20;
    p.top_p       = 0.8f;
    p.seed        = 0xA417;
    return p;
}

arivu_profile arivu_default_profile(void) {
    arivu_profile p;
    p.id          = "compact";
    p.model_id    = "qwen3-0.6b-q4km";
    p.model_bytes = 396705472ull;   // tools/fetch_model.sh, sha256-pinned

    // Every one of these is a decision already made (spine: C8): leaves/BRIEF.md "Context",
    // decisions.yml D-007 and D-015, Policy.kt.
    p.n_ctx     = 2048;
    p.n_batch   = 512;
    p.n_threads = 4;
    p.kv_q8_0   = true;
    p.repack    = false;

    p.reply_reserve_tokens = 512;
    p.max_reply_tokens     = 768;

    // Qwen3-0.6B: 28 layers x 8 KV heads x 128 head dim, K and V, at q8_0's 34 bytes per 32
    // values = 1.0625 B/value  ->  28*8*128*2*1.0625 = 60928 B per token (119 MiB at 2048 ctx).
    p.kv_bytes_per_token = 60928ull;
    // Measured, leaves/NOTES.md "Host verification, round 2": 26.59 MiB with n_outputs_max = 1.
    p.compute_buffer_bytes = 27ull * kMiB;
    // Provisional. The emulator dry run in leaves/NOTES.md peaked at 695 MB with weights, KV and
    // compute buffer accounting for ~543 MB; the remainder is ART, Compose and the allocator.
    // W02 on the test phone replaces this number.
    p.runtime_overhead_bytes = 160ull * kMiB;

    // Provisional floors, decisions.yml D-009; mirrored in android/gradle.properties.
    p.min_total_ram_bytes    = 3543348019ull;
    p.min_free_storage_bytes = 268435456ull;

    p.capabilities = ARIVU_CAP_CHAT;   // SPINE R2/R4: tools and longform are refusals, not gaps
    return p;
}

arivu_context_params arivu_profile_context_params(const arivu_profile * profile) {
    if (profile == nullptr) return arivu_default_context_params();
    arivu_context_params c;
    c.n_ctx     = profile->n_ctx;
    c.n_batch   = profile->n_batch;
    c.n_threads = profile->n_threads;
    c.kv_q8_0   = profile->kv_q8_0;
    c.repack    = profile->repack;
    return c;
}

bool arivu_profile_valid(const arivu_profile * p, char * err_buf, size_t err_len) {
    if (p == nullptr)                       { set_err(err_buf, err_len, "profile is NULL"); return false; }
    if (p->model_id == nullptr || p->model_id[0] == '\0') { set_err(err_buf, err_len, "model_id is empty"); return false; }
    if (p->model_bytes == 0)                { set_err(err_buf, err_len, "model_bytes is 0"); return false; }
    if (p->n_ctx < 256)                     { set_err(err_buf, err_len, "n_ctx below 256"); return false; }
    if (p->n_batch < 1 || p->n_batch > p->n_ctx) { set_err(err_buf, err_len, "n_batch must be 1..n_ctx"); return false; }
    if (p->n_threads < 1 || p->n_threads > 32)   { set_err(err_buf, err_len, "n_threads must be 1..32"); return false; }
    if (p->reply_reserve_tokens < 1 || p->reply_reserve_tokens >= p->n_ctx) {
        set_err(err_buf, err_len, "reply_reserve_tokens must be 1..n_ctx-1"); return false;
    }
    if (p->max_reply_tokens < 1 || p->max_reply_tokens >= p->n_ctx) {
        // May exceed the reserve — overrun is reported as ARIVU_STOP_CONTEXT_FULL (spine: C7) —
        // but a reply that cannot fit the context at all is a misconfiguration.
        set_err(err_buf, err_len, "max_reply_tokens must be 1..n_ctx-1"); return false;
    }
    if (p->kv_bytes_per_token == 0)         { set_err(err_buf, err_len, "kv_bytes_per_token is 0"); return false; }
    if ((p->capabilities & ARIVU_CAP_CHAT) == 0) { set_err(err_buf, err_len, "every profile must have ARIVU_CAP_CHAT"); return false; }
    // Capability follows what the device can carry, and a 2048-token context cannot carry a tool
    // transcript or a long document (spine: C11).
    if ((p->capabilities & (ARIVU_CAP_TOOLS | ARIVU_CAP_LONGFORM)) != 0 && p->n_ctx < 4096) {
        set_err(err_buf, err_len, "tools/longform need n_ctx >= 4096"); return false;
    }
    set_err(err_buf, err_len, "");
    return true;
}

bool arivu_profile_has(const arivu_profile * p, arivu_capability cap) {
    return p != nullptr && (p->capabilities & (uint32_t) cap) != 0;
}

// The memory model splits in two because a memory ceiling charges only one half (architecture
// B23). The weights are always mmap'd from the asset: clean, file-backed, evictable, and never
// written to. A kernel can drop those pages under pressure and read them back, and a footprint
// accounting that excludes clean file-backed pages does not charge them at all.
uint64_t arivu_profile_mapped_bytes(const arivu_profile * p) {
    return p != nullptr ? p->model_bytes : 0;
}

uint64_t arivu_profile_footprint_bytes(const arivu_profile * p) {
    if (p == nullptr) return 0;
    const uint64_t kv = p->kv_bytes_per_token * (uint64_t) (p->n_ctx > 0 ? p->n_ctx : 0);
    // Repacking copies the weights into anonymous memory. The file mapping stays, so the copy is
    // added to the charged half rather than moved into it — which is the whole reason D-015
    // leaves repacking off.
    const uint64_t repacked = p->repack ? p->model_bytes : 0ull;
    return repacked + kv + p->compute_buffer_bytes + p->runtime_overhead_bytes;
}

uint64_t arivu_profile_estimated_peak_bytes(const arivu_profile * p) {
    if (p == nullptr) return 0;
    return arivu_profile_mapped_bytes(p) + arivu_profile_footprint_bytes(p);
}

uint32_t arivu_headroom_permille(arivu_memory_source source) {
    switch (source) {
        // A number the OS gave us is the best case, not the typical one: it is read when the app
        // is calmest, and the same call a minute later under pressure returns less. Demand more
        // room over it, not less.
        case ARIVU_MEM_PROBED:     return 1400;
        case ARIVU_MEM_INFERRED:   return 1250;
        case ARIVU_MEM_UNMEASURED: return 0;
    }
    return 0;
}

uint64_t arivu_profile_required_available_bytes(const arivu_profile * p, const arivu_device * d) {
    if (p == nullptr || d == nullptr) return 0;
    const uint32_t permille = arivu_headroom_permille(d->memory_source);
    if (permille == 0) return 0;   // the platform did not measure; no ceiling to apply

    // Measurement beats prediction. See the header for why this is trusted downwards as well as
    // upwards, and why one observation is enough.
    const uint64_t basis = d->observed_footprint_bytes != 0 ? d->observed_footprint_bytes
                                                            : arivu_profile_footprint_bytes(p);
    // Integer, in this order, so a large basis cannot overflow on the way through.
    return basis / 1000ull * permille + basis % 1000ull * permille / 1000ull;
}

arivu_profile_check arivu_profile_fits(const arivu_profile * p, const arivu_device * d) {
    arivu_profile_check r;
    r.fit                       = ARIVU_FIT_OK;
    r.required_bytes            = 0;
    r.actual_bytes              = 0;
    r.estimated_peak_bytes      = arivu_profile_estimated_peak_bytes(p);
    r.estimated_footprint_bytes = arivu_profile_footprint_bytes(p);

    if (!arivu_profile_valid(p, nullptr, 0) || d == nullptr) {
        r.fit = ARIVU_FIT_INVALID_PROFILE;
        return r;
    }
    // Same order as the Android CompatibilityGate (leaves/BRIEF.md "Device compatibility gate"):
    // first failure wins, and the user is told which one (spine: C6).
    if (!d->arm64) {
        r.fit = ARIVU_FIT_NO_ARM64;
        return r;
    }
    if (d->low_ram_flagged) {
        r.fit = ARIVU_FIT_LOW_RAM_DEVICE;
        return r;
    }
    if (d->total_ram_bytes != 0 && d->total_ram_bytes < p->min_total_ram_bytes) {
        r.fit            = ARIVU_FIT_TOTAL_RAM;
        r.required_bytes = p->min_total_ram_bytes;
        r.actual_bytes   = d->total_ram_bytes;
        return r;
    }
    // The number that actually kills the app. On iOS os_proc_available_memory() is well below
    // total RAM (MULTIPLATFORM.md: ~1.3-2GB on a 4GB iPhone); on Android there is no equivalent
    // and the platform says so rather than inventing one.
    //
    // Two things this must get right (architecture B23):
    //   1. the ceiling applies to the charged footprint, not the peak. The mapped weights are
    //      clean file-backed pages; charging a device for memory it can evict and re-read would
    //      refuse phones that would have run this profile perfectly well.
    //   2. the headroom demanded depends on how the number was obtained, not on which platform
    //      obtained it. That is the same rule as everything else here (spine: C11).
    //   3. once this device has actually run the profile, what it cost here replaces what was
    //      predicted for every phone (arivu_profile_required_available_bytes).
    const uint64_t required = arivu_profile_required_available_bytes(p, d);
    if (required != 0 && d->available_memory_bytes != 0) {
        if (d->available_memory_bytes < required) {
            r.fit            = ARIVU_FIT_AVAILABLE_MEMORY;
            r.required_bytes = required;
            r.actual_bytes   = d->available_memory_bytes;
            return r;
        }
    }
    if (d->free_storage_bytes != 0 && d->free_storage_bytes < p->min_free_storage_bytes) {
        r.fit            = ARIVU_FIT_STORAGE;
        r.required_bytes = p->min_free_storage_bytes;
        r.actual_bytes   = d->free_storage_bytes;
    }
    return r;
}

int32_t arivu_profile_select(const arivu_profile * candidates, size_t n, const arivu_device * d) {
    if (candidates == nullptr || d == nullptr) return -1;
    for (size_t i = 0; i < n; ++i) {
        if (arivu_profile_fits(&candidates[i], d).fit == ARIVU_FIT_OK) return (int32_t) i;
    }
    return -1;
}

const char * arivu_fit_name(arivu_fit fit) {
    switch (fit) {
        case ARIVU_FIT_OK:               return "ok";
        case ARIVU_FIT_INVALID_PROFILE:  return "invalid_profile";
        case ARIVU_FIT_NO_ARM64:         return "no_arm64";
        case ARIVU_FIT_LOW_RAM_DEVICE:   return "low_ram_device";
        case ARIVU_FIT_TOTAL_RAM:        return "total_ram";
        case ARIVU_FIT_AVAILABLE_MEMORY: return "available_memory";
        case ARIVU_FIT_STORAGE:          return "storage";
    }
    return "unknown";
}

const char * arivu_stop_reason_name(arivu_stop_reason reason) {
    switch (reason) {
        case ARIVU_STOP_END_OF_TURN:  return "end_of_turn";
        case ARIVU_STOP_CANCELLED:    return "cancelled";
        case ARIVU_STOP_CONTEXT_FULL: return "context_full";
        case ARIVU_STOP_MAX_TOKENS:   return "max_tokens";
        case ARIVU_STOP_ERROR:        return "error";
    }
    return "unknown";
}

}  // extern "C"
