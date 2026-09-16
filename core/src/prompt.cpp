// Shared prompt building and truncation policy (see include/arivu/prompt.h), plus the C
// wrapper both platforms bind to. Ported from PromptBuilder.kt without behaviour change;
// core/tests/test_logic.cpp runs the same cases as PromptBuilderTest.kt (spine: C7, C11).
#include "arivu/prompt.h"

#include "arivu/arivu.h"

#include <cstring>
#include <new>

namespace arivu {

const char * const kAssistantOpen = "<|im_start|>assistant\n<think>\n\n</think>\n\n";

std::string render_system(const std::string & system_prompt) {
    return "<|im_start|>system\n" + system_prompt + "<|im_end|>\n";
}

std::string render_turn(const Turn & turn) {
    // Previous assistant turns are rendered without a think block, matching Qwen3's template.
    return std::string("<|im_start|>") + (turn.from_user ? "user" : "assistant") + "\n" + turn.text + "<|im_end|>\n";
}

int PromptBuilder::tokens_of(const Turn & turn) {
    const std::string key = turn.id + ":" + std::to_string(turn.text.size());
    auto it = cache_.find(key);
    if (it != cache_.end()) return it->second;
    const int n = count_(render_turn(turn));
    if (n >= 0) cache_.emplace(key, n);
    return n;
}

BuiltPrompt PromptBuilder::build(const std::vector<Turn> & turns) {
    BuiltPrompt out;
    // PromptBuilder.kt throws here; a C API cannot, so the caller gets a status instead.
    if (turns.empty() || !turns.back().from_user) {
        out.status = PromptStatus::Invalid;
        return out;
    }
    const std::string header = render_system(system_prompt_);
    const std::string footer = kAssistantOpen;
    const int header_tokens = count_(header);
    const int footer_tokens = count_(footer);
    if (header_tokens < 0 || footer_tokens < 0) {
        out.status = PromptStatus::Invalid;
        return out;
    }
    const int fixed  = header_tokens + footer_tokens;
    const int budget = n_ctx_ - reply_reserve_ - fixed;

    const int newest = tokens_of(turns.back());
    if (newest < 0) {
        out.status = PromptStatus::Invalid;
        return out;
    }
    if (newest > budget) {
        out.status         = PromptStatus::TooLong;
        out.message_tokens = newest;
        out.limit_tokens   = budget;
        return out;
    }

    int    used  = 0;
    size_t first = turns.size();
    for (size_t i = turns.size(); i-- > 0;) {
        const int t = tokens_of(turns[i]);
        if (t < 0) {
            out.status = PromptStatus::Invalid;
            return out;
        }
        if (used + t > budget) break;
        used += t;
        first = i;
    }
    // Never start the visible window on an assistant reply without the question before it.
    while (first + 1 < turns.size() && !turns[first].from_user) {
        used -= tokens_of(turns[first]);
        ++first;
    }

    out.text = header;
    for (size_t i = first; i < turns.size(); ++i) out.text += render_turn(turns[i]);
    out.text += footer;
    out.status         = PromptStatus::Ok;
    out.prompt_tokens  = fixed + used;
    out.first_included = (int) first;
    return out;
}

}  // namespace arivu

// ---------------------------------------------------------------------------------------------
// C API. No llama.cpp, no platform SDK: this half of the boundary is pure policy.

struct arivu_prompt_builder {
    arivu::PromptBuilder impl;
    arivu_prompt_builder(const char * system_prompt, int32_t n_ctx, int32_t reply_reserve,
                         arivu::TokenCountFn count)
        : impl(system_prompt != nullptr ? system_prompt : "", n_ctx, reply_reserve, std::move(count)) {}
};

extern "C" {

const char * arivu_assistant_open(void) { return arivu::kAssistantOpen; }

arivu_prompt_builder * arivu_prompt_builder_create(const char * system_prompt, int32_t n_ctx,
                                                   int32_t reply_reserve, arivu_count_fn count,
                                                   void * user_data) {
    if (count == nullptr) return nullptr;
    return new (std::nothrow) arivu_prompt_builder(
        system_prompt, n_ctx, reply_reserve,
        [count, user_data](const std::string & text) {
            return (int) count(text.data(), text.size(), user_data);
        });
}

void arivu_prompt_builder_free(arivu_prompt_builder * b) { delete b; }

arivu_prompt_result arivu_prompt_builder_build(arivu_prompt_builder * b, const arivu_turn * turns,
                                               size_t n_turns, char * out_buf, size_t out_cap,
                                               size_t * out_len) {
    arivu_prompt_result r;
    r.status           = ARIVU_PROMPT_INVALID;
    r.prompt_tokens    = 0;
    r.first_included   = 0;
    r.message_tokens   = 0;
    r.limit_tokens     = 0;
    r.text_len         = 0;
    r.output_truncated = false;
    if (b == nullptr || (turns == nullptr && n_turns > 0)) return r;

    std::vector<arivu::Turn> v;
    v.reserve(n_turns);
    for (size_t i = 0; i < n_turns; ++i) {
        arivu::Turn t;
        t.id        = turns[i].id != nullptr ? turns[i].id : "";
        t.from_user = turns[i].from_user;
        if (turns[i].text != nullptr) t.text.assign(turns[i].text, turns[i].text_len);
        v.push_back(std::move(t));
    }

    const arivu::BuiltPrompt built = b->impl.build(v);
    r.status         = (arivu_prompt_status) (int) built.status;
    r.prompt_tokens  = built.prompt_tokens;
    r.first_included = built.first_included;
    r.message_tokens = built.message_tokens;
    r.limit_tokens   = built.limit_tokens;
    r.text_len       = built.text.size();
    if (out_len != nullptr) *out_len = built.text.size();
    if (built.status == arivu::PromptStatus::Ok && out_buf != nullptr && out_cap > 0) {
        const size_t n = built.text.size() < out_cap - 1 ? built.text.size() : out_cap - 1;
        std::memcpy(out_buf, built.text.data(), n);
        out_buf[n] = '\0';
        r.output_truncated = n != built.text.size();
    } else if (built.status == arivu::PromptStatus::Ok && built.text.size() > 0) {
        r.output_truncated = true;
    }
    return r;
}

}  // extern "C"
