// Arivu inference engine. Plain C++ over llama.cpp, no JNI, so the host smoke
// test (tools/host/) exercises exactly the code the app ships.
//
// Memory model (CLAUDE.md "Lifecycle"): the model is mmap'd and file-backed, so
// the kernel may evict it; the context owns the KV cache and is freed explicitly.
#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <string>
#include <vector>

struct llama_model;
struct llama_context;
struct llama_sampler;

namespace arivu {

enum class StopReason : int {
    EndOfTurn   = 0,
    Cancelled   = 1,
    ContextFull = 2,  // spine: C7 — surfaced to the user, never silent
    MaxTokens   = 3,
    Error       = 4,
};

struct ContextConfig {
    int  n_ctx     = 2048;
    int  n_batch   = 512;
    int  n_threads = 4;
    bool kv_q8_0   = true;
};

struct Sampling {
    float    temperature = 0.7f;
    int32_t  top_k       = 20;
    float    top_p       = 0.8f;
    uint32_t seed        = 0xA417;
};

struct GenerationStats {
    StopReason  stop            = StopReason::EndOfTurn;
    int         prompt_tokens   = 0;
    int         reused_tokens   = 0;
    int         generated       = 0;
    double      prefill_ms      = 0;
    double      decode_ms       = 0;
    std::string error;
};

// Receives complete UTF-8 byte sequences only.
using PieceCallback = std::function<void(const char * bytes, size_t len)>;

class Engine {
public:
    Engine();
    ~Engine();
    Engine(const Engine &) = delete;
    Engine & operator=(const Engine &) = delete;

    // Weights. use_repack=false keeps every weight page file-backed (evictable).
    bool load_model_fd(int fd, uint64_t offset, uint64_t length, bool use_repack, std::string * err);
    bool load_model_path(const std::string & path, bool use_repack, std::string * err);
    bool has_model() const { return model_ != nullptr; }
    void free_model();  // also frees the context

    // KV cache + compute buffers. Created lazily, freed explicitly.
    bool ensure_context(const ContextConfig & cfg, std::string * err);
    bool has_context() const { return ctx_ != nullptr; }
    void free_context();
    int  n_ctx() const;

    // Token count of text as the model sees it (special tokens parsed).
    int count_tokens(const std::string & text) const;

    // Decodes `prompt`, reusing any KV prefix shared with the previous call,
    // then samples until end-of-turn, cancel, context full, or max_new tokens.
    GenerationStats generate(const std::string & prompt, int max_new, const Sampling & sampling,
                             const PieceCallback & on_piece);

    // Thread-safe. Aborts prefill mid-batch and decode at the next token.
    void request_cancel() { cancel_.store(true); }

private:
    bool tokenize(const std::string & text, std::vector<int32_t> & out) const;
    bool decode_tokens(const std::vector<int32_t> & tokens, size_t from, std::string * err);
    static bool abort_cb(void * data);

    llama_model *   model_ = nullptr;
    llama_context * ctx_   = nullptr;
    ContextConfig   cfg_;
    std::vector<int32_t> cached_;  // tokens currently in the KV cache, in order
    std::atomic<bool> cancel_{false};
};

// Number of bytes at the front of buf[0..len) that form complete UTF-8 sequences.
size_t utf8_complete_prefix(const char * buf, size_t len);

}  // namespace arivu
