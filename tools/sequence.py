#!/usr/bin/env python3
"""Sequencing Leaf renderer — two platforms, four milestones, declared resources.

Reads leaves/sequencing/workitems.yml (and leaves/decisions.yml, leaves/SPINE.md for cross-checks)
and writes leaves/sequencing/SEQUENCING.md with:
  - validation: unknown deps / decisions / spine IDs / resources / platforms, cycles,
    done items without a `verified` level, verified levels outside the declared vocabulary,
    and every `uses:` resource declared available or not
  - resource gates: what is not in hand, which item would create it, what waits on it
  - Ready-Now queue per PLATFORM, then per owner, Hari first
  - deadlines (overdue / at risk against --today) and decision SLAs from decisions.yml,
    split by which store the decision blocks (blocks_release_scope)
  - per milestone (two per store): unconstrained critical path and a bandwidth-aware calendar date
  - a cross-platform independence check: no Android item in an iOS milestone's ancestry, and vice versa
  - a schedule simulation with N builders, Hari, and the declared physical resources
  - Mermaid graph with the per-store critical paths highlighted

usage: tools/sequence.py [--slice BENCH|MVP|PLAY|STORE|CORE] [--platform android|ios|both]
                         [--builders N] [--today YYYY-MM-DD] [--phones N] [--iphones N]
                         [--leaf-parallel] [--agents-weekdays] [--check]

Model (stated in the output too):
  estimate_days = working days of effort; consumes the owner's pool (Hari: 1 slot, weekdays only;
  everyone else: the builder pool of N agents, every day unless --agents-weekdays) plus any `uses`
  resource. elapsed_days = calendar days after the effort that consume nobody. Work is not
  pre-empted. Scheduling is greedy: milestone-path items first, then longest downstream chain.

  A resource declared `available: false` with an `acquired_by:` item becomes an IMPLICIT dependency
  of every item that uses it — that is how "we have no iPhone" reaches the calendar instead of
  being discovered on the day. A resource declared `available: false` with no `acquired_by` makes
  every item that uses it unschedulable, and the item says so.
"""
import argparse, datetime as dt, math, pathlib, re, sys
from collections import defaultdict
import yaml

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "leaves/sequencing/workitems.yml"
OUT = ROOT / "leaves/sequencing/SEQUENCING.md"
DECISIONS = ROOT / "leaves/decisions.yml"
SPINE = ROOT / "leaves/SPINE.md"
STEP = 0.25

PLATFORMS = ("android", "ios", "both")
# The verified-level vocabulary, cheapest first. `done` must state one of these as its first word.
LEVELS = ("type-checked-only", "delivered", "resolved_human", "core", "host", "unit",
          "swift-macos", "build", "emulator", "simulator", "phone", "iphone", "play", "appstore")
# Levels that mean "a real handset ran this". Nothing should be here yet.
HANDSET_LEVELS = ("phone", "iphone")
OWNER_POOLS = ("Hari", "Engineering")   # `uses:` values that are people, not things

ap = argparse.ArgumentParser()
ap.add_argument("--slice")
ap.add_argument("--platform", choices=("android", "ios", "both"))
ap.add_argument("--builders", type=int, default=1, help="Engineering-capable agents (default 1)")
ap.add_argument("--phones", type=int, default=None, help="override the declared capacity of `phone`")
ap.add_argument("--iphones", type=int, default=None, help="override the declared capacity of `iphone`")
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
resources = doc.get("resources", {}) or {}

# milestones: {name: {item, platform, title}}
milestones, mil_meta = {}, {}
for name, m in (doc.get("milestones", {}) or {}).items():
    if isinstance(m, str):          # 0.1 shorthand
        m = {"item": m, "platform": "both", "title": name}
    milestones[name] = m["item"]
    mil_meta[name] = m

# ---------------------------------------------------------------- validation
decisions = {e["id"]: e for e in (yaml.safe_load(DECISIONS.read_text()) or [])} if DECISIONS.exists() else {}
spine_ids = set(re.findall(r"\b([CMR]\d+)\b", SPINE.read_text())) if SPINE.exists() else set()
STATUSES = {"done", "in_progress", "todo", "blocked"}
REQUIRED = ("id", "title", "slice", "platform", "spine", "owner", "status", "estimate_days", "deps")

def as_date(v):
    if v is None or isinstance(v, dt.date):
        return v
    return dt.date.fromisoformat(str(v))

