// Host smoke test for the Arivu engine and the llama.cpp fd-window patch.
// spine: C1, C7, C10
// Not a performance benchmark — performance is only measured on the test phone.
//
//   tools/host/run_smoke.sh
//
// Checks:
//   1. A GGUF embedded at an odd, non-page-aligned offset inside a larger file loads via
//      llama_model_load_from_fd and produces the same greedy output as a plain path load.
//   2. KV prefix reuse on a follow-up prompt.
//   3. Cancel from another thread stops generation.
//   4. A prompt that does not fit the context reports ContextFull instead of truncating silently.
#include "arivu/engine.h"

#include <cstdio>
#include <cstring>
#include <fcntl.h>
#include <string>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>

static int failures = 0;
#define CHECK(cond, msg) do { if (cond) { printf("  ok   %s\n", msg); } else { printf("  FAIL %s\n", msg); ++failures; } } while (0)

static std::string chat(const std::string & user) {
    return "<|im_start|>user\n" + user + "<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n";
}

static std::string run(arivu::Engine & e, const std::string & prompt, int max_new, arivu::GenerationStats * out) {
    std::string text;
    arivu::Sampling greedy;
    greedy.temperature = 0;
    *out = e.generate(prompt, max_new, greedy, [&](const char * b, size_t n) { text.append(b, n); });
    return text;
}

int main(int argc, char ** argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s model.gguf scratch-dir\n", argv[0]);
        return 2;
    }
    const std::string model = argv[1];
    const std::string container = std::string(argv[2]) + "/container.bin";
    // Multiple of 32 (tensor alignment) but not of 4K or 16K, so the mapping has a non-zero delta.
    const size_t prefix_bytes = 12352;

    {
        FILE * out = fopen(container.c_str(), "wb");
        FILE * in  = fopen(model.c_str(), "rb");
        std::string junk(prefix_bytes, 'Z');
        fwrite(junk.data(), 1, junk.size(), out);
        char buf[1 << 16];
        size_t n;
        while ((n = fread(buf, 1, sizeof(buf), in)) > 0) fwrite(buf, 1, n, out);
        fwrite(junk.data(), 1, 777, out);
        fclose(in);
        fclose(out);
    }
    struct stat sb{};
    stat(model.c_str(), &sb);
    const uint64_t model_len = (uint64_t) sb.st_size;

    arivu::ContextConfig cfg;
    cfg.n_ctx = 512;
    cfg.n_threads = 4;
    const std::string p1 = chat("Rewrite more politely: send me the report now.");
    std::string err;

    printf("[1] fd window load vs path load\n");
    std::string ref, via_fd;
    arivu::GenerationStats st{};
    {
        arivu::Engine e;
        CHECK(e.load_model_path(model, false, &err), "path load");
        CHECK(e.ensure_context(cfg, &err), "context (q8_0 KV, flash attn)");
        ref = run(e, p1, 24, &st);
        printf("       path: %s\n", ref.c_str());
        printf("       first token in %.0f ms, decode %.1f tok/s (host, not a phone measurement)\n",
               st.first_token_ms, st.generated * 1000.0 / (st.decode_ms > 0 ? st.decode_ms : 1));
    }
    {
        arivu::Engine e;
        int fd = open(container.c_str(), O_RDONLY);
        CHECK(e.load_model_fd(fd, prefix_bytes, model_len, false, &err), "fd window load at offset 12352 (not page-aligned)");
        close(fd);  // mapping must survive the caller closing its descriptor
        CHECK(e.ensure_context(cfg, &err), "context after fd close");
        via_fd = run(e, p1, 24, &st);
        printf("       fd:   %s\n", via_fd.c_str());
        CHECK(!ref.empty() && ref == via_fd, "identical greedy output");

        {
            arivu::Engine bad;
            int fd2 = open(container.c_str(), O_RDONLY);
            CHECK(!bad.load_model_fd(fd2, prefix_bytes + 4, model_len, false, &err), "offset not multiple of 32 is rejected, not aborted");
            close(fd2);
        }

        printf("[2] prefix reuse\n");
        const std::string p2 = p1 + via_fd + "<|im_end|>\n<|im_start|>user\nNow shorter.<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n";
        run(e, p2, 16, &st);
        printf("       prompt=%d reused=%d\n", st.prompt_tokens, st.reused_tokens);
        CHECK(st.reused_tokens > st.prompt_tokens / 2, "reused more than half the prompt");

        printf("[3] cancel\n");
        std::thread canceller([&] { std::this_thread::sleep_for(std::chrono::milliseconds(150)); e.request_cancel(); });
        run(e, chat("Write a long story about a river."), 400, &st);
        canceller.join();
        CHECK(st.stop == arivu::StopReason::Cancelled, "stop reason Cancelled");
        printf("       generated %d before cancel\n", st.generated);

        printf("[4] context full is reported\n");
        std::string big;
        for (int i = 0; i < 300; ++i) big += "the river runs to the sea ";
        run(e, chat(big), 8, &st);
        CHECK(st.stop == arivu::StopReason::ContextFull, "stop reason ContextFull for oversize prompt");
    }

    printf("[5] utf8 boundary buffering\n");
    const char euro[] = "a\xE2\x82\xAC";  // "a€"
    CHECK(arivu::utf8_complete_prefix(euro, 2) == 1, "holds partial 3-byte sequence");
    CHECK(arivu::utf8_complete_prefix(euro, 4) == 4, "releases complete sequence");

    unlink(container.c_str());
    printf(failures ? "\nFAILED (%d)\n" : "\nALL PASSED\n", failures);
    return failures ? 1 : 0;
}
