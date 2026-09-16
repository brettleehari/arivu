// Three macros and a counter. A test framework would be a dependency, and the point of
// core/tests is that the core has none (MULTIPLATFORM.md: /core builds with no platform SDK).
#pragma once

#include <cstdio>
#include <cstring>
#include <string>

namespace check {

inline int & failures() {
    static int n = 0;
    return n;
}

inline void report(bool ok, const char * what, const std::string & detail) {
    if (ok) {
        std::printf("  ok   %s\n", what);
    } else {
        std::printf("  FAIL %s%s%s\n", what, detail.empty() ? "" : " — ", detail.c_str());
        ++failures();
    }
}

template <typename A, typename B>
inline void eq(const A & a, const B & b, const char * what) {
    report(a == b, what, a == b ? "" : "got " + std::to_string(a) + ", want " + std::to_string(b));
}

inline void eq_str(const std::string & a, const std::string & b, const char * what) {
    report(a == b, what, a == b ? "" : "got [" + a + "] want [" + b + "]");
}

inline void section(const char * name) { std::printf("[%s]\n", name); }

inline int finish(const char * suite) {
    if (failures() == 0) {
        std::printf("\n%s: ALL PASSED\n", suite);
        return 0;
    }
    std::printf("\n%s: FAILED (%d)\n", suite, failures());
    return 1;
}

}  // namespace check

#define CHECK(cond) check::report((cond), #cond, "")
#define CHECK_EQ(a, b) check::eq((a), (b), #a " == " #b)
#define CHECK_STR(a, b) check::eq_str((a), (b), #a " == " #b)
