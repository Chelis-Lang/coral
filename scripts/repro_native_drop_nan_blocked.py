#!/usr/bin/env python3
"""Mechanical probe for an invoked native `drop_nan` path.

Unlike the trivial-entry stripped-module smoke probe, this program constructs
a real Frame and invokes Coral.Frame.drop_nan. The pinned compiler must still
reject it. A successful build is FIX-DETECTED and requires de-narrowing this
limitation.

History of the boundary this probe measures:

- through chelis 0.18.4 the rejection was the branded chelis#941 / [05-UNS-1]
  recursive generic host call on `hamt__from_pairs_rec`;
- chelis 0.18.5 lands bounded memoized monomorphization (chelis#1158), the
  non-recursive inlining fix (chelis#1201), and recursive dimension-generic
  monomorphization (chelis#1216). `from_pairs_rec` no longer rejects, so the
  0.18.4 diagnostic is gone and the probe reported DRIFTED at that pin bump.
  The path now stops one layer later, at a match on the dim-generic `Column`
  whose applied dimension did not survive the `Option[Column[n]]` round trip
  out of the HAMT.

The 0.18.5 diagnostic carries no issue number of its own, unlike its sibling
`generic host call ... (chelis#1226; [05-UNS-1])` residue that
`repro_package_frame_build.py --target nrows` pins. chelis#1226 is the live
standing [05-UNS-5] authority for the class and is what `UPSTREAM_BUGS` cites;
chelis#1260 asks for this diagnostic to be branded the same way.

- chelis 0.18.9 drifts this diagnostic again. The invoked generic `drop_nan`
  Frame read is still build-lane-blocked, but the compiler now stops one step
  earlier, in host inference: the host type does not resolve before the
  code-generation boundary, reported as an unresolved host inference variable
  ([05-UNS-1]; now cited as chelis#730). Same boundary class, new wording; the
  `.expect` substring is re-cited to the stable phrase below (the volatile
  inference-variable id is excluded from the pin).

This probe drives the bare concatenated-module lane. The package lane -- the
one downstream projects actually use, and the one coral#26 reports against --
is measured separately by `repro_package_frame_build.py`, which reproduces the
same residue on the same `drop_nan` shape.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from repro_multimodule_bare_build import CHELIS, MODULE_PRESETS, build_prefixed_modules


# chelis 0.18.9 boundary diagnostic. The trailing inference-variable id is
# volatile, so the pin is the stable descriptive phrase (see the module
# docstring for the 0.18.6 -> 0.18.9 drift).
EXPECTED = "host type did not resolve before the code-generation boundary"


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
            print("FIX-DETECTED: production drop_nan now builds natively; de-narrow the UPSTREAM_BUGS entry")
            return 1
        if EXPECTED not in output:
            print(output.strip())
            print("native drop_nan blocker probe: failure diagnostic drifted")
            return 1
        print("expected blocked: production drop_nan still does not lower; the host type does not resolve before the code-generation boundary ([05-UNS-1]; chelis#730, drifted on 0.18.9 from the 0.18.6 dim-generic `Column` match, chelis#1226 class)")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
