#!/usr/bin/env python3
"""Spine propagation check (leaves/SPINE.md "Propagation discipline").

Lists every Leaf stamped with an older spine_version than leaves/SPINE.md, in the fixed propagation order,
and regenerates the two derived Leaves (Compliance, Sequencing). Exit 1 while anything is stale.

To mark a Leaf current: review it against the new Spine, then update its `spine_version` stamp.
"""
import pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
spine_v = re.search(r"spine_version:\s*([\d.]+)", (ROOT / "leaves/SPINE.md").read_text()).group(1)

ORDER = [
    ("2. Architecture", ["leaves/architecture.md"]),
    ("3. Engineering + Design", ["leaves/engineering.md", "leaves/design.md"]),
    ("4. GTM + Compliance", ["leaves/gtm/tour.html"]),
    ("meta", ["leaves/sequencing/workitems.yml", "leaves/decisions.yml"]),
]

stale = 0
print(f"leaves/SPINE.md spine_version {spine_v}")
for step, files in ORDER:
    for f in files:
        p = ROOT / f
        m = re.search(r"spine_version:\s*([\d.]+)", p.read_text()) if p.exists() else None
        v = m.group(1) if m else "missing"
        ok = v == spine_v
        stale += not ok
        print(f"  {'current' if ok else 'STALE  '}  {step:24} {f} ({v})")

for script in ("tools/trace.py", "tools/sequence.py"):
    subprocess.run([sys.executable, str(ROOT / script)], check=False)

sys.exit(1 if stale else 0)
