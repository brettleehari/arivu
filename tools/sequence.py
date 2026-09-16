#!/usr/bin/env python3
"""Sequencing Leaf renderer.

Reads leaves/sequencing/workitems.yml (and leaves/decisions.yml, SPINE.md for cross-checks) and writes
leaves/sequencing/SEQUENCING.md with:
  - validation: unknown deps / decisions / spine IDs, cycles, done items without a `verified` level
  - Ready-Now queue grouped by owner, Hari first
  - deadlines (overdue / at risk against --today) and decision SLAs from decisions.yml
  - per milestone: unconstrained critical path, and a bandwidth-aware calendar estimate
  - a schedule simulation with N builders (Engineering-capable agents), Hari, and one test phone
  - Mermaid graph with the production critical path highlighted

usage: tools/sequence.py [--slice BENCH|MVP|PLAY] [--builders N] [--today YYYY-MM-DD] [--phones N]
                         [--leaf-parallel] [--agents-weekdays] [--check]

Model (stated in the output too):
  estimate_days = working days of effort; consumes the owner's pool (Hari: 1 slot, weekdays only;
  everyone else: the builder pool of N agents, every day unless --agents-weekdays) plus any `uses`
  resource (phone). elapsed_days = calendar days after the effort that consume nobody. Work is not
  pre-empted. Scheduling is greedy: milestone-path items first, then longest downstream chain.
"""
import argparse, datetime as dt, math, pathlib, re, sys
from collections import defaultdict
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "leaves/sequencing/workitems.yml"
OUT = ROOT / "leaves/sequencing/SEQUENCING.md"
DECISIONS = ROOT / "leaves/decisions.yml"
SPINE = ROOT / "SPINE.md"
STEP = 0.25

ap = argparse.ArgumentParser()
ap.add_argument("--slice")
ap.add_argument("--builders", type=int, default=1, help="Engineering-capable agents (default 1)")
ap.add_argument("--phones", type=int, default=1)
ap.add_argument("--today", default=dt.date.today().isoformat())
ap.add_argument("--leaf-parallel", action="store_true", help="non-Engineering Leaves get their own agent slot")
ap.add_argument("--agents-weekdays", action="store_true", help="agents work weekdays only, like Hari")
ap.add_argument("--check", action="store_true", help="validate only, write nothing")
args = ap.parse_args()
TODAY = dt.date.fromisoformat(args.today)

doc = yaml.safe_load(SRC.read_text())
raw = doc["items"]
items = {}
errors, warnings = [], []
for i in raw:
    if i["id"] in items:
        errors.append(f"duplicate id {i['id']}")
    items[i["id"]] = i
milestones = doc.get("milestones", {})

# ---------------------------------------------------------------- validation
decisions = {e["id"]: e for e in (yaml.safe_load(DECISIONS.read_text()) or [])} if DECISIONS.exists() else {}
spine_ids = set(re.findall(r"\b([CMR]\d+)\b", SPINE.read_text())) if SPINE.exists() else set()
STATUSES = {"done", "in_progress", "todo", "blocked"}
REQUIRED = ("id", "title", "slice", "spine", "owner", "status", "estimate_days", "deps")

def as_date(v):
    if v is None or isinstance(v, dt.date):
        return v
    return dt.date.fromisoformat(str(v))

for k, i in items.items():
    for f in REQUIRED:
        if f not in i:
            errors.append(f"{k}: missing field `{f}`")
    i.setdefault("deps", []); i.setdefault("soft_deps", []); i.setdefault("uses", [])
    i.setdefault("decisions", []); i.setdefault("elapsed_days", 0); i.setdefault("skip_if", [])
    if i.get("status") not in STATUSES:
        errors.append(f"{k}: unknown status {i.get('status')}")
    if i.get("slice") not in doc.get("slices", {}):
        errors.append(f"{k}: unknown slice {i.get('slice')}")
    for d in i["deps"] + i["soft_deps"]:
        if d not in items:
            errors.append(f"{k} depends on unknown {d}")
    for d in i["decisions"]:
        if decisions and d not in decisions:
            errors.append(f"{k} references unknown decision {d}")
    for s in i.get("spine", []):
        if spine_ids and s not in spine_ids:
            errors.append(f"{k} references unknown spine ID {s}")
    for u in i["uses"]:
        if u not in ("phone", "Engineering", "Hari"):
            errors.append(f"{k}: unknown resource {u}")
    if i.get("status") == "done" and not i.get("verified"):
        errors.append(f"{k}: done without a `verified` level")
    try:
        i["deadline"] = as_date(i.get("deadline"))
    except ValueError:
        errors.append(f"{k}: deadline must be an ISO date (use deadline_note for relative deadlines)")