# -- resources declared? every one must say available: true or false ------------------------------
for rname, r in resources.items():
    if r is None or "available" not in r:
        errors.append(f"resource {rname}: must declare `available: true` or `available: false`")
        continue
    if not isinstance(r["available"], bool):
        errors.append(f"resource {rname}: `available` must be a boolean, got {r['available']!r}")
    if not r["available"] and r.get("acquired_by") and r["acquired_by"] not in items:
        errors.append(f"resource {rname}: acquired_by names unknown work item {r['acquired_by']}")
    r.setdefault("capacity", 1)
if args.phones is not None and "phone" in resources:
    resources["phone"]["capacity"] = args.phones
if args.iphones is not None and "iphone" in resources:
    resources["iphone"]["capacity"] = args.iphones

for k, i in items.items():
    for f in REQUIRED:
        if f not in i:
            errors.append(f"{k}: missing field `{f}`")
    i.setdefault("deps", []); i.setdefault("soft_deps", []); i.setdefault("uses", [])
    i.setdefault("decisions", []); i.setdefault("elapsed_days", 0); i.setdefault("skip_if", [])
    i["resource_deps"] = []
    if i.get("status") not in STATUSES:
        errors.append(f"{k}: unknown status {i.get('status')}")
    if i.get("slice") not in doc.get("slices", {}):
        errors.append(f"{k}: unknown slice {i.get('slice')}")
    if i.get("platform") not in PLATFORMS:
        errors.append(f"{k}: platform must be one of {'/'.join(PLATFORMS)}, got {i.get('platform')!r}")
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
        if u not in resources and u not in OWNER_POOLS:
            errors.append(f"{k}: uses `{u}`, which is not declared in `resources:` "
                          f"(declare it available or not, or use one of {'/'.join(OWNER_POOLS)})")
    if i.get("status") == "done":
        v = str(i.get("verified") or "")
        if not v:
            errors.append(f"{k}: done without a `verified` level")
        else:
            first = v.split()[0].strip(":,;.").lower()
            if first not in LEVELS:
                errors.append(f"{k}: `verified` starts with {first!r}, which is not a declared level "
                              f"({', '.join(LEVELS)})")
            elif first in HANDSET_LEVELS:
                warnings.append(f"{k} claims `{first}` — a physical-handset level. Sequencing has no "
                                f"evidence any handset exists; confirm before this ships in the report")
    try:
        i["deadline"] = as_date(i.get("deadline"))
    except ValueError:
        errors.append(f"{k}: deadline must be an ISO date (use deadline_note for relative deadlines)")

for name, m in mil_meta.items():
    if m["item"] not in items:
        errors.append(f"milestone {name} → unknown item {m['item']}")
    if m.get("platform") not in PLATFORMS:
        errors.append(f"milestone {name}: platform must be one of {'/'.join(PLATFORMS)}")

# -- resource availability becomes a dependency, or a block ---------------------------------------
resource_blocked = {}
if not errors:
    for k, i in items.items():
        if i["status"] == "done":
            continue
        for u in i["uses"]:
            r = resources.get(u)
            if not r or r["available"]:
                continue
            owner_item = r.get("acquired_by")
            if owner_item and owner_item != k:
                if owner_item not in i["deps"]:
                    i["deps"].append(owner_item)
                    i["resource_deps"].append((u, owner_item))
            elif not owner_item:
                resource_blocked.setdefault(k, []).append(u)
    for k, missing in resource_blocked.items():
        warnings.append(f"{k} is UNSCHEDULABLE: uses {', '.join(missing)}, declared unavailable with "
                        f"no `acquired_by` item to create it")

# cycles over hard + soft edges (after resource deps are folded in)
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

def blocking_scope(e):
    """Which stores a decision blocks. Falls back to the platform tag when scope is absent."""
    if not e.get("blocks_release"):
        return set()
    scope = e.get("blocks_release_scope") or e.get("platform") or "both"
    return {"android", "ios"} if scope == "both" else {scope}

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
                if re.fullmatch(r"W\d+[A-Z]?", str(ref)) and ref not in items:
                    warnings.append(f"decisions.yml {did}.{fld} names unknown work item {ref}")
        if e.get("blocks_release") and did not in referenced:
            stores = "/".join(sorted(blocking_scope(e))) or "?"
            warnings.append(f"{stores}-blocking decision {did} is not referenced by any work item")
        if set(map(str, e.get("depends_on") or [])) & set(map(str, e.get("blocks") or [])):
            warnings.append(f"decisions.yml {did} both depends_on and blocks "
                            f"{sorted(set(map(str, e['depends_on'])) & set(map(str, e['blocks'])))} (split into provisional/final)")

