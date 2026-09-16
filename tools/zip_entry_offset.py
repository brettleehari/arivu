#!/usr/bin/env python3
"""Print compression and data offset of entries in an APK/zip.  spine: C1, C2

Answers leaves/BRIEF.md's open question "asset page alignment behaviour": the model can only be
mmap'd straight from the APK if it is STORED and its data offset is a multiple of 32
(tensor alignment); a multiple of the page size is not required.

usage: zip_entry_offset.py some.apk [substring]
"""
import struct, sys, zipfile

path = sys.argv[1]
needle = sys.argv[2] if len(sys.argv) > 2 else ""
ok = True
with zipfile.ZipFile(path) as z, open(path, "rb") as f:
    for info in z.infolist():
        if needle not in info.filename:
            continue
        f.seek(info.header_offset)
        sig, = struct.unpack("<I", f.read(4))
        assert sig == 0x04034B50, "bad local header"
        f.seek(info.header_offset + 26)
        name_len, extra_len = struct.unpack("<HH", f.read(4))
        data = info.header_offset + 30 + name_len + extra_len
        stored = info.compress_type == zipfile.ZIP_STORED
        verdict = "OK" if stored and data % 32 == 0 else "NOT MMAPPABLE"
        ok &= verdict == "OK"
        print(f"{info.filename}  {'stored' if stored else 'DEFLATED'}  offset={data}  "
              f"mod32={data % 32} mod4096={data % 4096} mod16384={data % 16384}  {verdict}")
sys.exit(0 if ok else 1)
