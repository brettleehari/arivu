# Arivu inference core. Plain C++ over llama.cpp: no JNI, no Android headers, no Apple types.
#
# The rule (MULTIPLATFORM.md): this target builds and its tests pass with no platform SDK
# present. tools/host/run_smoke.sh is the contract. If a change here needs an Android or
# Apple SDK to compile, the abstraction has leaked and the change belongs in /android or /ios.
#
# Two targets, because product logic and inference have different dependencies:
#
#   arivu_core_logic   prompt building, truncation policy, device profiles, UTF-8 boundaries.
#                      Needs nothing but a C++17 compiler — not even llama.cpp. This is what
#                      makes tools/core_test.sh run in seconds.
#   arivu_core         the engine and the C API on top of it. Adds llama.cpp.
#
# Options:
#   ARIVU_CORE_LOGIC_ONLY  build only arivu_core_logic; do not look for llama.cpp at all.
#   ARIVU_CORE_TESTS       add core/tests (CTest). Off by default so the app builds do not
#                          pick up test targets.
cmake_minimum_required(VERSION 3.22)
project(arivu_core CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(ARIVU_CORE_LOGIC_ONLY "Build only the platform- and llama-free half of the core" OFF)
option(ARIVU_CORE_TESTS      "Build core/tests"                                          OFF)

add_library(arivu_core_logic STATIC src/prompt.cpp src/profile.cpp src/text.cpp)
target_include_directories(arivu_core_logic PUBLIC include)

if(NOT ARIVU_CORE_LOGIC_ONLY)
    if(NOT TARGET llama)
        if(NOT DEFINED LLAMA_DIR)
            set(LLAMA_DIR "${CMAKE_CURRENT_LIST_DIR}/../third_party/llama.cpp" CACHE PATH "patched llama.cpp")
        endif()
        if(NOT EXISTS "${LLAMA_DIR}/src/llama-mmap.cpp")
            message(FATAL_ERROR "patched llama.cpp not found at ${LLAMA_DIR}; run tools/llama/fetch_llama.sh")
        endif()
        add_subdirectory("${LLAMA_DIR}" llama.cpp)
    endif()

    add_library(arivu_core STATIC src/engine.cpp src/arivu_c.cpp)
    target_include_directories(arivu_core PUBLIC include)
    target_link_libraries(arivu_core PUBLIC arivu_core_logic llama)
endif()

if(ARIVU_CORE_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