if errors:
    print("SEQUENCING ERRORS:\n  " + "\n  ".join(errors))
    sys.exit(1)

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

mil_anc = {name: ancestors(mid) for name, mid in milestones.items()}

# cross-platform independence: an iOS milestone must not have an android-only item in its ancestry
cross = {}
for name, mid in milestones.items():
    plat = mil_meta[name].get("platform")
    if plat in ("android", "ios"):
        other = "ios" if plat == "android" else "android"
        bad = sorted(a for a in mil_anc[name] if items[a]["platform"] == other and is_open(a))
        if bad:
            cross[name] = bad
for name, bad in cross.items():
    warnings.append(f"milestone {name} ({mil_meta[name]['platform']}) depends on open "
                    f"{mil_meta[name]['platform'] == 'android' and 'ios' or 'android'}-only items: "
                    f"{', '.join(bad)} — the two store calendars are supposed to be independent")

if args.check:
    print("OK" + ("".join("\n  warning: " + w for w in warnings)))
    sys.exit(0)

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

def tail_len():
    memo = {}
    def t(k):
        if k not in memo:
            memo[k] = dur(k) + max((t(c) for c in children[k]), default=0.0)
        return memo[k]
    return t
tail = tail_len()

MIL_ORDER = list(milestones)
def priority(k):
    i = items[k]
    dl = i.get("deadline") or dt.date.max
    on_path = tuple(k not in mil_anc.get(n, ()) for n in MIL_ORDER)
    return on_path + (dl, -tail(k), k)

# ---------------------------------------------------------------- schedule simulation
def pool_of(owner):
    if owner == "Hari":
        return "Hari"
    if owner == "Engineering" or not args.leaf_parallel:
        return "builders"
    return owner

def pools_for(k):
    p = {pool_of(items[k]["owner"])}
    for u in items[k]["uses"]:
        p.add(pool_of(u) if u in OWNER_POOLS else u)
    return p

def simulate(builders, skip=()):
    """Greedy, non-pre-emptive, STEP-day resolution. Returns finish, start, ready_at (days from TODAY)."""
    cap = defaultdict(lambda: 1)
    cap["Hari"], cap["builders"] = 1, builders
    for rname, r in resources.items():
        if rname not in OWNER_POOLS:
            cap[rname] = int(r.get("capacity", 1))
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
        if pool in resources and pool not in OWNER_POOLS:
            return True                       # a thing, not a person: available on any day
        return weekday if (pool == "Hari" or args.agents_weekdays) else True
    schedulable = [k for k in items if k not in resource_blocked]
    t = 0.0
    while len(finish) < len(schedulable) and t < 2000:
        weekday = (TODAY + dt.timedelta(days=int(t))).weekday() < 5
        changed = True
        while changed:  # zero-effort items (milestones, pure waits) release as soon as deps are done
            changed = False
            for k in sorted(set(schedulable) - set(finish) - set(active), key=priority):
                if all(d in finish and finish[d] <= t for d in items[k]["deps"]):
                    ready_at.setdefault(k, t)
                    if work[k] <= 0:
                        start.setdefault(k, t)
                        finish[k] = t + elapsed(k)
                        changed = True
        for k in sorted(set(ready_at) - set(finish) - set(active), key=priority):
            pools = pools_for(k)
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
def in_view(i):
    if args.slice and i["slice"] != args.slice:
        return False
    if args.platform and i["platform"] not in (args.platform, "both"):
        return False
    return True

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

def d_str(tf):
    return to_date(tf).isoformat() if tf is not None else "—"

open_items = [k for k in items if is_open(k)]
ready = [k for k in open_items if in_view(items[k]) and k not in resource_blocked
         and all(not is_open(d) for d in items[k]["deps"]) and items[k]["status"] != "blocked"]
owners = sorted({items[k]["owner"] for k in items}, key=lambda o: (o != "Hari", o != "Engineering", o))

L = [
    "---", "spine_version: 0.2", "leaf: sequencing", f"generated_for: {TODAY.isoformat()}", "---",
    "<!-- generated by tools/sequence.py from workitems.yml — do not edit -->", "",
    "# Sequencing Leaf", "",
    f"Today **{TODAY.isoformat()}** ({TODAY.strftime('%A')}) · slice **{args.slice or 'all'}** · "
    f"platform **{args.platform or 'all'}** · done {sum(not is_open(k) for k in items)}/{len(items)} · "
    f"builders {args.builders} + Hari", "",
    "Done means verified to the stated level, never more. **Nothing has run on a physical Android phone "
    "or on any iPhone.** Emulator runs are functional only; the 94 iOS tests ran on macOS, not on iOS.", "",
]

