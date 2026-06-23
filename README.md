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
| `Coral.AsOf` | sorted as-of lookup and join helpers over `int64` keys with `f32` values |

## Toolchain

Pinned to `chelis v0.9.0` in `reef.toml`:

```toml
compiler = "=0.9.0"
```

## Build

A Coral checkout uses `chelis-std 0.4.0` and `nautilus 0.7.28`
resolved from the local reef registry. With the compiler on `PATH`, or
`CHELIS_BIN` pointed at the published binary:

```sh
chelis check src/frame.ch
chelis reef build
chelis test tests/ --jobs auto         # internal correctness (Chelis-native)
chelis test tests/ --jobs 1            # serial fallback for debugging
python scripts/run_static_checks.py
python scripts/run_skill_checks.py
python scripts/validate_book_examples.py
python parity/run_parity.py            # pandas comparison oracle
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
- Parquet I/O is upstream-blocked (see `docs/upstream_bugs.md`)
- null semantics are intentionally narrower than pandas in the first pass
- the prior `chelis test` evaluator gap is fully resolved as of chelis
  v0.3.1: tensor-tensor `eq`/`neq`/`lt`/`gt` (v0.2.5), `to_tensor([bool, ...])`
  and tensor-scalar `gt(tensor, scalar)` (v0.3.1) all work. Coral's
  IntCol, `is_nan`/`count_nan`/`any_nan` tensor exports, `agg_count`,
  `value_counts`, int CSV round-trip, and bool CSV/JSON round-trips all
  run end-to-end under `chelis test`

## License

MIT
