// Arivu shared prompt building and token-budget truncation (C++ side).
//
// MULTIPLATFORM.md appendix lists "prompt + chat template handling" and "token budgeting &
// truncation policy" as genuinely shared: "keep whole turns" is a product decision, not a
// platform one. This is the port of
// android/app/src/main/java/io/github/brettleehari/arivu/app/inference/PromptBuilder.kt,
// behaviour for behaviour, so it is written once (spine: C7, C11).
//
// No llama.cpp here: token counting arrives as a callback, so this file builds and is tested
// with no model, no llama and no platform SDK.
#pragma once

#include <cstddef>
#include <cstdint>
#include <functional>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

namespace arivu {

// A turn as the prompt sees it. `id` is stable for the life of the turn; it keys the count cache.
struct Turn {
    std::string id;
    bool        from_user = true;
    std::string text;
};

enum class PromptStatus : int {
    Ok       = 0,
    TooLong  = 1,  // the newest user message alone does not fit; nothing is truncated silently
    Invalid  = 2,  // empty history, or the newest turn is not the user's
};

struct BuiltPrompt {
    PromptStatus status = PromptStatus::Ok;
    std::string  text;            // Ok only
    int          prompt_tokens  = 0;   // Ok only
    // Index of the oldest turn the model sees. Anything before it was dropped and must be shown
    // as dropped (spine: C7).
    int          first_included = 0;   // Ok only
    int          message_tokens = 0;   // TooLong only
    int          limit_tokens   = 0;   // TooLong only
};

// Counts tokens in `text` as the model sees it. Negative means the count failed; build() then
// reports Invalid rather than guessing.
using TokenCountFn = std::function<int(const std::string & text)>;

// Qwen3 ChatML in non-thinking mode (decisions.yml D-007).
extern const char * const kAssistantOpen;   // "<|im_start|>assistant\n<think>\n\n</think>\n\n"
std::string render_system(const std::string & system_prompt);
std::string render_turn(const Turn & turn);

// History is dropped oldest-first, whole turns only, until system + turns + reply reserve fit.
// The cache is an optimisation only: results do not depend on it.
class PromptBuilder {
public:
    PromptBuilder(std::string system_prompt, int n_ctx, int reply_reserve, TokenCountFn count)
        : system_prompt_(std::move(system_prompt)), n_ctx_(n_ctx), reply_reserve_(reply_reserve),
          count_(std::move(count)) {}

    BuiltPrompt build(const std::vector<Turn> & turns);

private:
    int tokens_of(const Turn & turn);

    std::string  system_prompt_;
    int          n_ctx_;
    int          reply_reserve_;
    TokenCountFn count_;
    std::unordered_map<std::string, int> cache_;
};

}  // namespace arivu