# ---- resources first: they decide everything below
L += ["## Resource gates", "",
      "Every `uses:` value must be declared here as available or not. An unavailable resource with an "
      "`acquired_by` item becomes an implicit dependency of everything that uses it — shown as "
      "`gate` in the tables below.", "",
      "| Resource | In hand | Capacity | Created by | Open items waiting on it |", "|---|---|---|---|---|"]
for rname, r in resources.items():
    users = sorted(k for k in open_items if rname in items[k]["uses"])
    ab = r.get("acquired_by")
    ab_s = f"{ab} ({d_str(finish.get(ab))})" if ab else ("—" if r["available"] else "**nothing — blocked**")
    L.append(f"| `{rname}` {esc(r.get('title',''))} | {'yes' if r['available'] else '**NO**'} | "
             f"{r.get('capacity',1)} | {ab_s} | {len(users)}: {', '.join(users) if users else '—'} |")
L.append("")
for rname, r in resources.items():
    if not r["available"] and r.get("note"):
        L += [f"**`{rname}` — not in hand.** " + " ".join(str(r["note"]).split()), ""]

# ---- milestones
L += ["## Milestones — two per store, independent calendars", "",
      "| Milestone | Store | Item | Critical path (unconstrained) | Bandwidth-aware finish | Calendar days |",
      "|---|---|---|---|---|---|"]
for name, mid in milestones.items():
    days, _ = critical_path(mid)
    f = finish.get(mid)
    L.append(f"| **{name}** — {esc(mil_meta[name].get('title',''))} | {mil_meta[name]['platform']} | {mid} | "
             f"{fmt_days(days)} days | "
             f"{to_date(f).isoformat() + ' (' + to_date(f).strftime('%a') + ')' if f is not None else 'unschedulable'} | "
             f"{math.ceil(f) if f is not None else '—'} |")
L += ["", "Unconstrained = sum of effort + elapsed on the longest chain if every owner were free. "
      f"Bandwidth-aware = simulated with {args.builders} builder(s), Hari 1 slot on weekdays, the "
      f"declared resource capacities, agents {'weekdays only' if args.agents_weekdays else 'every day'}; "
      "`~` estimates are guesses.", ""]

# cross-platform independence
L += ["### Are the two stores independent?", ""]
if cross:
    for name, bad in cross.items():
        L.append(f"- **No.** `{name}` ({mil_meta[name]['platform']}) still waits on open "
                 f"{'ios' if mil_meta[name]['platform']=='android' else 'android'}-only items: {', '.join(bad)}.")
else:
    L.append("- **Yes.** No open item tagged for one platform sits in the other platform's milestone "
             "ancestry. What the two queues share is Hari, the shared `/core` and `/tools` work, and the "
             "eight both-platform decisions (D-009, D-010, D-017, D-020, D-022, D-023, D-024, D-025).")
ios_m = [n for n in milestones if mil_meta[n]["platform"] == "ios"]
and_m = [n for n in milestones if mil_meta[n]["platform"] == "android"]
if ios_m and and_m:
    iosf = max((finish.get(milestones[n], 0) for n in ios_m), default=0)
    andf = max((finish.get(milestones[n], 0) for n in and_m), default=0)
    verdict = ("**iOS reaches users first** by about %d days" % math.ceil(andf - iosf)) if iosf < andf else \
              ("**Android reaches users first** by about %d days" % math.ceil(iosf - andf))
    L += ["", f"- On the base scenario: {verdict} ({d_str(iosf)} vs {d_str(andf)}). Apple imposes no "
          "12-tester / 14-day gate, so the App Store release is not downstream of the Play closed test. "
          "Whether that is what happens is a decision (D-041), not a constraint.", ""]

# scenarios
L += ["### What-if calendar", "", "| Scenario | " + " | ".join(milestones) + " |", "|---|" + "---|" * len(milestones)]
for label, b, skip in [
        (f"{args.builders} builder(s), hardware still to buy (base)", args.builders, ()),
        (f"{args.builders + 1} builders", args.builders + 1, ()),
        ("both handsets already in a drawer", args.builders, ("hardware_in_hand",)),
        ("organisation account exempt from the Play closed test (UNVERIFIED)", args.builders, ("org_account_exempt",)),
        ("both of the above", args.builders, ("hardware_in_hand", "org_account_exempt"))]:
    fs, _, _ = simulate(b, skip)
    L.append(f"| {label} | " + " | ".join(d_str(fs.get(m)) for m in milestones.values()) + " |")
