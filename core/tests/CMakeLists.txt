# Core tests. No external framework: check.h is three macros, and /core's whole claim is that it
# builds with nothing installed (MULTIPLATFORM.md).
#
#   core_logic_test   links arivu_core_logic only — no llama.cpp, no model, no SDK. Seconds.
#   core_engine_test  links the engine, but never loads a model, so it needs no 400MB download.
#                     Built only when llama.cpp is present (ARIVU_CORE_LOGIC_ONLY=OFF).
#
# Driven by tools/core_test.sh.
add_executable(core_logic_test test_logic.cpp)
target_link_libraries(core_logic_test PRIVATE arivu_core_logic)
target_include_directories(core_logic_test PRIVATE "${CMAKE_CURRENT_LIST_DIR}")
add_test(NAME core_logic COMMAND core_logic_test)

if(TARGET arivu_core)
    add_executable(core_engine_test test_engine.cpp)
    target_link_libraries(core_engine_test PRIVATE arivu_core)
    target_include_directories(core_engine_test PRIVATE "${CMAKE_CURRENT_LIST_DIR}")
    add_test(NAME core_engine COMMAND core_engine_test "${CMAKE_CURRENT_BINARY_DIR}")
endif()
