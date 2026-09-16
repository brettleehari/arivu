// W04 — the writing and comprehension eval runner.
//
// Generates, and nothing else. Every judgement lives in tools/eval/grade.py, because the useful
// checks are string work that is miserable in C++ and because a generation run is expensive enough
// that re-grading must not mean re-generating. This binary's whole job is to produce, for each case
// and each seed, exactly what the shipped app would have produced.
//
// "Exactly what the app would have produced" is the point, so:
//   - the system prompt comes from Policy.kt, extracted by prepare_cases.py. No copy lives here.
//   - the prompt is built by the CORE's own builder (arivu_prompt_builder_*), not by a local
//     reimplementation. That makes W04 the first real consumer of that API and means the eval
//     exercises the same ChatML template and the same oldest-first truncation the product uses.
//   - sampling is arivu_default_sampling_params() with only the seed changed (D-007).
//   - the context is the shipped profile's (arivu_default_profile), so the reply reserve and
//     n_ctx are the ones a phone has.
//
// What this run is NOT: a speed measurement. Same GGUF and same engine.cpp make the *quality*
// answer valid on a host; tok/s here is a desktop number and must never be quoted as product
// performance (leaves/BRIEF.md "Test device"). Timings are emitted only so a hung case is visible.
//
// Usage: eval <model.gguf> <cases.bin> <seed[,seed...]> [out.jsonl]
//
// spine: C5, C7 — decides D-017.
#include "arivu/arivu.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

namespace {

struct Turn {
    std::string text;
    bool from_user;
};

struct Case {
    std::string id, slice, lang;
    int max_new = 192;
    bool draft = false;
    std::vector<Turn> turns;
};

// ---- the record file written by prepare_cases.py ------------------------------------------------
//
// Length-prefixed, so no case text can break the framing however it is quoted or wrapped.

bool read_header(std::FILE * f, std::string & line) {
    line.clear();
    int c;
    while ((c = std::fgetc(f)) != EOF) {
        if (c == '\n') return true;
        line.push_back((char) c);
    }
    return !line.empty();
}

bool read_payload(std::FILE * f, size_t len, std::string & out) {
    out.assign(len, '\0');
    return len == 0 || std::fread(&out[0], 1, len, f) == len;
}

bool load_cases(const char * path, std::string & system_prompt, std::vector<Case> & cases) {
    std::FILE * f = std::fopen(path, "rb");
    if (!f) {
        std::fprintf(stderr, "cannot open %s\n", path);
        return false;
    }
    std::string line;
    bool ok = true;
    while (ok && read_header(f, line)) {
        if (line.rfind("SYSTEM ", 0) == 0) {
            ok = read_payload(f, (size_t) std::strtoul(line.c_str() + 7, nullptr, 10), system_prompt);
        } else if (line.rfind("CASE ", 0) == 0) {
            Case c;
            char id[256] = {0}, slice[64] = {0}, lang[16] = {0};
            int max_new = 192, n_turns = 0, draft = 0;
            if (std::sscanf(line.c_str() + 5, "%255s %63s %15s %d %d %d",
                            id, slice, lang, &max_new, &n_turns, &draft) != 6) {
                std::fprintf(stderr, "bad CASE line: %s\n", line.c_str());
                ok = false;
                break;
            }
            c.id = id; c.slice = slice; c.lang = lang; c.max_new = max_new; c.draft = draft != 0;
            for (int i = 0; i < n_turns && ok; ++i) {
                if (!read_header(f, line) || line.rfind("TURN ", 0) != 0) { ok = false; break; }
                const bool from_user = line.compare(5, 4, "user") == 0;
                const char * space = std::strrchr(line.c_str(), ' ');
                Turn t;
                t.from_user = from_user;
                ok = space && read_payload(f, (size_t) std::strtoul(space + 1, nullptr, 10), t.text);
                c.turns.push_back(std::move(t));
            }
            cases.push_back(std::move(c));
        }
    }
    std::fclose(f);
    if (!ok) std::fprintf(stderr, "malformed record file %s\n", path);
    return ok;
}

// ---- output -------------------------------------------------------------------------------------

void json_escape(const std::string & in, std::string & out) {
    for (unsigned char c : in) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:
                if (c < 0x20) { char b[8]; std::snprintf(b, sizeof(b), "\\u%04x", c); out += b; }
                else out += (char) c;   // UTF-8 passes through; the grader reads UTF-8.
        }
    }
}

void collect(const char * bytes, size_t len, void * user_data) {
    static_cast<std::string *>(user_data)->append(bytes, len);
}

}  // namespace

