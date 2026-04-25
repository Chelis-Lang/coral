# Coral Status

Phase 3t cutover complete: Chelis-native test harness (`chelis test tests/`)
runs alongside pandas-parity (`parity/run_parity.py`).

Current work focuses on:

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

- Parquet
- `stack` with mixed-type frames (string + float columns): `melt` requires float value_cols; stack on a pure-float frame works correctly

Test harness layout (Phase 3t):

- `tests/*.ch` — Chelis-native tests run via `chelis test tests/`. 56 tests
  across frame, window, groupby, join, reshape, io, nan, internal. All
  expected values are mathematical identities, hand-computed from inputs,
  structural assertions, or round-trip identities — never pandas-derived.
- `parity/` — pandas-comparison oracle. `parity/run_parity.py` runs the
  golden inventory check, `parity/gen_goldens.py --check` (regenerates
  goldens from pandas and compares), the window runtime parity lane
  (expected values pandas-derived), the HAMT integration compile probe,
  and the negative test suite. `parity/goldens/` holds 44 pandas-derived
  JSON fixtures.
- `scripts/` — documentation/lint validators (`run_static_checks.py`,
  `run_skill_checks.py`, `validate_book_examples.py`) plus the
  upstream-blocker probe `repro_multimodule_bare_build.py`.

What is currently proven:

- `src/internal/hamt.ch`, `src/frame.ch`, and the shell entrypoints
  typecheck on published `chelis v0.2.4`
- 8 `tests/*.ch` modules cover construction, filter (via mask
  consumers), head/tail/slice, rename/with_column/drop, sort_by
  (string asc/desc, float), concat, describe, single-key aggregations
  (sum/mean/min/max), inner/left/outer join, melt/pivot/stack/unstack,
  rolling sum/mean/min/max/std, ewm recurrence, and frame core
  algorithms (`str_lt`, `enum_insertion_sort`, `slice` reindex,
  `describe` skip-nan)
- HAMT-dependent operations (`from_pairs`, `with_column`, `describe`,
  joins, reshape) run end-to-end via `chelis test` — closes the v0.2.0
  generic-specialization runtime gap
- 44 checked-in `parity/goldens/*.json` fixtures (frame/groupby/io/join/
  window/reshape) are generated from pandas
- `parity/run_parity.py` validates golden inventory, runs a compile-level
  probe covering HAMT-backed frame mutation/bool-column concat/describe,
  executes the window runtime parity lane (`rolling_sum/mean/std/min/max`,
  `ewm(alpha, adjust=False)`), and checks the negative test suite
- negative test suite validates `TypeMismatch` and `UnboundVariable` at
  check time
- `src/io.ch` supports bool inference on read and bool rendering on
  CSV/JSON write
- `src/apismoke.ch` imports all float NaN helpers: `is_nan`, `fill_nan`,
  `drop_nan`, `any_nan`, `count_nan`
- SKILL examples and the mdBook cover the current validated GroupBy,
  Join, IO, Window, and Reshape slices without overstating runtime status
- CI hard-rule grep guards: no `.py` under `tests/`, no
  `pandas`/`scipy` references in `src/` or `tests/`

What is not yet proven:

- chelis v0.2.4 evaluator (used by `chelis test`) does not implement
  tensor-tensor `eq`/`neq` / `lt`/`gt`. As a result, IntCol/BoolCol
  construction and the float-tensor `is_nan`/`any_nan`/`count_nan`/
  `drop_nan` exports cannot be exercised from `tests/*.ch` directly.
  Tests work around this with element-wise scalar reimplementations
  where possible; the original tensor-level functions remain
  runtime-unverified at the `chelis test` level. Window/Frame runtime
  parity covers the `chelis build`-target path.
- pandas-equivalent sort semantics for NaN-bearing columns
- negative-test coverage for the full frame error surface
- runtime parity for GroupBy, Join, and IO module families against
  pandas (compile-checked plus golden-validated; not run end-to-end
  through `chelis build` against pandas output)