for name, mid in milestones.items():
    if mid not in items:
        errors.append(f"milestone {name} → unknown item {mid}")

# cycles over hard + soft edges
state = {}
def visit(k, stack):
    state[k] = 1
    for d in items[k]["deps"] + items[k]["soft_deps"]:
        if d not in items:
            continue
        if state.get(d) == 1:
            errors.append("cycle: " + " → ".join(stack[stack.index(d):] + [k, d]) if d in stack else f"cycle via {k} → {d}")
        elif not state.get(d):
            visit(d, stack + [k])
    state[k] = 2
for k in items:
    if not state.get(k):
        visit(k, [])

if not errors:
    for k, i in items.items():
        if i["status"] == "done":
            open_deps = [d for d in i["deps"] if items[d]["status"] != "done"]
            if open_deps:
                warnings.append(f"{k} is done but depends on open {', '.join(open_deps)}")
    referenced = {d for i in items.values() for d in i["decisions"]}
    for did, e in decisions.items():
        for fld in ("depends_on", "blocks"):
            for ref in e.get(fld) or []:
                if re.fullmatch(r"W\d+", str(ref)) and ref not in items:
                    warnings.append(f"decisions.yml {did}.{fld} names unknown work item {ref}")
        if e.get("blocks_release") and did not in referenced:
            warnings.append(f"blocking decision {did} is not referenced by any work item")
        if set(map(str, e.get("depends_on") or [])) & set(map(str, e.get("blocks") or [])):
            warnings.append(f"decisions.yml {did} both depends_on and blocks "
                            f"{sorted(set(map(str, e['depends_on'])) & set(map(str, e['blocks'])))} (split into provisional/final)")

if errors:
    print("SEQUENCING ERRORS:\n  " + "\n  ".join(errors))
    sys.exit(1)
if args.check:
    print("OK" + ("".join("\n  warning: " + w for w in warnings)))
    sys.exit(0)

# ---------------------------------------------------------------- graph helpers
def is_open(k):
    return items[k]["status"] != "done"

def ancestors(k):
    seen, todo = set(), [k]
    while todo:
        x = todo.pop()
        if x in seen:
            continue
        seen.add(x)
        todo += items[x]["deps"]
    return seen

children = defaultdict(list)
for k, i in items.items():
    for d in i["deps"]:
        children[d].append(k)

def dur(k, skip=()):
    i = items[k]
    if not is_open(k) or set(i["skip_if"]) & set(skip):
        return 0.0
    return float(i["estimate_days"]) + float(i["elapsed_days"])

def critical_path(target, skip=()):
    memo = {}
    def longest(k):
        if k not in memo:
            prev = [longest(d) for d in items[k]["deps"]]
            best = max(prev, default=(0.0, []), key=lambda p: p[0])
            memo[k] = (dur(k, skip) + best[0], best[1] + [k])
        return memo[k]
    days, path = longest(target)
    return days, [p for p in path if dur(p, skip) > 0 or p == target]

mil_anc = {name: ancestors(mid) for name, mid in milestones.items()}

def tail_len():
    memo = {}
    def t(k):
        if k not in memo:
            memo[k] = dur(k) + max((t(c) for c in children[k]), default=0.0)
        return memo[k]
    return t
tail = tail_len()

def priority(k):
    i = items[k]
    dl = i.get("deadline") or dt.date.max
    return (k not in mil_anc.get("internal", ()), k not in mil_anc.get("production", ()), dl, -tail(k), k)

# ---------------------------------------------------------------- schedule simulation
def pool_of(owner):
    if owner == "Hari":
        return "Hari"
    if owner == "Engineering" or not args.leaf_parallel:
        return "builders"
    return owner

