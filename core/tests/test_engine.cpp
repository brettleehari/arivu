// C API error handling with no model, a NULL handle and an invalid model file.
//
// The engine half of the core tests: it links llama.cpp but never loads a model, so it needs no
// 400MB download and still runs in a second. The model-backed checks are tools/host/run_smoke.sh.
//
// This is the surface the iOS Leaf and the Android JNI bridge both bind to; every one of these
// cases is something a platform will hit on a device where the model asset is missing or the
// install is damaged, and none of them may be undefined behaviour (spine: C6, C11).
#include "check.h"

#include "arivu/arivu.h"

#include <cstdio>
#include <string>
#include <vector>

namespace {

void test_null_handle() {
    check::section("every entry point tolerates a NULL handle");
    char err[256] = {0};
    CHECK(!arivu_load_model_path(nullptr, "/does/not/matter", false, err, sizeof err));
    CHECK(std::strlen(err) > 0);
    CHECK(!arivu_load_model_fd(nullptr, -1, 0, 0, false, nullptr, 0));
    CHECK(!arivu_has_model(nullptr));
    CHECK(!arivu_has_context(nullptr));
    CHECK_EQ(arivu_n_ctx(nullptr), (int32_t) 0);
    CHECK_EQ(arivu_count_tokens(nullptr, "hi", 2), (int32_t) -1);
    CHECK_EQ(arivu_compute_buffer_kib(nullptr), (int64_t) -1);
    CHECK(!arivu_ensure_context(nullptr, arivu_default_context_params(), err, sizeof err));
    const arivu_stats st = arivu_generate(nullptr, "hi", 2, 8, arivu_default_sampling_params(),
                                          nullptr, nullptr, err, sizeof err);
    CHECK(st.stop == ARIVU_STOP_ERROR);
    CHECK_EQ(st.generated, 0);
    // Frees and cancel on a NULL handle are no-ops, not crashes.
    arivu_free_model(nullptr);
    arivu_free_context(nullptr);
    arivu_cancel(nullptr);
    arivu_engine_free(nullptr);
    CHECK(arivu_prompt_builder_create_for_engine("sys", 2048, 512, nullptr) == nullptr);
    check::report(true, "no crash", "");
}

void test_no_model(const std::string & scratch) {
    check::section("an engine with no model fails cleanly and says why");
    arivu_engine * e = arivu_engine_create();
    CHECK(e != nullptr);
    CHECK(!arivu_has_model(e));
    CHECK(!arivu_has_context(e));
    CHECK_EQ(arivu_compute_buffer_kib(e), (int64_t) -1);
    CHECK_EQ(arivu_count_tokens(e, "hello", 5), (int32_t) -1);

    char err[256] = {0};
    CHECK(!arivu_ensure_context(e, arivu_default_context_params(), err, sizeof err));
    CHECK_STR(err, "no model loaded");

    err[0] = '\0';
    const arivu_stats st = arivu_generate(e, "hello", 5, 8, arivu_default_sampling_params(),
                                          nullptr, nullptr, err, sizeof err);
    CHECK(st.stop == ARIVU_STOP_ERROR);
    CHECK_STR(err, "no context");
    CHECK_STR(arivu_stop_reason_name(st.stop), "error");

    check::section("a missing or invalid model file is an error, not an abort");
    err[0] = '\0';
    CHECK(!arivu_load_model_path(e, "/nonexistent/arivu-not-a-model.gguf", false, err, sizeof err));
    CHECK(std::strlen(err) > 0);
    CHECK(!arivu_has_model(e));
    std::printf("       missing file: %s\n", err);

    const std::string junk_path = scratch + "/not-a-model.gguf";
    {
        FILE * f = std::fopen(junk_path.c_str(), "wb");
        CHECK(f != nullptr);
        if (f != nullptr) {
            const std::string junk(4096, 'Z');
            std::fwrite(junk.data(), 1, junk.size(), f);
            std::fclose(f);
        }
    }
    err[0] = '\0';
    CHECK(!arivu_load_model_path(e, junk_path.c_str(), false, err, sizeof err));
    CHECK(std::strlen(err) > 0);
    CHECK(!arivu_has_model(e));
    std::printf("       wrong magic:  %s\n", err);
    std::remove(junk_path.c_str());

    // A truncated err_buf must still be NUL-terminated, and a NULL one must be accepted.
    char tiny[4] = {'x', 'x', 'x', 'x'};
    CHECK(!arivu_load_model_path(e, "/nonexistent/arivu-not-a-model.gguf", false, tiny, sizeof tiny));
    CHECK_EQ(std::strlen(tiny), (size_t) 3);
    CHECK(!arivu_load_model_path(e, "/nonexistent/arivu-not-a-model.gguf", false, nullptr, 0));

    check::section("the prompt builder on a model-less engine reports Invalid, not a guess");
    arivu_prompt_builder * b = arivu_prompt_builder_create_for_engine("sys", 2048, 512, e);
    CHECK(b != nullptr);
    arivu_turn t;
    t.id = "t0";
    t.text = "hello";
    t.text_len = 5;
    t.from_user = true;
    CHECK(arivu_prompt_builder_build(b, &t, 1, nullptr, 0, nullptr).status == ARIVU_PROMPT_INVALID);
    arivu_prompt_builder_free(b);

    arivu_engine_free(e);
    check::report(true, "engine freed without a model", "");
}

void test_process_facts() {
    check::section("process facts the benchmark depends on");
    int64_t rss = 0, peak = 0;
    arivu_memory_kb(&rss, &peak);
    CHECK(rss > 0);                 // both Linux and Apple report a resident size
    std::printf("       rss %lld kB, peak %lld kB\n", (long long) rss, (long long) peak);
    arivu_memory_kb(nullptr, nullptr);  // must not crash
    CHECK(arivu_version() != nullptr && std::strlen(arivu_version()) > 0);
}

}  // namespace

int main(int argc, char ** argv) {
    const std::string scratch = argc > 1 ? argv[1] : ".";
    test_null_handle();
    test_no_model(scratch);
    test_process_facts();
    return check::finish("core engine");
}
