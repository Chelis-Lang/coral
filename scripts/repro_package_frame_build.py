#!/usr/bin/env python3
"""Re-probe real `Coral.Frame` entrypoints through the Reef package lane.

Construction, `nrows`, and a match on a column returned from the HAMT build,
link, run, and agree with `chelis eval` on the pinned compiler. The `nrows`
path was blocked by chelis#1226 before 0.18.12; the match is a separate
positive guard and does not establish a chelis#1260 class-wide fix.
This lane imports `Coral.Frame`; the stripped module smokes have a separate
probe in `repro_multimodule_bare_build.py`.

Six Frame verbs formerly blocked by chelis#3153 have native/eval witnesses at
the 0.18.13 pin: `drop_nan`, `filter`, `head`, `slice`, `sort_by`, and
`with_column`. Each witness checks a selected output value or ordering, as well
as the resulting shape where relevant.
Six further verbs sharing the former boundary need their own witnesses before
claiming native coverage; see `docs/UPSTREAM_BUGS.md` and coral#26.

Two other verbs reject at DIFFERENT boundaries and are out of this entry:
`drop_column` at chelis#879 (general C-host function-value ABI, which its own
diagnostic cites as `unimplemented chelis#879`), and `describe` at chelis#1226.
Neither is chelis#3153; do not fold them into these targets.

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
from scripts.repro_multimodule_bare_build import (
    built_executable_path,
    observed_root,
)


CHELIS = resolve_chelis_bin()

# The module name must lowercase to the file stem, so the stem carries no
# separator: `Coral.ProbeFrameBuild` -> `coral.probeframebuild`.
ENTRY_STEM = "probeframebuild"
ENTRY_MODULE = "Coral.ProbeFrameBuild"

TWO_COLUMNS = (
    '[("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))'
    ', ("b", FloatCol(to_tensor([cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])))]'
)

TARGETS = {
    "construct": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, ncols)\n"
            f"def main() -> i64 = ncols(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": True,
        "expect_value": 2,
    },
    "nrows": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, nrows)\n"
            f"def main() -> i64 = nrows(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": True,
        "expect_value": 3,
    },
    "match_column": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_column)\n"
            "def main() -> i64 =\n"
            f'  match get_column(from_pairs({TWO_COLUMNS}), "a") with {{\n'
            "    | FloatCol(xs) => numel(xs)\n"
            "    | _ => cast(-1, i64)\n"
            "  }\n"
        ),
        "expect_build": True,
        "expect_value": 3,
    },
    "drop_nan": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, drop_nan, get_float_col, nrows)\n"
            "def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))\n"
            'def main() -> i64 = {\n'
            '  kept = drop_nan(from_pairs([("value", FloatCol(to_tensor([nan_f32(), cast(2.0, f32)])))]), "value")\n'
            '  values = to_list(get_float_col(kept, "value"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(0, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 102,
    },
    "filter": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, filter, get_float_col, nrows)\n"
            "def main() -> i64 = {\n"
            f"  kept = filter(from_pairs({TWO_COLUMNS}), to_tensor([true, false, true]))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 203,
    },
    "head": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, head, nrows)\n"
            "def main() -> i64 = {\n"
            f"  kept = head(from_pairs({TWO_COLUMNS}), cast(2, i64))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 202,
    },
    "slice": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, nrows, slice)\n"
            "def main() -> i64 = {\n"
            f"  kept = slice(from_pairs({TWO_COLUMNS}), cast(1, i64), cast(3, i64))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(0, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 202,
    },
    "sort_by": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, sort_by)\n"
            "def main() -> i64 = {\n"
            '  unsorted = from_pairs([("a", FloatCol(to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)]))), ("b", FloatCol(to_tensor([cast(30.0, f32), cast(10.0, f32), cast(20.0, f32)])))])\n'
            '  ordered = sort_by(unsorted, "a", true)\n'
            '  values = to_list(get_float_col(ordered, "b"))\n'
            '  add(mul(cast(index(values, cast(0, i64)), i64), cast(100, i64)), add(mul(cast(index(values, cast(1, i64)), i64), cast(10, i64)), cast(index(values, cast(2, i64)), i64)))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 1230,
    },
    "with_column": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, with_column, ncols)\n"
            "def main() -> i64 = {\n"
            f'  result = with_column(from_pairs({TWO_COLUMNS}), "c", FloatCol(to_tensor([cast(7.0, f32), cast(8.0, f32), cast(9.0, f32)])))\n'
            '  values = to_list(get_float_col(result, "c"))\n'
            '  add(mul(ncols(result), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 308,
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
            print(f"{name}: still blocked at the expected boundary ({spec['blocker']})")
            return 0

        if build.returncode != 0:
            print(output)
            print(f"{name}: chelis build failed")
            return 1

        evaluated = _eval_value(entry)
        if evaluated is None:
            print(f"{name}: chelis eval did not produce an integer value")
            return 1

        binary = built_executable_path(output)

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"{name}: compiled program exited rc={run.returncode}")
            return 1

        native = observed_root(run.stdout, "main")
        if native is None or int(native) != evaluated:
            print(run.stdout.strip())
            print(f"{name}: native observed {native!r}, eval returned {evaluated}")
            return 1
        if int(native) != spec["expect_value"]:
            print(f"{name}: expected {spec['expect_value']}, got {native}")
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