def simulate(builders, skip=()):
    """Greedy, non-pre-emptive, STEP-day resolution. Returns finish, start, ready_at (days from TODAY)."""
    cap = defaultdict(lambda: 1)
    cap["Hari"], cap["builders"], cap["phone"] = 1, builders, args.phones
    busy = defaultdict(int)
    finish, start, ready_at, work, active = {}, {}, {}, {}, {}
    for k, i in items.items():
        if not is_open(k):
            finish[k] = 0.0
        else:
            work[k] = 0.0 if set(i["skip_if"]) & set(skip) else float(i["estimate_days"])
    def elapsed(k):
        return 0.0 if set(items[k]["skip_if"]) & set(skip) else float(items[k]["elapsed_days"])
    def working(pool, weekday):
        if pool == "phone":
            return True
        return weekday if (pool == "Hari" or args.agents_weekdays) else True
    t = 0.0
    while len(finish) < len(items) and t < 2000:
        weekday = (TODAY + dt.timedelta(days=int(t))).weekday() < 5
        changed = True
        while changed:  # zero-effort items (milestones, pure waits) release as soon as deps are done
            changed = False
            for k in sorted(set(items) - set(finish) - set(active), key=priority):
                if all(d in finish and finish[d] <= t for d in items[k]["deps"]):
                    ready_at.setdefault(k, t)
                    if work[k] <= 0:
                        start.setdefault(k, t)
                        finish[k] = t + elapsed(k)
                        changed = True
        for k in sorted(set(ready_at) - set(finish) - set(active), key=priority):
            pools = {pool_of(items[k]["owner"])} | {pool_of(u) for u in items[k]["uses"] if u != "phone"}
            if "phone" in items[k]["uses"]:
                pools.add("phone")
            if all(working(p, weekday) and busy[p] < cap[p] for p in pools):
                for p in pools:
                    busy[p] += 1
                active[k] = pools
                start.setdefault(k, t)
        t_next = t + STEP
        for k, pools in list(active.items()):
            if all(working(p, weekday) for p in pools):
                work[k] -= STEP
            if work[k] <= 1e-9:
                for p in pools:
                    busy[p] -= 1
                del active[k]
                finish[k] = t_next + elapsed(k)
        t = t_next
    return finish, start, ready_at

def to_date(tf):
    return TODAY + dt.timedelta(days=max(math.ceil(tf) - 1, 0))

def bandwidth_chain(target, finish):
    chain, k = [], target
    while k:
        if is_open(k):
            chain.append(k)
        opens = [d for d in items[k]["deps"] if is_open(d)]
        k = max(opens, key=lambda d: (finish.get(d, 0), d)) if opens else None
    return list(reversed(chain))

finish, start, ready_at = simulate(args.builders)
unscheduled = [k for k in items if k not in finish]

# ---------------------------------------------------------------- render
def in_slice(i):
    return not args.slice or i["slice"] == args.slice

def fmt_days(x):
    return f"{x:g}"

def est(i):
    s = f"{fmt_days(i['estimate_days'])}d"
    if i["elapsed_days"]:
        s += f" + {fmt_days(i['elapsed_days'])}d elapsed"
    return ("~" + s) if i.get("guess") else s

def dl(i):
    parts = []
    if i.get("deadline"):
        parts.append(i["deadline"].isoformat())
    if i.get("deadline_note"):
        parts.append(i["deadline_note"])
    return "; ".join(parts)

def esc(s):
    return str(s).replace("|", "\\|")

open_items = [k for k in items if is_open(k)]
ready = [k for k in open_items if in_slice(items[k]) and all(not is_open(d) for d in items[k]["deps"])
         and items[k]["status"] != "blocked"]
owners = sorted({items[k]["owner"] for k in items}, key=lambda o: (o != "Hari", o != "Engineering", o))

L = [
    "---", "spine_version: 0.1", "leaf: sequencing", f"generated_for: {TODAY.isoformat()}", "---",
    "<!-- generated by tools/sequence.py from workitems.yml — do not edit -->", "",
    "# Sequencing Leaf", "",
    f"Today **{TODAY.isoformat()}** ({TODAY.strftime('%A')}) · slice **{args.slice or 'all'}** · "
    f"done {sum(not is_open(k) for k in items)}/{len(items)} · builders {args.builders} + Hari · phones {args.phones}", "",
    "Done means verified to the stated level. **Nothing has run on a physical phone**; emulator runs are functional only.", "",
]

# headline
L += ["## Milestones", "", "| Milestone | Item | Critical path (unconstrained) | Bandwidth-aware finish | Calendar days |", "|---|---|---|---|---|"]
for name, mid in milestones.items():
    days, _ = critical_path(mid)
    f = finish.get(mid)
    L.append(f"| {name} | {mid} | {fmt_days(days)} days | "
             f"{to_date(f).isoformat() + ' (' + to_date(f).strftime('%a') + ')' if f is not None else 'unschedulable'} | "
             f"{math.ceil(f) if f is not None else '—'} |")
L += ["", "Unconstrained = sum of effort + elapsed on the longest chain if every owner were free. Bandwidth-aware = "
      f"simulated with {args.builders} builder(s), Hari 1 slot on weekdays, {args.phones} phone, "
      f"agents {'weekdays only' if args.agents_weekdays else 'every day'}; `~` estimates are guesses.", ""]

