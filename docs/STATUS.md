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

- `tests/*.ch` — Chelis-native tests run via `chelis test tests/`. 65 tests
  across frame, window, groupby, join, reshape, io, nan, internal. All
  expected values are mathematical identities, hand-computed from inputs,
  structural assertions, or round-trip identities — never pandas-derived.
- `parity/` — pandas-comparison oracle. `parity/run_parity.py` runs the
  golden inventory check, `parity/gen_goldens.py --check` (regenerates
  goldens from pandas and compares), a 2-fixture window runtime parity
  cross-check (rolling_mean + ewm), and the negative test suite.
  `parity/goldens/` holds 44 pandas-derived JSON fixtures.
- `scripts/` — documentation/lint validators (`run_static_checks.py`,
  `run_skill_checks.py`, `validate_book_examples.py`) plus the
  upstream-blocker probe `repro_multimodule_bare_build.py`.

What is currently proven:

- `src/internal/hamt.ch`, `src/frame.ch`, and the shell entrypoints
  typecheck on published `chelis v0.3.2`
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
- `parity/run_parity.py` validates golden inventory, runs the
  pandas-comparison check, executes a 2-fixture window runtime
  cross-check (`rolling_mean_w3` + `ewm_alpha_0_5` build+link+run), and
  checks the negative test suite. The remaining rolling fixtures
  (sum/std/min/max) are pandas-validated via `gen_goldens.py --check`
  without paying the per-fixture build+link+run cost.
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

- (resolved in v0.3.1, moved out of "not yet proven") The prior
  `chelis test` evaluator gap is fully closed: tensor-tensor
  `eq`/`neq`/`lt`/`gt` (v0.2.5), `to_tensor([bool, ...])`, and
  tensor-scalar `gt(tensor, scalar)` (v0.3.1) all work. Coral's
  IntCol, `is_nan`/`count_nan`/`any_nan` tensor exports, `agg_count`,
  `value_counts`, int CSV round-trip, and bool CSV/JSON round-trips
  are all exercised under `chelis test`. Window/Frame runtime parity
  still covers the `chelis build`-target path independently.
- pandas-equivalent sort semantics for NaN-bearing columns
- negative-test coverage for the full frame error surface
- runtime parity for GroupBy, Join, and IO module families against
  pandas (compile-checked plus golden-validated; not run end-to-end
  through `chelis build` against pandas output)
