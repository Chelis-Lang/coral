#!/usr/bin/env python3
"""Mechanical probe for the surviving native IEEE `neq` residue of chelis#630.

`src/frame.ch` keeps an O(n) scalar host-map for float NaN masks instead of
calling tensor `neq` directly, because the generated C derives `neq` from two
ordered `<` comparisons and therefore reports `false` for a NaN lane that the
evaluator reports `true`. That narrowing needs a live trigger: without one it
would outlive the bug.

`tests_blocked/types/tensor_neq_borrowed.ch` used to be that trigger, but it
pinned the *other* chelis#630 residue -- borrowed/borrowed operands inferring
`tensor[n, f32]` -- which chelis 0.18.6 fixed. That probe is now the executed
regression `tests/types.ch`, so this script takes over the blocked half.

The divergence is a wrong runtime answer in one lane, not a rejected program,
so it cannot live under `tests_blocked/`: nothing compile-fails. The probe
compares the two lanes on the same source instead, and a match is
FIX-DETECTED.

Exit codes:
- 0: the documented divergence is still present (expected)
- 1: the lanes agree (de-narrow `Coral.Frame.is_nan`) or the probe could not run
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
    compiled_binary_path,
    emitted_compile_cmd,
    observed_root,
)

CHELIS = resolve_chelis_bin()

# Lane bits for `[NaN, -0.0, 3.5]` compared against itself: bit 0 is the NaN
# lane, bit 1 the signed-zero lane, bit 2 the ordinary lane. IEEE-754 says
# only the NaN lane is unequal to itself, so 1 is correct and 0 is the
# two-ordered-comparisons answer.
EVAL_EXPECTED = 1
NATIVE_EXPECTED = 0

SOURCE = """def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def bit_of(mask: List[bool], i: int64) -> int64 = if index(mask, i) then cast(1, int64) else cast(0, int64)
def main() -> int64 = {
  values = to_tensor([nan_f32(), cast(-0.0, f32), cast(3.5, f32)])
  mask = to_list(neq(copy(values), values))
  add(bit_of(mask, cast(0, int64)), add(mul(bit_of(mask, cast(1, int64)), cast(2, int64)), mul(bit_of(mask, cast(2, int64)), cast(4, int64))))
}
"""


def main() -> int:
    workdir = Path(tempfile.mkdtemp(prefix="coral-native-neq-blocked-"))
    try:
        entry = workdir / "probe.ch"
        entry.write_text(SOURCE)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(entry)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print((fmt.stdout + fmt.stderr).strip())
            print("native neq blocker probe: source did not format")
            return 1

        evaluated = subprocess.run(
            [CHELIS, "eval", "--file", str(entry)], capture_output=True, text=True, timeout=300
        )
        if evaluated.returncode != 0:
            print((evaluated.stdout + evaluated.stderr).strip())
            print("native neq blocker probe: chelis eval failed")
            return 1
        eval_match = re.search(r"^main = (-?\d+)$", evaluated.stdout, re.MULTILINE)
        if eval_match is None:
            print(evaluated.stdout.strip())
            print("native neq blocker probe: chelis eval produced no integer entry value")
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
            print("native neq blocker probe: chelis build failed")
            return 1

        command = emitted_compile_cmd(build_output)
        binary = compiled_binary_path(command)
        link = subprocess.run(command, capture_output=True, text=True, timeout=900)
        if link.returncode != 0:
            print(link.stderr.strip())
            print("native neq blocker probe: C compile/link failed")
            return 1

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"native neq blocker probe: compiled program exited rc={run.returncode}")
            return 1
        native = observed_root(run.stdout, "main")
        if native is None:
            print(run.stdout.strip())
            print("native neq blocker probe: compiled program observed no entry value")
            return 1
        native_bits = int(native)

        if eval_bits != EVAL_EXPECTED:
            print(f"native neq blocker probe: eval lane drifted (got {eval_bits}, expected {EVAL_EXPECTED})")
            return 1
        if native_bits == eval_bits:
            print(
                "FIX-DETECTED: native tensor `neq` now agrees with the evaluator on the NaN "
                "lane; de-narrow Coral.Frame.is_nan's scalar host-map and archive chelis#630"
            )
            return 1
        if native_bits != NATIVE_EXPECTED:
            print(
                f"native neq blocker probe: native lane drifted (got {native_bits}, "
                f"expected {NATIVE_EXPECTED}); re-measure chelis#630 before trusting the narrowing"
            )
            return 1

        print(
            "expected blocked: native tensor `neq` still reports the NaN lane equal "
            f"(eval {eval_bits}, native {native_bits}; chelis#630)"
        )
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