L.append("")

# critical paths
for name, mid in milestones.items():
    days, path = critical_path(mid)
    L += [f"## Critical path — {name} ({mid}, {mil_meta[name]['platform']})", "",
          f"**Unconstrained: {fmt_days(days)} days.** " + " → ".join(f"{p} ({est(items[p])})" for p in path), ""]
    chain = bandwidth_chain(mid, finish)
    L += ["Bandwidth chain (the dependency that finished last, traced back from the milestone):", "",
          "| Item | Owner | Plat | Ready | Start | Finish | Queued (days) |", "|---|---|---|---|---|---|---|"]
    for k in chain:
        r, s, f = ready_at.get(k), start.get(k), finish.get(k)
        L.append(f"| {k} {esc(items[k]['title'][:66])} | {items[k]['owner']} | {items[k]['platform']} | "
                 f"{d_str(r+STEP) if r is not None else '—'} | {d_str(s+STEP) if s is not None else '—'} | "
                 f"{d_str(f)} | {fmt_days(s - r) if r is not None and s is not None else ''} |")
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
    L.append(f"| {k} {esc(i['title'][:60])} | {i['deadline']} | {left} | {d_str(f)} | {flag} |")
L.append("")

# decision SLAs, split by store
refs = sorted({d for k in open_items for d in items[k]["decisions"]})
L += ["### Decision SLAs (decisions.yml), by the store they block", "",
      "| Decision | Blocks Play | Blocks App Store | Status | SLA expires | Flag | Work items |",
      "|---|---|---|---|---|---|---|"]
for d in refs:
    e = decisions.get(d, {})
    sc = blocking_scope(e)
    sla = as_date(e.get("sla_expires_at"))
    flag = ""
    if e.get("status") == "pending" and sla:
        left = (sla - TODAY).days
        flag = "**OVERDUE**" if left < 0 else (f"expires in {left}d" if left <= 2 else "")
    L.append(f"| {d} | {'**yes**' if 'android' in sc else 'no'} | {'**yes**' if 'ios' in sc else 'no'} | "
             f"{e.get('status', '?')} | {sla or ''} | {flag} | "
             f"{', '.join(k for k in open_items if d in items[k]['decisions'])} |")
blocking = {d: e for d, e in decisions.items() if e.get("blocks_release") and e.get("status") == "pending"}
L += ["", f"{sum(1 for e in blocking.values() if 'android' in blocking_scope(e))} open decisions block the "
      f"Play release; {sum(1 for e in blocking.values() if 'ios' in blocking_scope(e))} block the App Store "
      f"release; {sum(1 for e in blocking.values() if blocking_scope(e) == {'android','ios'})} block both.", ""]

# ready now, per platform then owner
L += ["## Ready now, by platform and owner", ""]
for plat in ("both", "android", "ios"):
    ks_all = [k for k in ready if items[k]["platform"] == plat]
    if not ks_all:
        continue
    label = {"both": "Shared (`/core`, `/tools`, and decisions that serve both stores)",
             "android": "Android → Play", "ios": "iOS → App Store"}[plat]
    L += [f"### {label}", ""]
    for o in owners:
        ks = sorted((k for k in ks_all if items[k]["owner"] == o), key=priority)
        if not ks:
            continue
        L += [f"**{o}**", "", "| Item | Slice | Title | Estimate | Deadline | Decisions | Needs |",
              "|---|---|---|---|---|---|---|"]
        for k in ks:
            i = items[k]
            needs = "; ".join(filter(None, [("uses " + ", ".join(i["uses"])) if i["uses"] else "", i.get("needs", "")]))
            L.append(f"| {k} | {i['slice']} | {esc(i['title'])} | {est(i)} | {esc(dl(i))} | "
                     f"{' '.join(i['decisions'])} | {esc(needs[:240])} |")
        L.append("")

# Hari's full queue
hk = sorted((k for k in open_items if items[k]["owner"] == "Hari"), key=lambda k: (start.get(k, 1e9), priority(k)))
L += ["## Hari's queue (all open, in simulated order)", "",
      "| # | Item | Plat | Estimate | Deadline | Decisions | Waiting on | Scheduled |",
      "|---|---|---|---|---|---|---|---|"]
