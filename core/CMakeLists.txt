# Arivu inference core. Plain C++ over llama.cpp: no JNI, no Android headers, no Apple types.
#
# The rule (MULTIPLATFORM.md): this target builds and its tests pass with no platform SDK
# present. tools/host/run_smoke.sh is the contract. If a change here needs an Android or
# Apple SDK to compile, the abstraction has leaked and the change belongs in /android or /ios.
cmake_minimum_required(VERSION 3.22)
project(arivu_core CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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
target_link_libraries(arivu_core PUBLIC llama)