# scenarios
L += ["### What-if calendar", "", "| Scenario | " + " | ".join(milestones) + " |", "|---|" + "---|" * len(milestones)]
for label, b, skip in [(f"{args.builders} builder(s), personal account (base)", args.builders, ()),
                       (f"{args.builders + 1} builders, personal account", args.builders + 1, ()),
                       (f"{args.builders} builder(s), organisation account exempt from closed test (UNVERIFIED)", args.builders, ("org_account_exempt",))]:
    fs, _, _ = simulate(b, skip)
    L.append(f"| {label} | " + " | ".join(to_date(fs[m]).isoformat() if m in fs else "—" for m in milestones.values()) + " |")
L.append("")

# critical paths
for name, mid in milestones.items():
    days, path = critical_path(mid)
    L += [f"## Critical path — {name} ({mid})", "",
          f"**Unconstrained: {fmt_days(days)} days.** " + " → ".join(f"{p} ({est(items[p])})" for p in path), ""]
    chain = bandwidth_chain(mid, finish)
    L += ["Bandwidth chain (the dependency that finished last, traced back from the milestone):", "",
          "| Item | Owner | Ready | Start | Finish | Queued (days) |", "|---|---|---|---|---|---|"]
    for k in chain:
        r, s, f = ready_at.get(k), start.get(k), finish.get(k)
        L.append(f"| {k} {esc(items[k]['title'][:70])} | {items[k]['owner']} | {to_date(r+STEP) if r is not None else ''} | "
                 f"{to_date(s+STEP) if s is not None else ''} | {to_date(f) if f is not None else ''} | "
                 f"{fmt_days(s - r) if r is not None and s is not None else ''} |")
    L.append("")

# deadlines
L += ["## Deadlines", "", "| Item | Deadline | Days left | Scheduled finish | Flag |", "|---|---|---|---|---|"]
for k in sorted((k for k in items if items[k].get("deadline")), key=lambda k: (items[k]["deadline"], k)):
    i = items[k]
    left = (i["deadline"] - TODAY).days
    f = finish.get(k)
    if not is_open(k):
        flag = "met"
    elif left < 0:
        flag = "**OVERDUE**"
    elif f is not None and to_date(f) > i["deadline"]:
        flag = "**AT RISK** (scheduled after deadline)"
    elif left <= 3:
        flag = "**AT RISK** (≤ 3 days left)"
    elif i.get("guess") or i["elapsed_days"]:
        flag = "on schedule, but rests on a guessed duration"
    else:
        flag = "on schedule"
    L.append(f"| {k} {esc(i['title'][:60])} | {i['deadline']} | {left} | {to_date(f) if f is not None else '—'} | {flag} |")
L.append("")

# decision SLAs
refs = sorted({d for k in open_items for d in items[k]["decisions"]})
L += ["### Decision SLAs (decisions.yml)", "", "| Decision | Blocks release | Status | SLA expires | Flag | Work items |", "|---|---|---|---|---|---|"]
for d in refs:
    e = decisions.get(d, {})
    sla = as_date(e.get("sla_expires_at"))
    flag = ""
    if e.get("status") == "pending" and sla:
        left = (sla - TODAY).days
        flag = "**OVERDUE**" if left < 0 else (f"expires in {left}d" if left <= 2 else "")
    L.append(f"| {d} | {'**yes**' if e.get('blocks_release') else 'no'} | {e.get('status', '?')} | {sla or ''} | {flag} | "
             f"{', '.join(k for k in open_items if d in items[k]['decisions'])} |")
L.append("")

# ready now
L += ["## Ready now, by owner", ""]
for o in owners:
    ks = sorted((k for k in ready if items[k]["owner"] == o), key=priority)
    if not ks:
        continue
    L += [f"### {o}", "", "| Item | Slice | Title | Estimate | Deadline | Decisions | Needs |", "|---|---|---|---|---|---|---|"]
    for k in ks:
        i = items[k]
        needs = "; ".join(filter(None, [("uses " + ", ".join(i["uses"])) if i["uses"] else "", i.get("needs", "")]))
        L.append(f"| {k} | {i['slice']} | {esc(i['title'])} | {est(i)} | {esc(dl(i))} | {' '.join(i['decisions'])} | {esc(needs)} |")
    L.append("")

# Hari's full queue
hk = sorted((k for k in open_items if items[k]["owner"] == "Hari"), key=lambda k: (start.get(k, 1e9), priority(k)))
L += ["## Hari's queue (all open, in simulated order)", "", "| # | Item | Estimate | Deadline | Decisions | Waiting on | Scheduled |", "|---|---|---|---|---|---|---|"]
for n, k in enumerate(hk, 1):
    i = items[k]
    waiting_on = ", ".join(d for d in i["deps"] if is_open(d)) or "ready"
    L.append(f"| {n} | {k} {esc(i['title'])} | {est(i)} | {esc(dl(i))} | {' '.join(i['decisions'])} | {waiting_on} | "
             f"{to_date(start[k] + STEP) if k in start else '—'} → {to_date(finish[k]) if k in finish else '—'} |")
