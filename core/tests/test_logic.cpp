// Core logic tests: no model, no llama.cpp, no platform SDK, no test framework. Seconds.
//
//   tools/core_test.sh
//
// Covers the parts of /core that are product logic rather than inference:
//   1. UTF-8 boundary buffering                          (spine: C10 — streaming never shows a broken glyph)
//   2. Prompt building and token-budget truncation       (spine: C7 — the same cases as PromptBuilderTest.kt)
//   3. The prompt C API                                  (spine: C11)
//   4. Device profiles and "can this device run it"      (spine: C11, C6)
//   5. Stop-reason mapping across the C boundary         (spine: C7)
#include "check.h"

#include "arivu/arivu.h"
#include "arivu/engine.h"
#include "arivu/prompt.h"

#include <string>
#include <vector>

using arivu::Turn;

namespace {

// One token per character keeps the arithmetic obvious — exactly what PromptBuilderTest.kt does.
int one_per_char(const std::string & s) { return (int) s.size(); }

Turn turn(int i, bool user, size_t len) {
    Turn t;
    t.id        = "t" + std::to_string(i);
    t.from_user = user;
    // Same length as PromptBuilderTest.kt's "x".repeat(len) — the arithmetic is one token per
    // character — but a different filler per turn, so a dropped turn cannot be mistaken for a kept one.
    t.text      = std::string(len, (char) ('a' + (i % 26)));
    return t;
}

int rendered(const Turn & t) { return (int) arivu::render_turn(t).size(); }

arivu::PromptBuilder builder(int n_ctx, int reserve) {
    return arivu::PromptBuilder("sys", n_ctx, reserve, one_per_char);
}

int32_t count_cb(const char * utf8, size_t len, void *) {
    (void) utf8;
    return (int32_t) len;
}

void test_utf8() {
    check::section("utf8 boundary buffering");
    const char euro[] = "a\xE2\x82\xAC";  // "a€"
    CHECK_EQ(arivu::utf8_complete_prefix(euro, 2), (size_t) 1);
    CHECK_EQ(arivu::utf8_complete_prefix(euro, 3), (size_t) 1);
    CHECK_EQ(arivu::utf8_complete_prefix(euro, 4), (size_t) 4);
    CHECK_EQ(arivu::utf8_complete_prefix("plain", 5), (size_t) 5);

    const char two[] = "\xC3\xA9";        // "é"
    CHECK_EQ(arivu::utf8_complete_prefix(two, 1), (size_t) 0);
    CHECK_EQ(arivu::utf8_complete_prefix(two, 2), (size_t) 2);

    const char four[] = "ok\xF0\x9F\x99\x82";  // "ok🙂"
    CHECK_EQ(arivu::utf8_complete_prefix(four, 3), (size_t) 2);
    CHECK_EQ(arivu::utf8_complete_prefix(four, 5), (size_t) 2);
    CHECK_EQ(arivu::utf8_complete_prefix(four, 6), (size_t) 6);

    // Devanagari and Tamil: the users in the Spine do not write in ASCII.
    const std::string tamil = "\xE0\xAE\x85\xE0\xAE\xB1\xE0\xAE\xBF\xE0\xAE\xB5\xE0\xAF\x81";  // "அறிவு"
    CHECK_EQ(arivu::utf8_complete_prefix(tamil.data(), tamil.size()), tamil.size());
    CHECK_EQ(arivu::utf8_complete_prefix(tamil.data(), tamil.size() - 1), tamil.size() - 3);

    // A malformed run of continuation bytes must pass through, not stall the stream forever.
    const char bad[] = "\x80\x80\x80\x80\x80";
    CHECK_EQ(arivu::utf8_complete_prefix(bad, 5), (size_t) 5);

    // The C entry point is the same rule, and tolerates the empty case.
    CHECK_EQ(arivu_utf8_complete_prefix(euro, 2), (size_t) 1);
    CHECK_EQ(arivu_utf8_complete_prefix(nullptr, 4), (size_t) 0);
    CHECK_EQ(arivu_utf8_complete_prefix(euro, 0), (size_t) 0);
}

void test_template() {
    check::section("chat template matches PromptBuilder.kt byte for byte");
    CHECK_STR(arivu::render_system("sys"), "<|im_start|>system\nsys<|im_end|>\n");
    CHECK_STR(std::string(arivu::kAssistantOpen), "<|im_start|>assistant\n<think>\n\n</think>\n\n");
    CHECK_STR(std::string(arivu_assistant_open()), "<|im_start|>assistant\n<think>\n\n</think>\n\n");
    Turn u = turn(0, true, 0);
    u.text = "hello";
    CHECK_STR(arivu::render_turn(u), "<|im_start|>user\nhello<|im_end|>\n");
    Turn a = u;
    a.from_user = false;
    CHECK_STR(arivu::render_turn(a), "<|im_start|>assistant\nhello<|im_end|>\n");
}

void test_prompt_budget() {
    const int fixed = (int) arivu::render_system("sys").size() + (int) std::strlen(arivu::kAssistantOpen);

    check::section("everything fits: first included is 0");
    {
        std::vector<Turn> turns = {turn(0, true, 10), turn(1, false, 10), turn(2, true, 10)};
        arivu::PromptBuilder b = builder(2048, 512);
        const arivu::BuiltPrompt r = b.build(turns);
        CHECK(r.status == arivu::PromptStatus::Ok);
        CHECK_EQ(r.first_included, 0);
        CHECK(r.text.rfind(arivu::render_system("sys"), 0) == 0);
        CHECK(r.text.size() >= std::strlen(arivu::kAssistantOpen) &&
              r.text.compare(r.text.size() - std::strlen(arivu::kAssistantOpen), std::string::npos,
                             arivu::kAssistantOpen) == 0);
        CHECK_EQ((size_t) r.prompt_tokens, r.text.size());
    }

    check::section("oldest turns dropped, window starts on a user turn (spine: C7)");
    {
        std::vector<Turn> turns = {turn(0, true, 100), turn(1, false, 100), turn(2, true, 100),
                                   turn(3, false, 100), turn(4, true, 100)};
        // Room for exactly turns 2, 3, 4. Turn 2 is a user turn.
        const int budget = rendered(turns[2]) + rendered(turns[3]) + rendered(turns[4]);
        arivu::PromptBuilder b = builder(fixed + budget + 50, 50);
        const arivu::BuiltPrompt r = b.build(turns);
        CHECK(r.status == arivu::PromptStatus::Ok);
        CHECK_EQ(r.first_included, 2);

        // Room for turns 3, 4 would start on assistant turn 3; the builder must skip to user turn 4.
        arivu::PromptBuilder b2 = builder(fixed + rendered(turns[3]) + rendered(turns[4]) + 50, 50);
        const arivu::BuiltPrompt r2 = b2.build(turns);
        CHECK(r2.status == arivu::PromptStatus::Ok);
        CHECK_EQ(r2.first_included, 4);
        // The dropped turns really are absent from the text the model sees.
        CHECK(r2.text.find(arivu::render_turn(turns[0])) == std::string::npos);
        CHECK(r2.text.find(arivu::render_turn(turns[4])) != std::string::npos);
    }

    check::section("newest message too long is reported, not truncated (spine: C7)");
    {
        std::vector<Turn> turns = {turn(0, true, 5000)};
        arivu::PromptBuilder b = builder(2048, 512);
        const arivu::BuiltPrompt r = b.build(turns);
        CHECK(r.status == arivu::PromptStatus::TooLong);
        CHECK_EQ(r.message_tokens, rendered(turns[0]));
        CHECK_EQ(r.limit_tokens, 2048 - 512 - fixed);
        CHECK(r.text.empty());
    }

    check::section("exact-fit boundary");
    {
        // A turn costing exactly the budget fits; one byte more does not.
        std::vector<Turn> turns = {turn(0, true, 100)};
        const int cost = rendered(turns[0]);
        arivu::PromptBuilder tight = builder(fixed + cost + 50, 50);
        CHECK(tight.build(turns).status == arivu::PromptStatus::Ok);
        arivu::PromptBuilder over = builder(fixed + cost + 49, 50);
        CHECK(over.build(turns).status == arivu::PromptStatus::TooLong);
    }

    check::section("invalid history is refused, never guessed at");
    {
        arivu::PromptBuilder b = builder(2048, 512);
        CHECK(b.build({}).status == arivu::PromptStatus::Invalid);
        std::vector<Turn> ends_on_assistant = {turn(0, true, 10), turn(1, false, 10)};
        CHECK(b.build(ends_on_assistant).status == arivu::PromptStatus::Invalid);
        // A counter that fails (no model loaded, for instance) is Invalid, not a guess.
        arivu::PromptBuilder broken("sys", 2048, 512, [](const std::string &) { return -1; });
        std::vector<Turn> one = {turn(0, true, 10)};
        CHECK(broken.build(one).status == arivu::PromptStatus::Invalid);
    }

    check::section("the count cache does not change the answer");
    {
        int calls = 0;
        arivu::PromptBuilder b("sys", 2048, 512, [&calls](const std::string & s) {
            ++calls;
            return (int) s.size();
        });
        std::vector<Turn> turns = {turn(0, true, 10), turn(1, false, 10), turn(2, true, 10)};
        const arivu::BuiltPrompt a = b.build(turns);
        const int after_first = calls;
        const arivu::BuiltPrompt c = b.build(turns);
        CHECK_STR(a.text, c.text);
        CHECK_EQ(a.prompt_tokens, c.prompt_tokens);
        CHECK(calls - after_first < after_first);  // the second build reuses the cached counts
    }
}

void test_prompt_c_api() {
    check::section("prompt C API");
    CHECK(arivu_prompt_builder_create("sys", 2048, 512, nullptr, nullptr) == nullptr);

    arivu_prompt_builder * b = arivu_prompt_builder_create("sys", 2048, 512, count_cb, nullptr);
    CHECK(b != nullptr);

    const std::string hello = "hello";
    arivu_turn turns[1];
    turns[0].id        = "t0";
    turns[0].text      = hello.data();
    turns[0].text_len  = hello.size();
    turns[0].from_user = true;

    // Measuring pass: no buffer, but the full length comes back.
    size_t needed = 0;
    arivu_prompt_result r = arivu_prompt_builder_build(b, turns, 1, nullptr, 0, &needed);
    CHECK(r.status == ARIVU_PROMPT_OK);
    CHECK(needed > 0);
    CHECK_EQ(r.text_len, needed);
    CHECK_EQ(r.first_included, 0);

    std::vector<char> buf(needed + 1, '\0');
    r = arivu_prompt_builder_build(b, turns, 1, buf.data(), buf.size(), nullptr);
    CHECK(r.status == ARIVU_PROMPT_OK);
    CHECK(!r.output_truncated);
    Turn t;
    t.id = "t0";
    t.from_user = true;
    t.text = hello;
    CHECK_STR(std::string(buf.data()),
              arivu::render_system("sys") + arivu::render_turn(t) + arivu::kAssistantOpen);

    // A buffer that is too small says so instead of writing past it.
    std::vector<char> small(8, 'Z');
    r = arivu_prompt_builder_build(b, turns, 1, small.data(), small.size(), nullptr);
    CHECK(r.output_truncated);
    CHECK_EQ(r.text_len, needed);
    CHECK_EQ(std::strlen(small.data()), (size_t) 7);

    CHECK(arivu_prompt_builder_build(b, nullptr, 0, nullptr, 0, nullptr).status == ARIVU_PROMPT_INVALID);
    CHECK(arivu_prompt_builder_build(nullptr, turns, 1, nullptr, 0, nullptr).status == ARIVU_PROMPT_INVALID);
    arivu_prompt_builder_free(b);
    arivu_prompt_builder_free(nullptr);
}

arivu_device good_device() {
    // `{}`, not a bare declaration: arivu_device grows, and a caller that assigns field by field
    // inherits garbage in whatever was added since. That is exactly what happened when
    // observed_footprint_bytes arrived — these tests started demanding 8.6 GB.
    arivu_device d{};
    d.total_ram_bytes        = 4ull * 1024 * 1024 * 1024;
    d.available_memory_bytes = 0;
    d.free_storage_bytes     = 2ull * 1024 * 1024 * 1024;
    d.performance_cores      = 4;
    d.arm64                  = true;
    d.low_ram_flagged        = false;
    d.memory_source          = ARIVU_MEM_UNMEASURED;  // Android has no honest answer to give
    return d;
}

void test_profile() {
    check::section("the default profile is what ships today (spine: C8, C11)");
    const arivu_profile p = arivu_default_profile();
    char err[128] = {0};
    CHECK(arivu_profile_valid(&p, err, sizeof err));
    CHECK_STR(std::string(p.model_id), "qwen3-0.6b-q4km");
    CHECK_EQ(p.n_ctx, 2048);
    CHECK_EQ(p.n_batch, 512);
    CHECK_EQ(p.n_threads, 4);
    CHECK(p.kv_q8_0);
    CHECK(!p.repack);
    CHECK_EQ(p.reply_reserve_tokens, 512);
    CHECK_EQ(p.max_reply_tokens, 768);
    CHECK(arivu_profile_has(&p, ARIVU_CAP_CHAT));
    CHECK(!arivu_profile_has(&p, ARIVU_CAP_TOOLS));      // SPINE R2
    CHECK(!arivu_profile_has(&p, ARIVU_CAP_LONGFORM));
    CHECK(!arivu_profile_has(nullptr, ARIVU_CAP_CHAT));

    // The context params the engine is given come from the profile, not from a platform default.
    const arivu_context_params c = arivu_profile_context_params(&p);
    CHECK_EQ(c.n_ctx, p.n_ctx);
    CHECK_EQ(c.n_batch, p.n_batch);
    CHECK_EQ(c.n_threads, p.n_threads);
    CHECK(c.kv_q8_0 == p.kv_q8_0);
    CHECK(c.repack == p.repack);
    // And they are the same numbers the C API has always defaulted to, so nothing moved.
    const arivu_context_params d = arivu_default_context_params();
    CHECK_EQ(c.n_ctx, d.n_ctx);
    CHECK_EQ(c.n_batch, d.n_batch);
    CHECK_EQ(c.n_threads, d.n_threads);

    check::section("peak estimate stays inside the M3 budget");
    const uint64_t peak      = arivu_profile_estimated_peak_bytes(&p);
    const uint64_t mapped    = arivu_profile_mapped_bytes(&p);
    const uint64_t footprint = arivu_profile_footprint_bytes(&p);
    CHECK_EQ(peak, p.model_bytes + p.kv_bytes_per_token * 2048 + p.compute_buffer_bytes + p.runtime_overhead_bytes);
    CHECK(peak < 800ull * 1000 * 1000);   // M3: peak RSS <= 800 MB
    std::printf("       peak %.0f MB = mapped %.0f MB + charged footprint %.0f MB\n",
                peak / 1e6, mapped / 1e6, footprint / 1e6);

    check::section("the two halves of the memory model (architecture B23)");
    // The weights are mmap'd, clean and evictable: they are the mapped half, and a footprint
    // accounting that excludes clean file-backed pages must not be charged for them.
    CHECK_EQ(mapped, p.model_bytes);
    CHECK_EQ(footprint, p.kv_bytes_per_token * 2048 + p.compute_buffer_bytes + p.runtime_overhead_bytes);
    CHECK_EQ(mapped + footprint, peak);
    CHECK(footprint < mapped);   // the charged half is the smaller one, which is the entire point
    // Repacking copies the weights into anonymous memory; the mapping stays, so the copy lands in
    // the charged half and the peak grows by a whole model. That is why D-015 leaves it off.
    arivu_profile repacked = p;
    repacked.repack = true;
    CHECK_EQ(arivu_profile_mapped_bytes(&repacked), mapped);
    CHECK_EQ(arivu_profile_footprint_bytes(&repacked), footprint + p.model_bytes);
    CHECK_EQ(arivu_profile_estimated_peak_bytes(&repacked), peak + p.model_bytes);
    CHECK_EQ(arivu_profile_estimated_peak_bytes(nullptr), (uint64_t) 0);
    CHECK_EQ(arivu_profile_mapped_bytes(nullptr), (uint64_t) 0);
    CHECK_EQ(arivu_profile_footprint_bytes(nullptr), (uint64_t) 0);

    check::section("headroom follows the quality of the measurement, not the platform");
    CHECK_EQ(arivu_headroom_permille(ARIVU_MEM_PROBED), (uint32_t) 1400);
    CHECK_EQ(arivu_headroom_permille(ARIVU_MEM_INFERRED), (uint32_t) 1250);
    CHECK_EQ(arivu_headroom_permille(ARIVU_MEM_UNMEASURED), (uint32_t) 0);
    CHECK(arivu_headroom_permille(ARIVU_MEM_PROBED) > arivu_headroom_permille(ARIVU_MEM_INFERRED));

    check::section("profile validation");
    arivu_profile bad = p;
    bad.n_batch = p.n_ctx + 1;
    CHECK(!arivu_profile_valid(&bad, err, sizeof err));
    CHECK(std::strlen(err) > 0);
    bad = p; bad.n_ctx = 64;                     CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.n_threads = 0;                  CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.n_threads = 64;                 CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.reply_reserve_tokens = p.n_ctx; CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.max_reply_tokens = 0;           CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.model_id = "";                  CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.model_bytes = 0;                CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.kv_bytes_per_token = 0;         CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad = p; bad.capabilities = 0;               CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    // Capability follows what the device can carry: longform in a 2048 context is a lie.
    bad = p; bad.capabilities = ARIVU_CAP_CHAT | ARIVU_CAP_LONGFORM;
    CHECK(!arivu_profile_valid(&bad, nullptr, 0));
    bad.n_ctx = 8192;
    CHECK(arivu_profile_valid(&bad, nullptr, 0));
    CHECK(!arivu_profile_valid(nullptr, nullptr, 0));

    check::section("can this device run this profile (spine: C6, C11)");
    CHECK(arivu_profile_fits(&p, nullptr).fit == ARIVU_FIT_INVALID_PROFILE);
    {
        arivu_device dev = good_device();
        const arivu_profile_check r = arivu_profile_fits(&p, &dev);
        CHECK(r.fit == ARIVU_FIT_OK);
        CHECK_EQ(r.estimated_peak_bytes, peak);
    }
    {
        arivu_device dev = good_device();
        dev.arm64 = false;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_NO_ARM64);
    }
    {
        arivu_device dev = good_device();
        dev.low_ram_flagged = true;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_LOW_RAM_DEVICE);
    }
    {
        arivu_device dev = good_device();
        dev.total_ram_bytes = 2ull * 1024 * 1024 * 1024;
        const arivu_profile_check r = arivu_profile_fits(&p, &dev);
        CHECK(r.fit == ARIVU_FIT_TOTAL_RAM);
        CHECK_EQ(r.required_bytes, p.min_total_ram_bytes);
        CHECK_EQ(r.actual_bytes, dev.total_ram_bytes);
    }
    {
        // The iPhone case: 6GB of RAM, but the app is killed on a much lower figure
        // (MULTIPLATFORM.md: ~1.3-2GB on a 4GB iPhone).
        arivu_device dev = good_device();
        dev.total_ram_bytes        = 6ull * 1024 * 1024 * 1024;
        dev.available_memory_bytes = 400ull * 1024 * 1024;
        dev.memory_source          = ARIVU_MEM_PROBED;
        const arivu_profile_check r = arivu_profile_fits(&p, &dev);
        CHECK(r.fit == ARIVU_FIT_AVAILABLE_MEMORY);
        CHECK_EQ(r.estimated_footprint_bytes, footprint);
        CHECK_EQ(r.required_bytes, footprint * 14 / 10);   // probed: 1.4x headroom
        CHECK(r.required_bytes < peak);                    // ...and still less than the raw peak
        // Same phone with the headroom an entitlement buys: the profile fits.
        dev.available_memory_bytes = 2ull * 1024 * 1024 * 1024;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);
    }
    {
        // architecture B23, the regression this guards: a ceiling that charges only dirty pages
        // sits below the raw peak but above the charged footprint. Summing the whole working set
        // would refuse this phone; it runs the profile perfectly well, because the ~379 MB of
        // mmap'd weights are clean, file-backed and evictable.
        arivu_device dev = good_device();
        dev.total_ram_bytes        = 6ull * 1024 * 1024 * 1024;
        dev.available_memory_bytes = 600ull * 1024 * 1024;
        dev.memory_source          = ARIVU_MEM_PROBED;
        CHECK(dev.available_memory_bytes < peak);          // the old arithmetic refused this device
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);
    }
    {
        // An inferred ceiling demands less headroom than a probed one, so a number the platform
        // derived rather than asked for can pass where a probed one of the same size would not.
        arivu_device dev = good_device();
        dev.available_memory_bytes = footprint * 13 / 10;
        dev.memory_source          = ARIVU_MEM_INFERRED;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);
        dev.memory_source = ARIVU_MEM_PROBED;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_AVAILABLE_MEMORY);
    }
    {
        // Calibration: what the profile ACTUALLY cost on this device replaces what was predicted
        // for every device. The estimate exists to be superseded; runtime_overhead_bytes in
        // particular is one provisional number standing in for every phone that will ever run this.

        // (a) Observed HIGHER than predicted: this device is hungrier than the estimate allowed.
        //     Demanding more is the only thing between the user and a kill.
        arivu_device dev = good_device();
        dev.memory_source            = ARIVU_MEM_PROBED;
        dev.observed_footprint_bytes = footprint * 2;
        CHECK_EQ(arivu_profile_required_available_bytes(&p, &dev), footprint * 2 * 14 / 10);
        dev.available_memory_bytes   = footprint * 14 / 10;   // enough for the ESTIMATE
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_AVAILABLE_MEMORY);

        // (b) Observed LOWER than predicted: the estimate was pessimistic here. Refusing a device
        //     this app has already demonstrably run on is the other half of the same mistake.
        dev.observed_footprint_bytes = footprint / 2;
        CHECK_EQ(arivu_profile_required_available_bytes(&p, &dev), (footprint / 2) * 14 / 10);
        dev.available_memory_bytes   = footprint;             // below the ESTIMATE's requirement
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);

        // (c) The headroom multiplier still applies on top. Adapting the magnitude must never
        //     remove the margin, or a device that just fits would have no room to breathe.
        CHECK(arivu_profile_required_available_bytes(&p, &dev) > dev.observed_footprint_bytes);

        // (d) No observation yet: the estimate stands, unchanged.
        dev.observed_footprint_bytes = 0;
        CHECK_EQ(arivu_profile_required_available_bytes(&p, &dev), footprint * 14 / 10);

        // (e) An unmeasured platform has no ceiling, however large the observation. Calibration
        //     refines a ceiling; it never invents one.
        dev.observed_footprint_bytes = footprint * 100;
        dev.memory_source            = ARIVU_MEM_UNMEASURED;
        CHECK_EQ(arivu_profile_required_available_bytes(&p, &dev), (uint64_t) 0);
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);
    }
    {
        // A platform that does not know must say so, and the core then makes no ceiling check at
        // all rather than inventing one from a number it was not given.
        arivu_device dev = good_device();
        dev.available_memory_bytes = 1024;                 // nonsense, but unmeasured
        dev.memory_source          = ARIVU_MEM_UNMEASURED;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_OK);
    }
    {
        arivu_device dev = good_device();
        dev.free_storage_bytes = 1024;
        CHECK(arivu_profile_fits(&p, &dev).fit == ARIVU_FIT_STORAGE);
    }
    {
        // An 8GB Android phone and an 8GB iPhone get the same answer. That is C11.
        arivu_device android = good_device();
        android.total_ram_bytes        = 8ull * 1024 * 1024 * 1024;
        android.available_memory_bytes = 3ull * 1024 * 1024 * 1024;
        android.memory_source          = ARIVU_MEM_PROBED;
        arivu_device iphone = android;
        iphone.low_ram_flagged = false;  // iOS has no such flag; nothing else differs
        CHECK(arivu_profile_fits(&p, &android).fit == arivu_profile_fits(&p, &iphone).fit);
        // Same numbers, same answer — and the answer does not depend on which of them mmaps its
        // weights out of an APK and which out of an app bundle.
        CHECK_EQ(arivu_profile_fits(&p, &android).required_bytes,
                 arivu_profile_fits(&p, &iphone).required_bytes);
    }

    check::section("profile selection picks the richest that fits");
    {
        arivu_profile roomy = p;              // a hypothetical larger tier, richest first
        roomy.id                 = "roomy";
        roomy.n_ctx              = 8192;
        roomy.model_bytes        = 2500ull * 1024 * 1024;
        roomy.capabilities       = ARIVU_CAP_CHAT | ARIVU_CAP_LONGFORM;
        roomy.min_total_ram_bytes = 7ull * 1024 * 1024 * 1024;
        const arivu_profile candidates[2] = {roomy, p};

        arivu_device small = good_device();
        CHECK_EQ(arivu_profile_select(candidates, 2, &small), (int32_t) 1);

        arivu_device big = good_device();
        big.total_ram_bytes    = 8ull * 1024 * 1024 * 1024;
        big.free_storage_bytes = 8ull * 1024 * 1024 * 1024;
        CHECK_EQ(arivu_profile_select(candidates, 2, &big), (int32_t) 0);

        arivu_device tiny = good_device();
        tiny.arm64 = false;
        CHECK_EQ(arivu_profile_select(candidates, 2, &tiny), (int32_t) -1);
        CHECK_EQ(arivu_profile_select(nullptr, 0, &big), (int32_t) -1);
        CHECK_EQ(arivu_profile_select(candidates, 2, nullptr), (int32_t) -1);
    }
}

