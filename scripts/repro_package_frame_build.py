#!/usr/bin/env python3
"""Re-probe real `Coral.Frame` entrypoints through the Reef package lane.

Construction, `nrows`, and a match on a column returned from the HAMT build,
link, run, and agree with `chelis eval` on the pinned compiler. The `nrows`
path was blocked by chelis#1226 before 0.18.12; the match is a separate
positive guard and does not establish a chelis#1260 class-wide fix.
This lane imports `Coral.Frame`; the stripped module smokes have a separate
probe in `repro_multimodule_bare_build.py`.

Six Frame verbs are pinned here as expected failures on chelis#3153, so an
upstream fix is detected rather than landing unnoticed: `drop_nan`, `filter`,
`head`, `slice`, `sort_by`, `with_column`. chelis#3153 is one defect -- a bare
`[]` accumulator of a recursive dimension-generic function whose element type is
a dimension-generic ADT, here `(string, Column[n])`.

**Twelve exported verbs sit on that boundary, not six.** `tail`, `mutate`,
`concat`, `drop_nan_col`, `fill_nan_col`, and `key_values` reject identically
and are knowingly unpinned (`mutate` delegates to `with_column`,
`drop_nan_col` to `filter`). The six pins suffice to detect a #3153 fix;
see `docs/UPSTREAM_BUGS.md`, and do not read this target list as the surface.

The compiler prints `chelis#730` in this diagnostic because that citation is
hard-coded into the format string in `crates/chelis-ir/src/host.rs`; #730 is a
tracking hub, so the printed number names the plan rather than the defect.
Track #3153.

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
    compiled_binary_path,
    emitted_compile_cmd,
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

# Every expected failure below is one upstream defect, so the diagnostic and the
# blocker are named once. A drift in either is a real signal, not a typo to fix
# locally: see this module's docstring for why the printed citation is the hub.
HOST_TYPE_UNRESOLVED = "host type did not resolve before the code-generation boundary"
BLOCKER = "chelis#3153"

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
            "import Coral.Frame (FloatCol, from_pairs, drop_nan, nrows)\n"
            "def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))\n"
            'def main() -> i64 = nrows(drop_nan(from_pairs([("value", FloatCol(to_tensor([nan_f32(), cast(2.0, f32)])))]), "value"))\n'
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
    },
    "filter": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, filter, nrows)\n"
            f"def main() -> i64 = nrows(filter(from_pairs({TWO_COLUMNS}), to_tensor([true, false, true])))\n"
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
    },
    "head": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, head, nrows)\n"
            f"def main() -> i64 = nrows(head(from_pairs({TWO_COLUMNS}), cast(2, i64)))\n"
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
    },
    "slice": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, slice, nrows)\n"
            f"def main() -> i64 = nrows(slice(from_pairs({TWO_COLUMNS}), cast(0, i64), cast(2, i64)))\n"
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
    },
    "sort_by": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, sort_by, ncols)\n"
            f'def main() -> i64 = ncols(sort_by(from_pairs({TWO_COLUMNS}), "a", true))\n'
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
    },
    "with_column": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, with_column, ncols)\n"
            f"def main() -> i64 = ncols(with_column(from_pairs({TWO_COLUMNS}), \"c\","
            " FloatCol(to_tensor([cast(7.0, f32), cast(8.0, f32), cast(9.0, f32)]))))\n"
        ),
        "expect_build": False,
        "expect_diagnostic": HOST_TYPE_UNRESOLVED,
        "blocker": BLOCKER,
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

        command = emitted_compile_cmd(output)
        binary = compiled_binary_path(command)
        link = subprocess.run(command, capture_output=True, text=True, timeout=900)
        if link.returncode != 0:
            print(link.stderr.strip())
            print(f"{name}: C compile/link failed")
            return 1

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
