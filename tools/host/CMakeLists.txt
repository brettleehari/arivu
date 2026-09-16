cmake_minimum_required(VERSION 3.22)
project(arivu_host_smoke CXX C)
set(CMAKE_CXX_STANDARD 17)

enable_testing()   # core/tests registers core_logic and core_engine here; tools/core_test.sh runs them

set(LLAMA_DIR "${CMAKE_CURRENT_LIST_DIR}/../../third_party/llama.cpp" CACHE PATH "patched llama.cpp")
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory("${LLAMA_DIR}" llama.cpp)

set(ARIVU_CORE_TESTS ON CACHE BOOL "" FORCE)   # llama.cpp is already built here, so the engine suite is free
add_subdirectory("${CMAKE_CURRENT_LIST_DIR}/../../core" arivu_core)

add_executable(engine_smoke engine_smoke.cpp)
target_link_libraries(engine_smoke PRIVATE arivu_core)

add_executable(apk_window_check apk_window_check.cpp)
target_link_libraries(apk_window_check PRIVATE arivu_core)
