# Coral

Typed dataframes shell for the
[Chelis](https://github.com/Chelis-Lang/chelis) programming language.
Ships as a reef package under the `Coral` module prefix.

Numeric columns are tensors, so dataframe pipelines compose with the
Chelis tensor DAG instead of sitting beside it. That gives Coral three
distinctive properties:

- GPU-friendly numeric columns
- typed column accessors
- dataframe pipelines that can participate in AD-oriented workloads

Coral uses pandas as its behavioral reference, with explicit documented
deltas where the Chelis runtime or first-release scope is narrower.

Today that reference is backed in two different ways:

- checked-in pandas goldens for the first validated `Frame` slice
- checked-in pandas goldens for the current `GroupBy` aggregation slice
- checked-in pandas / Coral-format goldens for the current `IO` slice
- checked-in pandas goldens for the current `Join` slice
- checked-in pandas goldens plus a runtime build/link/execute harness for the
  current `Window` slice

For the alpha implementation, frame metadata is required to use a
persistent HAMT-backed column store from day one. That is not treated as
an optional later optimization: structural sharing across chained frame
operations is part of making AD-through-dataframes viable at realistic
scale.

## Modules

| Module | What it provides |
|---|---|
| `Coral.Core` | package version/smoke anchor and top-level shared metadata |
| `Coral.Frame` | typed columns, frame construction, accessors, filtering, sorting, mutation, NaN helpers, concat, `describe` |
| `Coral.GroupBy` | single-key grouping plus `sum` / `mean` / `count` / `min` / `max` aggregations |
| `Coral.Join` | `inner_join` and `left_join` |
| `Coral.Window` | rolling sum/mean/std/min/max and EWM |
| `Coral.Io` | CSV and JSON read/write |
| `Coral.Reshape` | `pivot`, `melt`, `stack`, `unstack` |
| `Coral.AsOf` | sorted as-of lookup and join helpers over `i64` keys with `f32` values |

## Toolchain

This checkout targets the published `chelis v0.18.1` release in `reef.toml`:

```toml
compiler = "=0.18.1"
```

The v0.18.1 tag resolves to commit
`c8db387d06d538ce8039ac37645a43def48373c9`. Its official glibc-2.31 archive
SHA-256 is `88a1a53b47b7168e4df614e66a6d9313176174b1dc3a25a43db5f73a3ee8f0cd`;
the extracted binary SHA-256 is
`0d7a46262b4ba2975702d5ed2def5d54b79b5d68258602da59069b6715cc690b`.

## Build

A Coral 0.7.35 checkout uses `chelis-std 0.4.0` and the published Nautilus
0.7.38 release. That release resolves to commit
`6b4c10f19a2cd120c08ba3c7d9cb746c161106ec`; its CHB and archive SHA-256 are
`cad8bd996ddeddb25f698496a394ab45388a120f9b870e7832cb5b87b5935740`
and `39a81b079dfae2a0aa907574954eeb48631757fb5fb1d0940def0c8a98adf4f6`.
Validation consumes official Chelis and Nautilus assets in dependency order.

With the selected release compiler on `PATH`, or `CHELIS_BIN` pointed at that
exact binary:

```sh
chelis check src/frame.ch
chelis reef build
chelis test tests/ --jobs auto         # internal correctness (Chelis-native)
chelis test tests/ --jobs 1            # serial fallback for debugging
chelis test tests_neg/ --expect neg    # negative contracts
chelis test tests_blocked/ --expect blocked # upstream de-narrowing probes
python scripts/repro_native_nan.py     # positive native mask/drop-core lane
python scripts/repro_native_drop_nan_blocked.py # expected chelis#941 boundary
uv run --python 3.11 --no-project python scripts/run_static_checks.py
CHELIS_BIN=/path/to/chelis uv run --python 3.11 --no-project python scripts/run_skill_checks.py
CHELIS_BIN=/path/to/chelis uv run --python 3.11 --no-project python scripts/validate_book_examples.py
CHELIS_BIN=/path/to/chelis uv run --project parity --frozen python parity/run_parity.py --strict
```

## Current deltas

- `Frame` column storage uses a persistent HAMT, not a
  plain `Dict`
- `Window` and `Frame` both have a runtime-executed pandas parity lane
- `IO` supports bool inference/read and bool CSV/JSON write formatting in the
  compile-checked slice
- `sort_by` covers int, float, bool, and string columns
- `outer_join` is implemented and golden-validated
- `Coral.Reshape` ships `pivot`, `melt`, `stack`, and `unstack`
- Parquet I/O is upstream-blocked (see `docs/UPSTREAM_BUGS.md`)
- native compilation of an invoked full `drop_nan(Frame, ...)` remains
  upstream-blocked by recursive generic HAMT specialization (chelis#941); the
  positive native lane covers the production mask/drop core
- null semantics are intentionally narrower than pandas in the first pass
- the prior `chelis test` evaluator gap is fully resolved as of chelis
  v0.3.1: tensor-tensor `eq`/`neq`/`lt`/`gt` (v0.2.5), `to_tensor([bool, ...])`
  and tensor-scalar `gt(tensor, scalar)` (v0.3.1) all work. Coral's
  IntCol, `is_nan`/`count_nan`/`any_nan` tensor exports, `agg_count`,
  `value_counts`, int CSV round-trip, and bool CSV/JSON round-trips all
  run end-to-end under `chelis test`

## License

MIT