int main(int argc, char ** argv) {
    if (argc < 4) {
        std::fprintf(stderr, "usage: %s <model.gguf> <cases.bin> <seed[,seed...]> [out.jsonl]\n", argv[0]);
        return 2;
    }
    const char * model_path = argv[1];
    const char * cases_path = argv[2];

    std::vector<uint32_t> seeds;
    for (const char * p = argv[3]; *p;) {
        seeds.push_back((uint32_t) std::strtoul(p, nullptr, 10));
        const char * comma = std::strchr(p, ',');
        if (!comma) break;
        p = comma + 1;
    }
    if (seeds.empty()) seeds.push_back(1);

    std::string system_prompt;
    std::vector<Case> cases;
    if (!load_cases(cases_path, system_prompt, cases)) return 1;
    if (system_prompt.empty()) {
        std::fprintf(stderr, "no SYSTEM record — prepare_cases.py must extract it from Policy.kt\n");
        return 1;
    }

    std::FILE * out = (argc > 4) ? std::fopen(argv[4], "wb") : stdout;
    if (!out) { std::fprintf(stderr, "cannot write %s\n", argv[4]); return 1; }

    arivu_engine * engine = arivu_engine_create();
    if (!engine) { std::fprintf(stderr, "arivu_engine_create failed\n"); return 1; }

    char err[512] = {0};
    const arivu_profile profile = arivu_default_profile();
    if (!arivu_load_model_path(engine, model_path, profile.repack, err, sizeof(err))) {
        std::fprintf(stderr, "load failed: %s\n", err);
        arivu_engine_free(engine);
        return 1;
    }
    if (!arivu_ensure_context(engine, arivu_profile_context_params(&profile), err, sizeof(err))) {
        std::fprintf(stderr, "context failed: %s\n", err);
        arivu_engine_free(engine);
        return 1;
    }

    std::fprintf(stderr, "eval: %zu cases x %zu seeds, core %s, n_ctx %d\n",
                 cases.size(), seeds.size(), arivu_version(), arivu_n_ctx(engine));

    std::vector<char> prompt_buf(1 << 16);
    int written = 0;

    for (const Case & c : cases) {
        // A builder per case: its token cache is keyed by turn id, and cases share no turns.
        arivu_prompt_builder * builder = arivu_prompt_builder_create_for_engine(
            system_prompt.c_str(), profile.n_ctx, profile.reply_reserve_tokens, engine);
        if (!builder) { std::fprintf(stderr, "%s: builder failed\n", c.id.c_str()); continue; }

        std::vector<arivu_turn> turns;
        std::vector<std::string> ids;
        ids.reserve(c.turns.size());
        for (size_t i = 0; i < c.turns.size(); ++i) ids.push_back(c.id + "/" + std::to_string(i));
        for (size_t i = 0; i < c.turns.size(); ++i) {
            arivu_turn t;
            t.id = ids[i].c_str();
            t.text = c.turns[i].text.data();
            t.text_len = c.turns[i].text.size();
            t.from_user = c.turns[i].from_user;
            turns.push_back(t);
        }

        size_t prompt_len = 0;
        arivu_prompt_result pr = arivu_prompt_builder_build(
            builder, turns.data(), turns.size(), prompt_buf.data(), prompt_buf.size(), &prompt_len);
        if (pr.output_truncated && pr.status == ARIVU_PROMPT_OK) {
            prompt_buf.resize(pr.text_len + 1);
            pr = arivu_prompt_builder_build(builder, turns.data(), turns.size(),
                                            prompt_buf.data(), prompt_buf.size(), &prompt_len);
        }

        for (uint32_t seed : seeds) {
            std::string reply, row;
            arivu_stats st;
            std::memset(&st, 0, sizeof(st));
            const char * prompt_status = "ok";

            if (pr.status == ARIVU_PROMPT_OK) {
                arivu_sampling_params sampling = arivu_default_sampling_params();
                sampling.seed = seed;   // the only value that changes per row (D-007)
                err[0] = '\0';
                st = arivu_generate(engine, prompt_buf.data(), prompt_len, c.max_new, sampling,
                                    &collect, &reply, err, sizeof(err));
            } else {
                // TOO_LONG or INVALID is a result, not a crash: the app would show the user a
                // notice here (C7), and a case that cannot even be built is a finding.
                prompt_status = pr.status == ARIVU_PROMPT_TOO_LONG ? "too_long" : "invalid";
            }

            // The user's own last message, so the grader can measure echo without re-reading the
            // dataset and without guessing which turn was the input.
            const std::string & input = c.turns.back().text;

            row = "{";
            row += "\"case\":\"";   json_escape(c.id, row);    row += "\",";
            row += "\"slice\":\"";  json_escape(c.slice, row); row += "\",";
            row += "\"lang\":\"";   json_escape(c.lang, row);  row += "\",";
            row += "\"draft\":";    row += c.draft ? "true," : "false,";
            row += "\"seed\":";     row += std::to_string(seed); row += ",";
            row += "\"prompt_status\":\""; row += prompt_status; row += "\",";
            row += "\"prompt_tokens\":";  row += std::to_string(pr.prompt_tokens); row += ",";
            row += "\"first_included\":"; row += std::to_string(pr.first_included); row += ",";
            row += "\"max_new\":";  row += std::to_string(c.max_new); row += ",";
            row += "\"stop\":\"";   row += arivu_stop_reason_name(st.stop); row += "\",";
            row += "\"generated\":"; row += std::to_string(st.generated); row += ",";
            row += "\"error\":\"";  json_escape(err, row);     row += "\",";
            row += "\"input\":\"";  json_escape(input, row);   row += "\",";
            row += "\"reply\":\"";  json_escape(reply, row);   row += "\"}";
            std::fprintf(out, "%s\n", row.c_str());
            std::fflush(out);
            ++written;

            std::fprintf(stderr, "  %-32s seed %-4u %-12s %4d tok\n",
                         c.id.c_str(), seed, arivu_stop_reason_name(st.stop), st.generated);
        }
        arivu_prompt_builder_free(builder);
    }

    if (out != stdout) std::fclose(out);
    arivu_engine_free(engine);
    std::fprintf(stderr, "eval: %d rows\n", written);
    return 0;
}