for n, k in enumerate(hk, 1):
    i = items[k]
    waiting_on = ", ".join(d for d in i["deps"] if is_open(d)) or "ready"
    L.append(f"| {n} | {k} {esc(i['title'][:70])} | {i['platform']} | {est(i)} | {esc(dl(i))} | "
             f"{' '.join(i['decisions'])} | {waiting_on} | "
             f"{d_str(start[k] + STEP) if k in start else '—'} → {d_str(finish.get(k))} |")
L += ["", f"Hari effort still open: {fmt_days(sum(items[k]['estimate_days'] for k in hk))} days "
      f"({fmt_days(sum(items[k]['estimate_days'] for k in hk if items[k]['platform'] != 'ios'))} of it not iOS).", ""]

# not required by any milestone
req = set().union(*mil_anc.values()) if mil_anc else set()
extra = [k for k in open_items if k not in req and in_view(items[k])]
if extra:
    L += ["## Open items no milestone requires", "",
          ", ".join(f"{k} ({items[k]['owner']}, {items[k]['platform']})" for k in extra) +
          ". Scheduled after milestone work; soft dependencies are dotted in the graph.", ""]

# schedule
L += ["## Schedule (simulated)", "", "| Item | Owner | Plat | Slice | Estimate | Gate | Start | Finish |",
      "|---|---|---|---|---|---|---|---|"]
for k in sorted(open_items, key=lambda k: (finish.get(k, 1e9), k)):
    i = items[k]
    if in_view(i):
        gate = ", ".join(f"{r}→{o}" for r, o in i["resource_deps"]) or ""
        L.append(f"| {k} {esc(i['title'][:66])} | {i['owner']} | {i['platform']} | {i['slice']} | {est(i)} | "
                 f"{gate} | {d_str(start[k] + STEP) if k in start else '—'} | {d_str(finish.get(k))} |")
L.append("")

# status
L += ["## Done — verified to", "", "| Item | Owner | Plat | Verified to |", "|---|---|---|---|"]
for k, i in items.items():
    if in_view(i) and not is_open(k):
        L.append(f"| {k} {esc(i['title'][:60])} | {i['owner']} | {i['platform']} | {esc(i['verified'])} |")
L.append("")

if warnings:
    L += ["## Graph warnings", ""] + [f"- {w}" for w in warnings] + [""]
if unscheduled:
    L += [f"**Unschedulable:** {', '.join(sorted(unscheduled))}", ""]

# mermaid
crit_edges, crit_nodes = set(), set()
for name, mid in milestones.items():
    _, p = critical_path(mid)
    crit_edges |= set(zip(p, p[1:]))
    crit_nodes |= set(p)
L += ["## Graph", "",
      "Red: the critical path to each of the four milestones. Dotted: soft dependency. "
      "Blue: Hari. An edge created by a resource gate is a normal edge — the gate is in the item table.", "",
      "```mermaid", "flowchart LR"]
style = {"done": "done", "todo": "todo", "in_progress": "prog", "blocked": "blocked"}
for k, i in items.items():
    if in_view(i):
        title = re.sub(r'["\[\]{}()<>|#;]', " ", i["title"])
        title = re.sub(r"\s+", " ", title)
        title = title[:40].rstrip() + ("…" if len(title) > 40 else "")
        cls = "hari" if i["owner"] == "Hari" and is_open(k) else style[i["status"]]
        if k in resource_blocked:
            cls = "blocked"
        L.append(f'  {k}["{k} {title}"]:::{cls}')
edge_i, crit_idx = 0, []
for k, i in items.items():
    for d in i["deps"]:
        if in_view(i) and in_view(items[d]):
            L.append(f"  {d} --> {k}")
            if (d, k) in crit_edges:
                crit_idx.append(edge_i)
            edge_i += 1
    for d in i["soft_deps"]:
        if in_view(i) and in_view(items[d]):
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
cn = [k for k in items if k in crit_nodes and in_view(items[k])]
if cn:
    L.append(f"  class {','.join(cn)} crit")
if crit_idx:
    L.append(f"  linkStyle {','.join(map(str, crit_idx))} stroke:#c0392b,stroke-width:3px")
L += ["```", ""]

OUT.write_text("\n".join(L))
for plat in ("both", "android", "ios"):
    ks = sorted(k for k in ready if items[k]["platform"] == plat)
    print(f"ready [{plat}]: {', '.join(ks) or '—'}")
print(" | ".join(f"{n} {d_str(finish.get(m))}" for n, m in milestones.items()))
print("".join(f"warning: {w}\n" for w in warnings), end="")