L += ["", f"Hari effort still open: {fmt_days(sum(items[k]['estimate_days'] for k in hk))} days.", ""]

# not required by any milestone
req = set().union(*mil_anc.values()) if mil_anc else set()
extra = [k for k in open_items if k not in req and in_slice(items[k])]
if extra:
    L += ["## Open items no milestone requires", "",
          ", ".join(f"{k} ({items[k]['owner']})" for k in extra) +
          ". Scheduled after milestone work; soft dependencies are dotted in the graph.", ""]

# schedule
L += ["## Schedule (simulated)", "", "| Item | Owner | Slice | Status | Estimate | Start | Finish |", "|---|---|---|---|---|---|---|"]
for k in sorted(open_items, key=lambda k: (finish.get(k, 1e9), k)):
    i = items[k]
    if in_slice(i):
        L.append(f"| {k} {esc(i['title'][:70])} | {i['owner']} | {i['slice']} | {i['status']} | {est(i)} | "
                 f"{to_date(start[k] + STEP) if k in start else '—'} | {to_date(finish[k]) if k in finish else '—'} |")
L.append("")

# status
L += ["## Done — verified to", "", "| Item | Owner | Verified to |", "|---|---|---|"]
for k, i in items.items():
    if in_slice(i) and not is_open(k):
        L.append(f"| {k} {esc(i['title'])} | {i['owner']} | {esc(i['verified'])} |")
L.append("")

if warnings:
    L += ["## Graph warnings", ""] + [f"- {w}" for w in warnings] + [""]
if unscheduled:
    L += [f"**Unschedulable:** {', '.join(unscheduled)}", ""]

# mermaid
_, prod_path = critical_path(milestones["production"]) if "production" in milestones else (0, [])
_, int_path = critical_path(milestones["internal"]) if "internal" in milestones else (0, [])
crit_edges = set(zip(prod_path, prod_path[1:])) | set(zip(int_path, int_path[1:]))
crit_nodes = set(prod_path) | set(int_path)
L += ["## Graph", "", "Red: critical paths to the internal upload and to production. Dotted: soft dependency.", "",
      "```mermaid", "flowchart LR"]
style = {"done": "done", "todo": "todo", "in_progress": "prog", "blocked": "blocked"}
for k, i in items.items():
    if in_slice(i):
        title = re.sub(r'["\[\]{}()<>|#;]', " ", i["title"])
        title = re.sub(r"\s+", " ", title)
        title = title[:40].rstrip() + ("…" if len(title) > 40 else "")
        cls = "hari" if i["owner"] == "Hari" and is_open(k) else style[i["status"]]
        L.append(f'  {k}["{k} {title}"]:::{cls}')
edge_i, crit_idx = 0, []
for k, i in items.items():
    for d in i["deps"]:
        if in_slice(i) and in_slice(items[d]):
            L.append(f"  {d} --> {k}")
            # a critical edge links consecutive open items; done deps collapse out of the path
            if (d, k) in crit_edges:
                crit_idx.append(edge_i)
            edge_i += 1
    for d in i["soft_deps"]:
        if in_slice(i) and in_slice(items[d]):
            L.append(f"  {d} -.-> {k}")
            edge_i += 1
L += [
    "  classDef done fill:#d3e8df,stroke:#1f5c4a,color:#0b2a20",
    "  classDef todo fill:#fff,stroke:#8a877f,color:#222",
    "  classDef hari fill:#e4e9f7,stroke:#34488a,color:#111",
    "  classDef prog fill:#fdf1c7,stroke:#a07a00,color:#222",
    "  classDef blocked fill:#f7d4d0,stroke:#a33,color:#222",
    "  classDef crit stroke:#c0392b,stroke-width:3px",
]
cn = [k for k in items if k in crit_nodes and in_slice(items[k])]
if cn:
    L.append(f"  class {','.join(cn)} crit")
if crit_idx:
    L.append(f"  linkStyle {','.join(map(str, crit_idx))} stroke:#c0392b,stroke-width:3px")
L += ["```", ""]

OUT.write_text("\n".join(L))
summary = " | ".join(f"{n} {to_date(finish[m])}" for n, m in milestones.items() if m in finish)
print(f"ready: {', '.join(sorted(ready))}\n{summary}\n" + "".join(f"warning: {w}\n" for w in warnings), end="")
