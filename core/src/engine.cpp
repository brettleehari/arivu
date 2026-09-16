#include "arivu/engine.h"

#include "llama.h"

#include <algorithm>
#include <chrono>
#include <mutex>

namespace arivu {

namespace {

using clock_type = std::chrono::steady_clock;

double ms_since(clock_type::time_point t0) {
    return std::chrono::duration<double, std::milli>(clock_type::now() - t0).count();
}

void backend_init_once() {
    static std::once_flag once;
    std::call_once(once, [] { llama_backend_init(); });
}

llama_model_params model_params(bool use_repack) {
    llama_model_params p = llama_model_default_params();
    p.n_gpu_layers    = 0;
    p.load_mode       = LLAMA_LOAD_MODE_MMAP;  // never MLOCK: pinning defeats eviction
    // Repacked weights live in anonymous memory, which would add ~400MB of
    // unreclaimable RSS. Off by default; the benchmark measures both.
    p.use_extra_bufts = use_repack;
    return p;
}

}  // namespace

size_t utf8_complete_prefix(const char * buf, size_t len) {
    // Walk back from the end over at most 3 continuation bytes to find a lead byte.
    size_t i = len;
    size_t back = 0;
    while (i > 0 && back < 4) {
        unsigned char c = (unsigned char) buf[i - 1];
        if ((c & 0xC0) != 0x80) {
            size_t need = (c < 0x80) ? 1 : ((c & 0xE0) == 0xC0) ? 2 : ((c & 0xF0) == 0xE0) ? 3 : ((c & 0xF8) == 0xF0) ? 4 : 1;
            return (back + 1 >= need) ? len : i - 1;
        }
        --i;
        ++back;
    }
    return len;  // malformed run of continuation bytes: pass through rather than stall
}

Engine::Engine() { backend_init_once(); }

Engine::~Engine() { free_model(); }

bool Engine::load_model_fd(int fd, uint64_t offset, uint64_t length, bool use_repack, std::string * err) {
    free_model();
    model_ = llama_model_load_from_fd(fd, offset, length, model_params(use_repack));
    if (!model_ && err) *err = "failed to load model from fd window";
    return model_ != nullptr;
}

bool Engine::load_model_path(const std::string & path, bool use_repack, std::string * err) {
    free_model();
    model_ = llama_model_load_from_file(path.c_str(), model_params(use_repack));
    if (!model_ && err) *err = "failed to load model from " + path;
    return model_ != nullptr;
}

void Engine::free_model() {
    free_context();
    if (model_) {
        llama_model_free(model_);
        model_ = nullptr;
    }
}

bool Engine::abort_cb(void * data) {
    return static_cast<Engine *>(data)->cancel_.load();
}

bool Engine::ensure_context(const ContextConfig & cfg, std::string * err) {
    if (!model_) {
        if (err) *err = "no model loaded";
        return false;
    }
    if (ctx_ && cfg.n_ctx == cfg_.n_ctx && cfg.n_batch == cfg_.n_batch &&
        cfg.n_threads == cfg_.n_threads && cfg.kv_q8_0 == cfg_.kv_q8_0) {
        return true;
    }
    free_context();

    llama_context_params p = llama_context_default_params();
    p.n_ctx           = (uint32_t) cfg.n_ctx;
    p.n_batch         = (uint32_t) cfg.n_batch;
    p.n_ubatch        = (uint32_t) cfg.n_batch;
    p.n_seq_max       = 1;
    // spine: C2 — we only ever read logits for the last token of a batch. The default (n_batch outputs)
    // reserves n_batch x vocab x 4 bytes of logits (~300 MiB of compute buffer); 1 output reserves ~28 MiB.
    // Measured on host: leaves/architecture.md B1, leaves/NOTES.md.
    p.n_outputs_max         = 1;
    p.n_outputs_max_per_seq = 1;
    p.n_threads       = cfg.n_threads;
    p.n_threads_batch = cfg.n_threads;
    p.no_perf         = true;
    if (cfg.kv_q8_0) {
        p.type_k          = GGML_TYPE_Q8_0;
        p.type_v          = GGML_TYPE_Q8_0;
        p.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED;  // quantized V cache requires it
    }
    p.abort_callback      = &Engine::abort_cb;
    p.abort_callback_data = this;

    ctx_ = llama_init_from_model(model_, p);
    if (!ctx_) {
        if (err) *err = "failed to create context";
        return false;
    }
    cfg_ = cfg;
    cached_.clear();
    return true;
}

void Engine::free_context() {
    if (ctx_) {
        llama_free(ctx_);
        ctx_ = nullptr;
    }
    cached_.clear();
}

int Engine::n_ctx() const { return ctx_ ? (int) llama_n_ctx(ctx_) : cfg_.n_ctx; }

bool Engine::tokenize(const std::string & text, std::vector<int32_t> & out) const {
    if (!model_) return false;
    const llama_vocab * vocab = llama_model_get_vocab(model_);
    out.resize(text.size() + 8);
    int n = llama_tokenize(vocab, text.data(), (int32_t) text.size(), out.data(), (int32_t) out.size(),
                           /*add_special*/ false, /*parse_special*/ true);
    if (n < 0) {
        out.resize((size_t) -n);
        n = llama_tokenize(vocab, text.data(), (int32_t) text.size(), out.data(), (int32_t) out.size(), false, true);
    }
    if (n < 0) return false;
    out.resize((size_t) n);
    return true;
}

int Engine::count_tokens(const std::string & text) const {
    std::vector<int32_t> toks;
    return tokenize(text, toks) ? (int) toks.size() : -1;
}

bool Engine::decode_tokens(const std::vector<int32_t> & tokens, size_t from, std::string * err) {
    const size_t n_batch = (size_t) cfg_.n_batch;
    llama_batch batch = llama_batch_init((int32_t) n_batch, 0, 1);
    bool ok = true;
    for (size_t i = from; i < tokens.size() && ok; i += n_batch) {
        const size_t n = std::min(n_batch, tokens.size() - i);
        batch.n_tokens = (int32_t) n;
        for (size_t j = 0; j < n; ++j) {
            batch.token[j]     = tokens[i + j];
            batch.pos[j]       = (llama_pos) (i + j);
            batch.n_seq_id[j]  = 1;
            batch.seq_id[j][0] = 0;
            batch.logits[j]    = (i + j == tokens.size() - 1);
        }
        const int32_t rc = llama_decode(ctx_, batch);
        if (rc != 0) {
            ok = false;
            if (err) *err = rc == 2 ? "aborted" : rc == 1 ? "no KV slot" : "decode failed (" + std::to_string(rc) + ")";
        } else {
            cached_.insert(cached_.end(), tokens.begin() + (long) i, tokens.begin() + (long) (i + n));
        }
    }
    llama_batch_free(batch);
    return ok;
}

GenerationStats Engine::generate(const std::string & prompt, int max_new, const Sampling & s,
                                 const PieceCallback & on_piece) {
    GenerationStats st;
    cancel_.store(false);
    if (!ctx_) {
        st.stop  = StopReason::Error;
        st.error = "no context";
        return st;
    }

    std::vector<int32_t> tokens;
    if (!tokenize(prompt, tokens) || tokens.empty()) {
        st.stop  = StopReason::Error;
        st.error = "tokenize failed";
        return st;
    }
    st.prompt_tokens = (int) tokens.size();
    const int n_ctx = (int) llama_n_ctx(ctx_);
    if ((int) tokens.size() >= n_ctx) {
        st.stop = StopReason::ContextFull;
        return st;
    }

    // Reuse the shared KV prefix; always re-decode at least the last prompt token for logits.
    size_t keep = 0;
    while (keep < cached_.size() && keep < tokens.size() && cached_[keep] == tokens[keep]) ++keep;
    keep = std::min(keep, tokens.size() - 1);
    llama_memory_t mem = llama_get_memory(ctx_);
    if (!llama_memory_seq_rm(mem, 0, (llama_pos) keep, -1)) {
        llama_memory_clear(mem, true);
        keep = 0;
    }
    cached_.resize(keep);
    st.reused_tokens = (int) keep;

    auto t0 = clock_type::now();
    std::string err;
    if (!decode_tokens(tokens, keep, &err)) {
        // Partial ubatches may remain in memory; start clean next time.
        llama_memory_clear(mem, true);
        cached_.clear();
        st.prefill_ms = ms_since(t0);
        st.stop  = cancel_.load() ? StopReason::Cancelled : StopReason::Error;
        st.error = err;
        return st;
    }
    st.prefill_ms = ms_since(t0);

    llama_sampler * chain = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(chain, llama_sampler_init_top_k(s.top_k));
    llama_sampler_chain_add(chain, llama_sampler_init_top_p(s.top_p, 1));
    if (s.temperature <= 0) {
        llama_sampler_chain_add(chain, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(chain, llama_sampler_init_temp(s.temperature));
        llama_sampler_chain_add(chain, llama_sampler_init_dist(s.seed));
    }

    const llama_vocab * vocab = llama_model_get_vocab(model_);
    bool first_piece = true;
    std::string pending;
    char piece[256];
    auto t1 = clock_type::now();
    st.stop = StopReason::MaxTokens;
    for (int i = 0; i < max_new; ++i) {
        if (cancel_.load()) { st.stop = StopReason::Cancelled; break; }
        const llama_token tok = llama_sampler_sample(chain, ctx_, -1);
        if (llama_vocab_is_eog(vocab, tok)) { st.stop = StopReason::EndOfTurn; break; }
        if ((int) cached_.size() >= n_ctx) { st.stop = StopReason::ContextFull; break; }

        const int32_t n = llama_token_to_piece(vocab, tok, piece, sizeof(piece), 0, false);
        if (n > 0) {
            pending.append(piece, (size_t) n);
            const size_t ready = utf8_complete_prefix(pending.data(), pending.size());
            if (ready > 0) {
                if (first_piece) {
                    st.first_token_ms = ms_since(t0);
                    first_piece = false;
                }
                on_piece(pending.data(), ready);
                pending.erase(0, ready);
            }
        }
        ++st.generated;

        llama_batch one = llama_batch_init(1, 0, 1);
        one.n_tokens = 1;
        one.token[0] = tok;
        one.pos[0] = (llama_pos) cached_.size();
        one.n_seq_id[0] = 1;
        one.seq_id[0][0] = 0;
        one.logits[0] = true;
        const int32_t rc = llama_decode(ctx_, one);
        llama_batch_free(one);
        if (rc != 0) {
            if (rc == 2) { st.stop = StopReason::Cancelled; }
            else { st.stop = StopReason::Error; st.error = "decode failed (" + std::to_string(rc) + ")"; }
            llama_memory_clear(mem, true);
            cached_.clear();
            break;
        }
        cached_.push_back(tok);
    }
    if (!pending.empty()) {
        if (first_piece) {
            st.first_token_ms = ms_since(t0);
            first_piece = false;
        }
        on_piece(pending.data(), pending.size());
    }
    st.decode_ms = ms_since(t1);
    llama_sampler_free(chain);
    return st;
}

}  // namespace arivu
