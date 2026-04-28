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
| `Coral.IO` | CSV and JSON read/write |
| `Coral.Reshape` | `pivot`, `melt`, `stack`, `unstack` |

## Toolchain

Pinned to `chelis v0.3.0` in `reef.toml`:

```toml
compiler = "=0.3.0"
```

## Build

For local development in this workspace, Coral uses a vendored
`chelis-std` snapshot from the published `v0.1.13` compiler source tag
and a vendored snapshot of the published Nautilus `v0.1.2` package.
With the compiler on `PATH`, or `CHELIS_BIN` pointed at the published
binary:

```sh
chelis check src/frame.ch
chelis reef build
chelis test tests/                     # internal correctness (Chelis-native)
python scripts/run_static_checks.py
python scripts/run_skill_checks.py
python scripts/validate_book_examples.py
python parity/run_parity.py            # pandas-comparison oracle
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
- null semantics are intentionally narrower than pandas in the first pass
- chelis v0.3.0 narrows the prior evaluator gap: tensor-tensor
  `eq`/`neq`/`lt`/`gt` and IntCol / `is_nan` / `count_nan` / `any_nan`
  tensor exports are now exercised from `tests/*.ch`. Still blocked at
  the eval level: `to_tensor([bool, ...])` (so bool CSV/JSON round trips
  stay compile-checked only) and tensor-scalar `gt(tensor, scalar)`

## License

MIT
