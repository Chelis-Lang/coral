#!/usr/bin/env python3
"""Compile, link, and run Coral's float-NaN helpers through native C.

`chelis test` exercises the evaluator. This regression separately protects
the released C backend, where chelis#630 can otherwise make a tensor `neq`
mask evaluator-correct but IEEE-wrong after native lowering.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from repro_multimodule_bare_build import (
    CHELIS,
    MODULE_PRESETS,
    build_prefixed_modules,
    native_link_cmd,
)


def main() -> int:
    body = build_prefixed_modules(MODULE_PRESETS["frame"])
    body += """

def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def main() -> int64 = {
  values = to_tensor([nan_f32(), cast(-0.0, f32), cast(3.5, f32)])
  mask = to_list(frame__is_nan(values))
  mask_ok = and(index(mask, cast(0, int64)), and(not(index(mask, cast(1, int64))), not(index(mask, cast(2, int64)))))
  any_ok = frame__any_nan(values)
  count_ok = eq(frame__count_nan(values), cast(1, int64))
  keep = not(frame__is_nan(values))
  kept_indices = frame__mask_to_index_list(enumerate(to_list(keep)), [])
  kept_values = to_list(gather(values, to_tensor(kept_indices), cast(0, int32)))
  drop_ok = and(eq(len(kept_values), cast(2, int64)), and(eq(index(kept_values, cast(0, int64)), cast(-0.0, f32)), eq(index(kept_values, cast(1, int64)), cast(3.5, f32))))
  if and(mask_ok, and(any_ok, and(count_ok, drop_ok))) then cast(0, int64) else cast(1, int64)
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
        if build.returncode != 0:
            print((build.stdout + build.stderr).strip())
            print("native NaN regression: chelis build failed")
            return 1

        c_file = out_dir / "main.c"
        h_file = out_dir / "main.h"
        c_file.write_text(c_file.read_text().replace("int64_t main__main", "int64_t chelis_entry__main"))
        if h_file.exists():
            h_file.write_text(h_file.read_text().replace("int64_t main__main", "int64_t chelis_entry__main"))

        driver = workdir / "driver.c"
        driver.write_text(
            "#include <stdint.h>\n"
            "int64_t chelis_entry__main(void);\n"
            "int main(void){ return (int)chelis_entry__main(); }\n"
        )
        link = subprocess.run(
            native_link_cmd(workdir / "native-nan", [c_file, driver], out_dir),
            capture_output=True,
            text=True,
        )
        if link.returncode != 0:
            print(link.stderr.strip())
            print("native NaN regression: C compile/link failed")
            return 1

        run = subprocess.run([str(workdir / "native-nan")], capture_output=True, text=True, timeout=10)
        if run.returncode != 0:
            print(f"native NaN regression: helper verdict failed (rc={run.returncode})")
            return 1
        print("native NaN regression OK: mask/drop/count/any agree after compile-link-run")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
