#!/usr/bin/env python3
"""Compare evaluator/native tensor inequality on NaN, signed zero and finite data.

Regression for the native IEEE residue of chelis#630, fixed at the 0.18.11
pin. Both lanes must report bitmask 1: only NaN differs from itself.
Exit nonzero on a wrong answer, lane disagreement or a failed probe.
"""
from __future__ import annotations

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

# Lane bits for `[NaN, -0.0, 3.5]` compared against itself: bit 0 is the NaN
# lane, bit 1 the signed-zero lane, bit 2 the ordinary lane. IEEE-754 says
# only the NaN lane is unequal to itself, so 1 is correct and 0 is the
# two-ordered-comparisons answer.
EVAL_EXPECTED = 1

SOURCE = """def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def bit_of(mask: List[bool], i: i64) -> i64 = if index(mask, i) then cast(1, i64) else cast(0, i64)
def main() -> i64 = {
  values = to_tensor([nan_f32(), cast(-0.0, f32), cast(3.5, f32)])
  mask = to_list(neq(copy(values), values))
  add(bit_of(mask, cast(0, i64)), add(mul(bit_of(mask, cast(1, i64)), cast(2, i64)), mul(bit_of(mask, cast(2, i64)), cast(4, i64))))
}
"""


def main() -> int:
    workdir = Path(tempfile.mkdtemp(prefix="coral-native-neq-"))
    try:
        entry = workdir / "probe.ch"
        entry.write_text(SOURCE)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(entry)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print((fmt.stdout + fmt.stderr).strip())
            print("native neq regression: source did not format")
            return 1

        evaluated = subprocess.run(
            [CHELIS, "eval", "--file", str(entry)],
            capture_output=True,
            text=True,
            timeout=300,
        )
        if evaluated.returncode != 0:
            print((evaluated.stdout + evaluated.stderr).strip())
            print("native neq regression: chelis eval failed")
            return 1
        eval_match = re.search(r"^main = (-?\d+)$", evaluated.stdout, re.MULTILINE)
        if eval_match is None:
            print(evaluated.stdout.strip())
            print("native neq regression: chelis eval produced no integer entry value")
            return 1
        eval_bits = int(eval_match.group(1))

        build = subprocess.run(
            [CHELIS, "build", str(entry), "-o", str(workdir / "out")],
            capture_output=True,
            text=True,
            timeout=900,
        )
        build_output = (build.stdout or "") + (build.stderr or "")
        if build.returncode != 0:
            print(build_output.strip())
            print("native neq regression: chelis build failed")
            return 1

        binary = built_executable_path(build_output)

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"native neq regression: compiled program exited rc={run.returncode}")
            return 1
        native = observed_root(run.stdout, "main")
        if native is None:
            print(run.stdout.strip())
            print("native neq regression: compiled program observed no entry value")
            return 1
        native_bits = int(native)

        if eval_bits != EVAL_EXPECTED:
            print(f"native neq regression: eval lane drifted (got {eval_bits}, expected {EVAL_EXPECTED})")
            return 1
        if native_bits != eval_bits:
            print(
                f"native neq regression: lane mismatch (eval {eval_bits}, "
                f"native {native_bits}; expected {EVAL_EXPECTED} in both)"
            )
            return 1

        print(
            "native tensor neq regression OK: NaN is unequal; signed zero "
            f"and finite self-comparisons are equal (eval {eval_bits}, native {native_bits})"
        )
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
