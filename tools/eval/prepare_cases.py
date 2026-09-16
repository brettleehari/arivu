#!/usr/bin/env python3
"""Turn tools/eval/cases.yml into the flat record file tools/eval/eval.cpp reads.

Two jobs, both of which exist to keep the eval honest rather than convenient:

1. **The system prompt is not written down here.** It is extracted from
   android/.../Policy.kt — the same source ProfileParityTest already treats as the authority, and
   the same technique it uses to compare the Swift copy. An eval that carries its own copy of the
   system prompt measures a prompt nobody ships. Every token of it is context the user's text
   cannot use, so it also has to be the real length.

2. **The dataset stays YAML for humans and becomes trivial for C++.** eval.cpp gets a
   length-prefixed format it can read with fgets and fread, so no JSON or YAML parser enters the
   C++ side and no case text can break the framing, whatever quoting or newlines it contains.

Output format, all UTF-8:

    SYSTEM <byte_len>\\n<raw bytes>
    CASE <id> <slice> <lang> <max_new> <n_turns> <draft:0|1>\\n
    TURN <user|assistant> <byte_len>\\n<raw bytes>
    ...

Usage: prepare_cases.py [cases.yml] [out_file]
"""
import pathlib
import re
import sys

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is needed: python3 -m pip install --user pyyaml")

ROOT = pathlib.Path(__file__).resolve().parents[2]
POLICY_KT = ROOT / "android/app/src/main/java/io/github/brettleehari/arivu/app/Policy.kt"


def system_prompt() -> str:
    """The shipped system prompt, read out of Policy.kt rather than copied.

    Takes the concatenated string literals of `const val SYSTEM_PROMPT = "..." + "..."`, skipping
    comment lines, which is exactly what ProfileParityTest does to the Swift side. If Policy.kt is
    ever reformatted so this stops matching, the eval fails loudly instead of running against a
    stale prompt.
    """
    text = POLICY_KT.read_text(encoding="utf-8").split("\n")
    try:
        start = next(i for i, l in enumerate(text) if "SYSTEM_PROMPT" in l)
    except StopIteration:
        sys.exit(f"{POLICY_KT} has no SYSTEM_PROMPT")

    body = []
    for line in text[start:]:
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        body.append(line)
        # The literal ends on the first line that does not continue it. Kotlin continues a
        # concatenation with a trailing `+`, so a line without one is the last.
        if body[1:] and not stripped.endswith("+"):
            break

    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', "\n".join(body))
    if not parts:
        sys.exit(f"could not read SYSTEM_PROMPT out of {POLICY_KT}")
    prompt = "".join(parts)
    # Kotlin escapes that survive the regex above.
    prompt = prompt.replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
    if "You are Arivu" not in prompt or not prompt.rstrip().endswith("help."):
        sys.exit(f"extracted system prompt does not look right: {prompt[:80]!r} ... {prompt[-40:]!r}")
    return prompt


def expand(text: str, sources: dict) -> str:
    """Substitute {{source_name}} with the shared input, so one passage has one copy."""
    def sub(match):
        name = match.group(1).strip()
        if name not in sources:
            sys.exit(f"unknown source {{{{{name}}}}}")
        return sources[name].rstrip("\n")
    return re.sub(r"\{\{([^}]+)\}\}", sub, text)


def main() -> None:
    cases_path = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).with_name("cases.yml")
    out_path = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else pathlib.Path("cases.bin")

    doc = yaml.safe_load(cases_path.read_text(encoding="utf-8"))
    sources = doc.get("sources", {}) or {}
    cases = doc.get("cases", []) or []
    if not cases:
        sys.exit(f"{cases_path} has no cases")

    out = bytearray()

    def record(header: str, payload: str) -> None:
        raw = payload.encode("utf-8")
        out.extend(f"{header} {len(raw)}\n".encode("utf-8"))
        out.extend(raw)

    record("SYSTEM", system_prompt())

    seen = set()
    for case in cases:
        cid = case["id"]
        if cid in seen:
            sys.exit(f"duplicate case id {cid}")
        seen.add(cid)
        turns = case.get("turns") or []
        if not turns:
            sys.exit(f"{cid}: no turns")
        last = turns[-1]
        if "user" not in last:
            sys.exit(f"{cid}: the last turn must be the user's — the prompt builder requires it")
        draft = 1 if case.get("draft") else 0
        out.extend(
            f"CASE {cid} {case.get('slice','?')} {case.get('lang','en')} "
            f"{int(case.get('max_new', 192))} {len(turns)} {draft}\n".encode("utf-8")
        )
        for turn in turns:
            role = "user" if "user" in turn else "assistant"
            record(f"TURN {role}", expand(turn[role], sources))

    out_path.write_bytes(bytes(out))
    seeds = doc.get("seeds", [1])
    print(f"{len(cases)} cases, {len(seeds)} seeds -> {out_path} ({len(out)} bytes)")
    print("seeds: " + ",".join(str(s) for s in seeds))


if __name__ == "__main__":
    main()
