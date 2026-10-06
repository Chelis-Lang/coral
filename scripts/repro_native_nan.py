#!/usr/bin/env python3
"""Compile, link, and run Coral's float-NaN helpers through native C.

`chelis test` exercises the evaluator. This regression separately protects
the released C backend, where chelis#630 can otherwise make a tensor `neq`
mask evaluator-correct but IEEE-wrong after native lowering.

chelis 0.18.6 emits its own `main` for the C target and observes every
effect-free nullary definition, so the verdict is read off the compiled
program's `main = <value>` observation line rather than its exit status,
which the emitted entry always sets to zero.

Scope: this probe extracts Coral's own frame NaN helpers and their dependencies
instead of flat-pasting `MODULE_PRESETS["frame"]`. The full preset remains a
separate package-dependent re-probe (chelis#2097; see docs/UPSTREAM_BUGS.md).
The 0.18.11 pin makes tensor `neq` IEEE-correct for the tested NaN lanes, so
`is_nan` now uses it directly. This probe executes the production mask,
drop-core, count and any paths after native compile-link-run.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from repro_multimodule_bare_build import (
    CHELIS,
    REPO,
    built_executable_path,
    extract_named_defs,
    observed_root,
    prefix_defs,
    strip_module_surface,
)

# Coral's own frame NaN surface and its genuine in-module dependencies. Only
# these defs need to lower through the C backend to guard chelis#630; nothing
# here reaches the Nautilus special/distributions chain.
FRAME_NAN_DEFS = ["zero_i64", "one_i64", "is_nan", "any_nan", "count_nan", "mask_to_index_list"]


def _frame_nan_slice() -> str:
    frame_src = strip_module_surface((REPO / "src" / "frame.ch").read_text())
    slice_src = extract_named_defs(frame_src, FRAME_NAN_DEFS)
    prefixed, _ = prefix_defs(slice_src, "frame__")
    return prefixed


def main() -> int:
    body = _frame_nan_slice()
    body += """

def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def main() -> i64 = {
  values = to_tensor([nan_f32(), cast(-0.0, f32), cast(3.5, f32)])
  mask = to_list(frame__is_nan(values))
  mask_ok = and(index(mask, cast(0, i64)), and(not(index(mask, cast(1, i64))), not(index(mask, cast(2, i64)))))
  any_ok = frame__any_nan(values)
  count_ok = eq(frame__count_nan(values), cast(1, i64))
  keep = not(frame__is_nan(values))
  kept_indices = frame__mask_to_index_list(enumerate(to_list(keep)), [])
  kept_values = to_list(gather(values, to_tensor(kept_indices), cast(0, i32)))
  drop_ok = and(eq(len(kept_values), cast(2, i64)), and(eq(index(kept_values, cast(0, i64)), cast(-0.0, f32)), eq(index(kept_values, cast(1, i64)), cast(3.5, f32))))
  if and(mask_ok, and(any_ok, and(count_ok, drop_ok))) then cast(0, i64) else cast(1, i64)
}
"""

    workdir = Path(tempfile.mkdtemp(prefix="coral-native-nan-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(body)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(main_ch)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print((fmt.stdout + fmt.stderr).strip())
            print("native NaN regression: synthesized module did not format")
            return 1

        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        build_output = (build.stdout or "") + (build.stderr or "")
        if build.returncode != 0:
            print(build_output.strip())
            print("native NaN regression: chelis build failed")
            return 1

        binary = built_executable_path(build_output)

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"native NaN regression: compiled program exited rc={run.returncode}")
            return 1

        verdict = observed_root(run.stdout, "main")
        if verdict != "0":
            print(run.stdout.strip())
            print(f"native NaN regression: helper verdict observed as {verdict!r}, expected '0'")
            return 1
        print("native NaN regression OK: mask/drop/count/any agree after compile-link-run")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
