#!/usr/bin/env python3
"""Validate the stripped multi-module bare-build end-to-end on the current compiler.

This is an upstream-triage helper, not a CI gate.

It concatenates stripped Coral modules into one temporary file, prefixes
function names to avoid obvious user-space symbol collisions, runs
`chelis build`, links the generated C with a tiny driver, and executes
the resulting binary.

Expected current outcome on `chelis v0.1.21`:
- `chelis build` exits rc=0 with no panic in output
- native C compile/link succeeds
- binary executes and returns the expected value

History:
- v0.1.15–v0.1.17: invalid-C type-collapse caused link failure
- v0.1.18: invalid-C fixed; Phase 0e RISC DAG panic remained (non-fatal, rc=0)
- v0.1.19: Phase 0e panic fixed; build, link, and run are now fully clean

Exit codes:
- 0: build, link, and run all succeeded cleanly
- 1: unexpected failure or regression detected
"""
from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()


def _nautilus_stats_src() -> str:
    """Extract stats.ch from the Nautilus package in the local reef registry."""
    reef_toml = REPO / "reef.toml"
    with open(reef_toml, "rb") as f:
        deps = tomllib.load(f).get("dependencies", {})
    nautilus_version = deps.get("nautilus", {}).get("version", "")
    if not nautilus_version:
        raise RuntimeError("nautilus dependency not found in reef.toml")
    tarball = Path.home() / ".chelis" / "reef" / "packages" / "nautilus" / nautilus_version / f"nautilus-{nautilus_version}.tar.zst"
    if not tarball.exists():
        raise RuntimeError(f"nautilus {nautilus_version} not found in local reef registry: {tarball}")
    with tarfile.open(tarball, "r:*") as tf:
        member = tf.getmember("src/stats.ch")
        return tf.extractfile(member).read().decode()


MODULE_PRESETS = {
    "frame": [
        ("src/internal/hamt.ch", "hamt__"),
        (None, "stats__"),  # resolved from reef registry at runtime
        ("src/frame.ch", "frame__"),
    ],
    "groupby": [
        ("src/internal/hamt.ch", "hamt__"),
        (None, "stats__"),
        ("src/frame.ch", "frame__"),
        ("src/groupby.ch", "groupby__"),
    ],
    "join": [
        ("src/internal/hamt.ch", "hamt__"),
        (None, "stats__"),
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


def build_prefixed_modules(specs: list[tuple[str | None, str]]) -> str:
    accumulated: dict[str, str] = {}
    parts: list[str] = []
    for rel_path, prefix in specs:
        raw = _nautilus_stats_src() if rel_path is None else (REPO / rel_path).read_text()
        src = strip_module_surface(raw)
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

        build_output = (build.stdout or "") + (build.stderr or "")
        PHASE0E_PANIC = "`if` is not representable in the Phase 0e RISC DAG"
        if PHASE0E_PANIC in build_output:
            print("regression: Phase 0e RISC DAG panic reappeared in chelis build output")
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
        if link.returncode != 0:
            print(link.stderr.strip())
            print("regression: native compile/link failed (invalid-C regression?)")
            return 1

        run = subprocess.run([str(workdir / "repro")], capture_output=True, text=True, timeout=10)
        if run.returncode != 0:
            print(f"regression: binary exited with rc={run.returncode}")
            return 1

        print(f"stripped multi-module bare-build OK: build clean, link OK, run OK (output={run.stdout.strip()!r})")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
