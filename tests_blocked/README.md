# Upstream blocker probes

No evaluator blocker probes remain in this directory. The 2,000-row JSON
reader witness is ordinary coverage in `tests/io.ch`; it passes against the
published Chelis 0.21.0 and Nautilus 0.7.57 package graph. Coral 0.7.51
builds from those published artifacts.

The gather-axis rejection is not an upstream blocker but a language rule,
covered by `tests_neg/frame/gather_axis_helper_neg.ch`.

The remaining upstream limitations cannot be expressed in this harness:

| Upstream issue | Re-probe | Why this harness cannot express it |
|---|---|---|
| chelis#879 | `scripts/repro_multimodule_bare_build.py` and `scripts/repro_native_drop_nan_blocked.py` | Native build of stripped source |
| chelis#879 | `scripts/repro_package_frame_build.py --target drop_column`; see `docs/UPSTREAM_BUGS.md` | Native package build |
| chelis#850 | Check, build, and run a `Std.Io.Parquet` call; see `docs/UPSTREAM_BUGS.md` | Unsupported runtime stub |
