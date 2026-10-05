# Upstream blocker probes

There are no checker or evaluator blockers that `chelis test --expect blocked`
can probe at this pin. The gather-axis rejection is a language rule covered by
`tests_neg/frame/gather_axis_helper_neg.ch`.

| Upstream issue | Re-probe | Why this harness cannot express it |
|---|---|---|
| chelis#2097 | `scripts/repro_multimodule_bare_build.py` and `scripts/repro_native_drop_nan_blocked.py` | Native build of stripped source |
| chelis#3169, chelis#879 | Build `describe` and `drop_column` entries separately; see `docs/UPSTREAM_BUGS.md` | Native package build |
| chelis#850 | Check, build, and run a `Std.Io.Parquet` call; see `docs/UPSTREAM_BUGS.md` | Unsupported runtime stub |
