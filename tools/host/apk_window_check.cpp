// spine: C1
// Loads the model directly out of a built APK (fd + entry offset + length), exactly as the app does
// through AssetManager.openFd(), and generates a few tokens. Offsets come from tools/zip_entry_offset.py.
//
//   apk_window_check <apk> <offset> <length>
#include "arivu/engine.h"

#include <cstdio>
#include <cstdlib>
#include <fcntl.h>
#include <string>
#include <unistd.h>

int main(int argc, char ** argv) {
    if (argc < 4) {
        fprintf(stderr, "usage: %s apk offset length\n", argv[0]);
        return 2;
    }
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) { perror("open"); return 2; }
    arivu::Engine e;
    std::string err;
    if (!e.load_model_fd(fd, strtoull(argv[2], nullptr, 10), strtoull(argv[3], nullptr, 10), false, &err)) {
        fprintf(stderr, "FAIL load: %s\n", err.c_str());
        return 1;
    }
    close(fd);
    arivu::ContextConfig cfg;
    cfg.n_ctx = 512;
    if (!e.ensure_context(cfg, &err)) { fprintf(stderr, "FAIL context: %s\n", err.c_str()); return 1; }
    arivu::Sampling greedy;
    greedy.temperature = 0;
    std::string out;
    auto st = e.generate("<|im_start|>user\nShorten: I am writing to let you know that the meeting has been moved.<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n",
                         32, greedy, [&](const char * b, size_t n) { out.append(b, n); });
    printf("output: %s\nstop=%d generated=%d\n", out.c_str(), (int) st.stop, st.generated);
    printf(st.generated > 0 ? "APK WINDOW LOAD OK\n" : "FAIL: nothing generated\n");
    return st.generated > 0 ? 0 : 1;
}
