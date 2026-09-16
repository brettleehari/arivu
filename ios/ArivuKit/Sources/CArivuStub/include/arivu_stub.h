// A fake Arivu core, for tests only.
//
// It implements every symbol in core/include/arivu/arivu.h with no llama.cpp and no model, so the
// Swift wrapper, the lifecycle rules and the chat state machine can be exercised on a machine that
// has neither. It is NOT in any product: linking it beside the real core would duplicate every
// symbol, and SwiftPM will not let an app reach it.
//
// What it is not: a substitute for the real engine. Anything that depends on llama.cpp's actual
// behaviour — tokenisation, sampling, prefix reuse, memory — is verified by tools/host/run_smoke.sh
// on the C++ side and on a device, never here. `arivu_version()` returns a string beginning "stub",
// and the parity tests skip themselves when they see it.
#ifndef ARIVU_STUB_H
#define ARIVU_STUB_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// The text the fake engine will "generate", as space-separated pieces. Default: a short sentence.
void arivu_stub_set_script(const char * utf8);

// Microseconds to sleep between pieces, so a test can cancel mid-stream. Default 0.
void arivu_stub_set_piece_delay_us(int micros);

// Make the next model load fail with this message (NULL clears). Used for load_failed and
// load_failed_low_memory, which are different screens (leaves/design.md §7).
void arivu_stub_fail_next_load(const char * message);

// Make the next context creation fail with this message (NULL clears).
void arivu_stub_fail_next_context(const char * message);

// Report a context-full stop on the next generate().
void arivu_stub_next_stop_context_full(void);

// How many engines have been created and not freed. A leaked handle makes this non-zero.
int arivu_stub_live_engines(void);

// Reset every stub knob and counter.
void arivu_stub_reset(void);

#ifdef __cplusplus
}
#endif
#endif  // ARIVU_STUB_H
