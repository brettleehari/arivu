#!/usr/bin/env python3
"""Fails if any native library in an AAB or APK is not 16 KB page aligned.

spine: C2 — a 16 KB page-size device refuses to load a library whose LOAD segments are aligned to
4 KB, and the failure is an install-time crash on exactly the phones the Spine promises to serve.
android/llama/src/main/cpp/CMakeLists.txt passes -Wl,-z,max-page-size=16384; this checks the
artifact rather than trusting the flag.

    tools/check_alignment.py android/app/build/outputs/bundle/release/app-release.aab

The same check runs inside tools/release_check.sh for a signed release. This standalone copy is
what CI calls, so an unsigned CI bundle can still be checked (.github/workflows/android.yml).
"""
import struct
import sys
import zipfile

PAGE = 16384


def load_aligns(blob: bytes):
    """Alignment of every PT_LOAD segment in an ELF64 image."""
    if blob[:4] != b"\x7fELF" or blob[4] != 2:
        return None
    phoff, = struct.unpack_from("<Q", blob, 0x20)
    phentsize, phnum = struct.unpack_from("<HH", blob, 0x36)
    out = []
    for k in range(phnum):
        off = phoff + k * phentsize
        if struct.unpack_from("<I", blob, off)[0] == 1:  # PT_LOAD
            out.append(struct.unpack_from("<Q", blob, off + 0x30)[0])
    return out


def main(path: str) -> int:
    z = zipfile.ZipFile(path)
    libs = [i for i in z.infolist() if "/lib/" in i.filename and i.filename.endswith(".so")]
    # An APK keeps its libraries under lib/ without a split prefix.
    libs += [i for i in z.infolist() if i.filename.startswith("lib/") and i.filename.endswith(".so")
             and i not in libs]
    if not libs:
        print(f"FAIL  no native libraries found in {path}")
        return 1

    bad = 0
    for i in sorted(libs, key=lambda e: e.filename):
        aligns = load_aligns(z.read(i))
        if aligns is None:
            print(f"FAIL  {i.filename}: not an ELF64 image")
            bad += 1
        elif not aligns or min(aligns) < PAGE:
            print(f"FAIL  {i.filename}: LOAD alignment {aligns} < {PAGE}")
            bad += 1
    if bad:
        print(f"\nFAILED: {bad} of {len(libs)} libraries are not {PAGE // 1024} KB aligned")
        return 1
    print(f"OK: {len(libs)} native libraries, all LOAD segments >= {PAGE // 1024} KB aligned")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