void test_names() {
    check::section("stop reason and fit names cross the C boundary intact");
    CHECK_EQ((int) ARIVU_STOP_END_OF_TURN, (int) arivu::StopReason::EndOfTurn);
    CHECK_EQ((int) ARIVU_STOP_CANCELLED, (int) arivu::StopReason::Cancelled);
    CHECK_EQ((int) ARIVU_STOP_CONTEXT_FULL, (int) arivu::StopReason::ContextFull);
    CHECK_EQ((int) ARIVU_STOP_MAX_TOKENS, (int) arivu::StopReason::MaxTokens);
    CHECK_EQ((int) ARIVU_STOP_ERROR, (int) arivu::StopReason::Error);
    CHECK_STR(arivu_stop_reason_name(ARIVU_STOP_END_OF_TURN), "end_of_turn");
    CHECK_STR(arivu_stop_reason_name(ARIVU_STOP_CONTEXT_FULL), "context_full");
    CHECK_STR(arivu_stop_reason_name(ARIVU_STOP_CANCELLED), "cancelled");
    CHECK_STR(arivu_stop_reason_name(ARIVU_STOP_MAX_TOKENS), "max_tokens");
    CHECK_STR(arivu_stop_reason_name(ARIVU_STOP_ERROR), "error");
    CHECK_STR(arivu_stop_reason_name((arivu_stop_reason) 99), "unknown");
    CHECK_STR(arivu_fit_name(ARIVU_FIT_OK), "ok");
    CHECK_STR(arivu_fit_name(ARIVU_FIT_AVAILABLE_MEMORY), "available_memory");
    CHECK_STR(arivu_fit_name((arivu_fit) 99), "unknown");
}

}  // namespace

int main() {
    test_utf8();
    test_template();
    test_prompt_budget();
    test_prompt_c_api();
    test_profile();
    test_names();
    return check::finish("core logic");
}
