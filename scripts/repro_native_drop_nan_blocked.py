#!/usr/bin/env python3
"""Mechanical chelis#941 probe for an invoked native `drop_nan` path.

Unlike the trivial-entry stripped-module smoke probe, this program constructs
a real Frame and invokes Coral.Frame.drop_nan. The pinned compiler must reject
the recursive generic HAMT specialization with its branded diagnostic. A
successful build is FIX-DETECTED and requires de-narrowing this limitation.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from repro_multimodule_bare_build import CHELIS, MODULE_PRESETS, build_prefixed_modules


EXPECTED = "recursive generic host call `hamt__from_pairs_rec` requires bounded monomorphized symbols (chelis#941; [05-UNS-1])"


def main() -> int:
    body = build_prefixed_modules(MODULE_PRESETS["frame"])
    body += """

def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def main() -> int64 = {
  values = to_tensor([nan_f32(), cast(-0.0, f32), cast(3.5, f32)])
  frame = frame__from_pairs([("value", FloatCol(values))])
  kept = frame__drop_nan(frame, "value")
  frame__nrows(kept)
}
"""

    workdir = Path(tempfile.mkdtemp(prefix="coral-native-drop-blocked-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(body)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(main_ch)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print((fmt.stdout + fmt.stderr).strip())
            print("native drop_nan blocker probe: synthesized module did not format")
            return 1

        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        output = (build.stdout or "") + (build.stderr or "")
        if build.returncode == 0:
            print("FIX-DETECTED: production drop_nan now builds natively; de-narrow chelis#941")
            return 1
        if EXPECTED not in output:
            print(output.strip())
            print("native drop_nan blocker probe: failure diagnostic drifted")
            return 1
        print("expected blocked: production drop_nan reaches chelis#941 recursive generic HAMT boundary")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
