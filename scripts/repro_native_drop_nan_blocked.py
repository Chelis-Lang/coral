#!/usr/bin/env python3
"""Probe the stripped-source native `drop_nan` boundary.

The probe constructs a Frame and invokes Coral.Frame.drop_nan. Stripping and
concatenating the modules reaches the chelis#2097 ownership-signature
rejection. A successful build is FIX-DETECTED and calls for de-narrowing this
limitation. The Reef package lane is measured separately by
`repro_package_frame_build.py`; its `drop_nan` case builds, runs, and agrees
with evaluation against the published dependency.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from repro_multimodule_bare_build import CHELIS, MODULE_PRESETS, build_prefixed_modules


# chelis 0.18.13 boundary diagnostic. The local function id is volatile.
EXPECTED = "does not match ownership signature"


def main() -> int:
    body = build_prefixed_modules(MODULE_PRESETS["frame"])
    body += """

def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def main() -> i64 = {
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
            print("FIX-DETECTED: production drop_nan now builds natively; de-narrow the UPSTREAM_BUGS entry")
            return 1
        if EXPECTED not in output:
            print(output.strip())
            print("native drop_nan blocker probe: failure diagnostic drifted")
            return 1
        print("expected blocked: stripped production drop_nan still does not lower at the chelis#2097 ownership-signature boundary")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
