# Upstream blocker probes

No evaluator blocker probes remain in this directory. The 2,000-row JSON
reader witness is ordinary coverage in `tests/io.ch`; Chelis 0.19.2 passes it
with a locally published Nautilus candidate. That package smoke is exploratory
until the compatible Nautilus release is published and the Coral package gates
run against its authenticated artifact.

The gather-axis rejection is not an upstream blocker but a language rule,
covered by `tests_neg/frame/gather_axis_helper_neg.ch`.

The remaining upstream limitations cannot be expressed in this harness:

| Upstream issue | Re-probe | Why this harness cannot express it |
|---|---|---|
| chelis#2097 | `scripts/repro_multimodule_bare_build.py` and `scripts/repro_native_drop_nan_blocked.py` | Native build of stripped source |
| chelis#3169, chelis#879 | Build `describe` and `drop_column` entries separately; see `docs/UPSTREAM_BUGS.md` | Native package build |
| chelis#850 | Check, build, and run a `Std.Io.Parquet` call; see `docs/UPSTREAM_BUGS.md` | Unsupported runtime stub |
