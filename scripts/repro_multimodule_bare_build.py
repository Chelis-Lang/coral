#!/usr/bin/env python3
"""Reproduce the stripped multi-module bare-build backend failure.

This is an upstream-triage helper, not a CI gate.

It concatenates stripped Coral modules into one temporary file, prefixes
function names to avoid obvious user-space symbol collisions, runs
`chelis build`, then tries to link the generated C with a tiny driver.

Expected current outcome on `chelis v0.1.13`:
- `chelis build` succeeds
- native C compile/link fails because generated signatures collapse some
  polymorphic ADT/value paths to `int`

Exit codes:
- 0: reproduced the known failure
- 1: did not reproduce the expected failure
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()
MODULE_PRESETS = {
    "groupby": [
        ("src/internal/hamt.ch", "hamt__"),
        ("vendor/nautilus/src/stats.ch", "stats__"),
        ("src/frame.ch", "frame__"),
        ("src/groupby.ch", "groupby__"),
    ],
    "join": [
        ("src/internal/hamt.ch", "hamt__"),
        ("vendor/nautilus/src/stats.ch", "stats__"),
        ("src/frame.ch", "frame__"),
        ("src/join.ch", "join__"),
    ],
}


def strip_module_surface(src: str) -> str:
    src = re.sub(r"^module .*\n", "", src, flags=re.M)
    src = re.sub(r"^import .*\n", "", src, flags=re.M)
    src = re.sub(r"^export \([^)]*\)\s*\n", "", src, flags=re.M | re.S)
    return src


def apply_name_map(src: str, mapping: dict[str, str]) -> str:
    updated = src
    for old, new in sorted(mapping.items(), key=lambda item: -len(item[0])):
        updated = re.sub(rf"\b{re.escape(old)}(?=\s*\[)", new, updated)
        updated = re.sub(rf"\b{re.escape(old)}(?=\s*\()", new, updated)
    return updated


def prefix_defs(src: str, prefix: str) -> tuple[str, dict[str, str]]:
    names = re.findall(r"^def\s+([A-Za-z_][A-Za-z0-9_]*)", src, flags=re.M)
    mapping = {name: f"{prefix}{name}" for name in names}
    return apply_name_map(src, mapping), mapping


def build_prefixed_modules(specs: list[tuple[str, str]]) -> str:
    accumulated: dict[str, str] = {}
    parts: list[str] = []
    for rel_path, prefix in specs:
        src = strip_module_surface((REPO / rel_path).read_text())
        src, local_map = prefix_defs(src, prefix)
        src = apply_name_map(src, accumulated)
        parts.append(src)
        accumulated.update(local_map)
    return "\n".join(parts)


def native_link_cmd(binary: Path, sources: list[Path], out_dir: Path) -> list[str]:
    return [
        "gcc",
        "-O2",
        "-fopenmp",
        "-o",
        str(binary),
        *(str(source) for source in sources),
        "-I",
        str(out_dir),
        "-L",
        str(out_dir),
        "-lchelis_runtime",
        "-lm",
        "-lpthread",
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=sorted(MODULE_PRESETS), default="groupby")
    args = parser.parse_args()

    body = build_prefixed_modules(MODULE_PRESETS[args.target])
    body += "\n\ndef main() -> f32 = cast(1.0, f32)\n"

    workdir = Path(tempfile.mkdtemp(prefix=f"coral-repro-{args.target}-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(body)
        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        print((build.stdout + build.stderr).strip())
        if build.returncode != 0:
            print("unexpected: `chelis build` failed before native C compile")
            return 1

        c_file = out_dir / "main.c"
        h_file = out_dir / "main.h"
        c_file.write_text(c_file.read_text().replace("double main", "double chelis_entry"))
        if h_file.exists():
            h_file.write_text(h_file.read_text().replace("double main", "double chelis_entry"))

        driver = workdir / "driver.c"
        driver.write_text(
            "#include <stdio.h>\n"
            "double chelis_entry__main(void);\n"
            "int main(){ printf(\"%.6f\\n\", chelis_entry__main()); return 0; }\n"
        )

        link = subprocess.run(
            native_link_cmd(workdir / "repro", [c_file, driver], out_dir),
            capture_output=True,
            text=True,
        )
        print(link.stderr.strip())
        if link.returncode == 0:
            print("unexpected: native compile/link succeeded; reproducer no longer matches the documented bug")
            return 1
        print("reproduced stripped multi-module bare-build failure")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
