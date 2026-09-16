cmake_minimum_required(VERSION 3.22)
project(arivu_llama C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED LLAMA_DIR)
    message(FATAL_ERROR "LLAMA_DIR not set; run tools/llama/fetch_llama.sh")
endif()
if(NOT EXISTS "${LLAMA_DIR}/src/llama-mmap.cpp")
    message(FATAL_ERROR "patched llama.cpp not found at ${LLAMA_DIR}; run tools/llama/fetch_llama.sh")
endif()

# Portable arm64 build; the best CPU kernel variant (dotprod, i8mm, sve…) is chosen at runtime,
# so a Helio G85 (armv8.2 dotprod) and an SD680 (armv8.0) each get their fastest path.
set(BUILD_SHARED_LIBS     ON  CACHE BOOL "" FORCE)
set(GGML_NATIVE           OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL       ON  CACHE BOOL "" FORCE)
set(GGML_CPU_ALL_VARIANTS ON  CACHE BOOL "" FORCE)
set(GGML_OPENMP           OFF CACHE BOOL "" FORCE)  # busy-wait threads run a budget SoC hot
set(GGML_LLAMAFILE        OFF CACHE BOOL "" FORCE)
set(GGML_CPU_KLEIDIAI     OFF CACHE BOOL "" FORCE)  # decisions.yml D-015: repack only, needs a build-time download
set(LLAMA_BUILD_COMMON    OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS     OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS     OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES  OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER    OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP       OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL         OFF CACHE BOOL "" FORCE)
add_subdirectory("${LLAMA_DIR}" llama.cpp)

add_library(arivu_llama SHARED engine.cpp jni_bridge.cpp)
target_link_libraries(arivu_llama PRIVATE llama ggml android log)
# 16KB page-size devices (BRIEF.md: NDK r27+, mandatory)
target_link_options(arivu_llama PRIVATE "-Wl,-z,max-page-size=16384")
