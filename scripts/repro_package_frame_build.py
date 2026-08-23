#!/usr/bin/env python3
"""Compile, link, and run a real `Coral.Frame` entrypoint through the package lane.

This is the lane coral#26 reports against: a reef project that imports
`Coral.Frame` and runs `chelis build`. It is distinct from
`repro_multimodule_bare_build.py`, which concatenates stripped and
symbol-prefixed modules into one bare file and therefore does not exercise
package module resolution at all.

Two claims are pinned here, both re-measured at every pin bump:

`--target construct` is the **positive** de-narrowing. Through chelis 0.18.4 a
`Frame` could not even be constructed in this lane: `from_pairs` reaches
`Coral.Internal.Hamt.from_pairs_rec`, and a recursive generic host call was
rejected at the branded chelis#941 / [05-UNS-1] boundary. chelis 0.18.5 lands
bounded memoized monomorphization (chelis#1158), the non-recursive inlining
fix (chelis#1201), and recursive dimension-generic monomorphization
(chelis#1216), so construction plus `ncols` now builds, links, runs, and
agrees with `chelis eval`.

`--target nrows` is the **expected-failure** probe for what is still blocked.
`nrows` reads a column back out of the HAMT through
`hamt_get[a](Hamt[a], string) -> Option[a]` instantiated at `a = Column[n]`,
and the dimension does not survive that round trip: `column_len` arrives at
lowering with no concrete checked type application. That residue is the open
chelis#1226 class. A clean build here is FIX-DETECTED and de-narrows the
`UPSTREAM_BUGS` entry.

Exit codes:
- 0: every selected target matched its expected outcome
- 1: an outcome changed (either lane) or the probe could not run
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
from scripts.repro_multimodule_bare_build import native_link_cmd


CHELIS = resolve_chelis_bin()

# The module name must lowercase to the file stem, so the stem carries no
# separator: `Coral.ProbeFrameBuild` -> `coral.probeframebuild`.
ENTRY_STEM = "probeframebuild"
ENTRY_MODULE = "Coral.ProbeFrameBuild"
ENTRY_SYMBOL = "pkg__coral__Coral__ProbeFrameBuild__main"

TWO_COLUMNS = (
    '[("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))'
    ', ("b", FloatCol(to_tensor([cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])))]'
)

TARGETS = {
    "construct": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, ncols)\n"
            f"def main() -> int64 = ncols(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": True,
        "expect_value": 2,
    },
    "nrows": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, nrows)\n"
            f"def main() -> int64 = nrows(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": False,
        "expect_diagnostic": (
            "generic host call `pkg__coral__Coral__Frame__column_len` has no "
            "concrete checked type application to specialize (chelis#1226; [05-UNS-1])"
        ),
    },
}


def _eval_value(entry: Path) -> int | None:
    result = subprocess.run(
        [CHELIS, "eval", "--file", str(entry)], capture_output=True, text=True, timeout=300
    )
    if result.returncode != 0:
        print((result.stdout + result.stderr).strip())
        return None
    match = re.search(r"^main = (-?\d+)$", result.stdout, re.MULTILINE)
    return int(match.group(1)) if match else None


def _run_target(name: str, spec: dict) -> int:
    entry = REPO / "src" / f"{ENTRY_STEM}.ch"
    if entry.exists():
        print(f"{name}: {entry} already exists; refusing to overwrite")
        return 1
    workdir = Path(tempfile.mkdtemp(prefix=f"coral-package-frame-{name}-"))
    try:
        entry.write_text(spec["source"])
        out_dir = workdir / "out"
        build = subprocess.run(
            [CHELIS, "build", str(entry), "--output", str(out_dir)],
            capture_output=True,
            text=True,
            timeout=900,
        )
        output = (build.stdout + build.stderr).strip()

        if not spec["expect_build"]:
            if build.returncode == 0:
                print(output)
                print(f"{name}: FIX-DETECTED -- the build lane now accepts this entry")
                return 1
            if spec["expect_diagnostic"] not in output:
                print(output)
                print(f"{name}: failure diagnostic drifted")
                return 1
            print(f"{name}: still blocked at the expected boundary (chelis#1226)")
            return 0

        if build.returncode != 0:
            print(output)
            print(f"{name}: chelis build failed")
            return 1

        evaluated = _eval_value(entry)
        if evaluated is None:
            print(f"{name}: chelis eval did not produce an integer value")
            return 1

        driver = workdir / "driver.c"
        driver.write_text(
            "#include <stdint.h>\n"
            f"int64_t {ENTRY_SYMBOL}(void);\n"
            f"int main(void){{ return (int){ENTRY_SYMBOL}(); }}\n"
        )
        binary = workdir / f"package-frame-{name}"
        link = subprocess.run(
            native_link_cmd(binary, [out_dir / f"{ENTRY_STEM}.c", driver], out_dir),
            capture_output=True,
            text=True,
            timeout=900,
        )
        if link.returncode != 0:
            print(link.stderr.strip())
            print(f"{name}: C compile/link failed")
            return 1

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != evaluated:
            print(f"{name}: native returned {run.returncode}, eval returned {evaluated}")
            return 1
        if run.returncode != spec["expect_value"]:
            print(f"{name}: expected {spec['expect_value']}, got {run.returncode}")
            return 1
        print(f"{name}: build, link, and run OK -- native and eval both {evaluated}")
        return 0
    finally:
        entry.unlink(missing_ok=True)
        shutil.rmtree(workdir, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=[*sorted(TARGETS), "all"], default="all")
    args = parser.parse_args()
    names = sorted(TARGETS) if args.target == "all" else [args.target]
    return max(_run_target(name, TARGETS[name]) for name in names)


if __name__ == "__main__":
    raise SystemExit(main())
