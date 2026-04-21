# Coral Status

Current work focuses on the first pass of:

- persistent HAMT-backed frame column storage
- typed frame representation
- frame parity infrastructure and pandas-backed goldens
- groupby parity expectations and pandas-backed goldens
- io parity expectations and pandas-backed goldens
- join parity expectations and pandas-backed goldens
- window parity infrastructure and runtime-backed goldens
- filtering and schema mutation
- host-path string grouping and joining
- rolling window helpers
- CSV/JSON I/O

Hard constraint recorded for alpha:

- `Frame.columns` uses a persistent HAMT from day one
- no plain `Dict` fallback for frame column storage
- reason: AD through multi-op frame pipelines must preserve structural sharing instead of copying the full column map on every frame mutation
- implementation order: land `Coral.Internal.HAMT` with isolated tests first, then wire `Coral.Frame` onto it

Known deferred items:

- string sorting
- Parquet
- outer join
- richer reshape support

What is currently proven:

- `src/internal/hamt.ch`, `src/frame.ch`, and the shell entrypoints typecheck on
  published `chelis v0.1.13`
- checked-in `tests/goldens/frame/*.json` fixtures are generated from pandas for a
  deterministic Phase-2 frame slice
- checked-in `tests/goldens/groupby/*.json` fixtures are generated from pandas for the
  current single-key aggregation slice
- checked-in `tests/goldens/io/*.json` fixtures are generated from pandas / Coral text
  expectations for the current CSV/JSON compile-checked slice
- checked-in `tests/goldens/join/*.json` fixtures are generated from pandas for the
  current string-key inner/left join slice
- checked-in `tests/goldens/window/*.json` fixtures are generated from pandas for the
  current rolling/ewm slice
- `tests/run_coral_tests.py` validates the golden inventory and runs a compile-level
  probe covering HAMT-backed frame mutation, bool-column concat, and `describe`
- `tests/run_coral_tests.py` executes a bare-build runtime parity lane for
  `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`, and
  `ewm(alpha, adjust=False)`
- `src/io.ch` now supports bool inference on read and bool rendering on CSV/JSON write

What is not yet proven:

- runtime parity for frame operations end-to-end
- reef-import `chelis build` on HAMT-backed Coral programs under `v0.1.13`
- pandas-equivalent sort semantics for NaN-bearing columns
- negative-test coverage for the full frame error surface
- runtime parity for GroupBy, Join, and IO module families
