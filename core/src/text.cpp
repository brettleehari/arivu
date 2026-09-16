// UTF-8 boundary buffering. Lives apart from engine.cpp because it needs no llama.cpp and no
// platform SDK: core/tests exercises it in a build that links neither (spine: C11).
//
// A token boundary is not a character boundary. Handing a partial multi-byte sequence to the UI
// would render a replacement glyph that then has to be un-rendered, so the engine holds the tail
// until it completes.
#include "arivu/engine.h"

#include "arivu/arivu.h"

namespace arivu {

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

}  // namespace arivu

extern "C" size_t arivu_utf8_complete_prefix(const char * bytes, size_t len) {
    if (bytes == nullptr || len == 0) return 0;
    return arivu::utf8_complete_prefix(bytes, len);
}
