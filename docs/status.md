# Coral Status

Phase 3t cutover complete: Chelis-native test harness
(`chelis test tests/ --jobs auto`) runs alongside pandas-parity
(`parity/run_parity.py`).

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
- implementation order: land `Coral.Internal.Hamt` with isolated tests first, then wire `Coral.Frame` onto it

Known deferred items:

- Parquet
- `stack` with mixed-type frames (string + float columns): `melt` requires float value_cols; stack on a pure-float frame works correctly

Test harness layout (Phase 3t):

- `tests/*.ch` — Chelis-native tests run via
  `chelis test tests/ --jobs auto`. 74 tests across as-of, frame, window,
  groupby, join, reshape, io, nan, and internal modules. All expected values are
  mathematical identities, hand-computed from inputs, structural
  assertions, or round-trip identities — never pandas-derived.
- `parity/` — pandas comparison oracle. `parity/run_parity.py` runs the
  golden inventory check, `parity/gen_goldens.py --check` (regenerates
  goldens from pandas and compares), a 2-fixture window runtime parity
  cross-check (rolling_mean + ewm), and the negative test suite.
  `parity/goldens/` holds 45 pandas-derived JSON fixtures.
- `scripts/` — documentation/lint validators (`run_static_checks.py`,
  `run_skill_checks.py`, `validate_book_examples.py`) plus the
  upstream-blocker probe `repro_multimodule_bare_build.py`.
- `tests_neg/` pins 4 user-error diagnostics; `tests_blocked/` pins 2 live
  upstream failures and intentionally becomes loud `FIX-detected` evidence
  when either narrowing can be removed.

What is currently proven:

- The validated dependency chain is the official Chelis 0.18.1 and Nautilus
  0.7.38 publisher-checksummed releases. The compiler binary SHA-256 is
  `0d7a46262b4ba2975702d5ed2def5d54b79b5d68258602da59069b6715cc690b`;
  the Nautilus CHB and archive SHA-256 are
  `cad8bd996ddeddb25f698496a394ab45388a120f9b870e7832cb5b87b5935740`
  and `39a81b079dfae2a0aa907574954eeb48631757fb5fb1d0940def0c8a98adf4f6`.
- `src/internal/hamt.ch`, `src/frame.ch`, and the shell entrypoints
  typecheck on the official Chelis 0.18.1 release.
- Empty tensor row counts now use O(1) `numel`, and tensor-native `not` drives
  integer masks and mask inversion. Empty float/int/bool column tests and
  executed drop-NaN tests pin those paths. Two `chelis#630` residues remain:
  borrowed/borrowed tensor `neq` selects `tensor[f32]`, and bool-typed tensor
  `neq` is IEEE-wrong for NaN in native C. Float `is_nan` therefore retains an
  O(n) scalar host-map, protected by evaluator tests plus a compile-link-run
  mask/drop-core/count/any regression.
- The bare native lane is split honestly: stripped Frame/GroupBy/Join modules
  with a trivial entrypoint build/link/run, and the NaN drop core executes.
  Invoking actual `drop_nan(Frame, ...)` still reaches the branded recursive
  generic HAMT boundary (`chelis#941`), mechanically pinned by
  `scripts/repro_native_drop_nan_blocked.py`.
- 9 `tests/*.ch` modules cover as-of lookup/join, construction, filter (via mask
  consumers), head/tail/slice, rename/with_column/drop, sort_by
  (string asc/desc, float), concat, describe, single-key aggregations
  (sum/mean/min/max), inner/left/outer join, melt/pivot/stack/unstack,
  rolling sum/mean/min/max/std, ewm recurrence, and frame core
  algorithms (`str_lt`, `enum_insertion_sort`, `slice` reindex,
  `describe` skip-nan)
- HAMT-dependent operations (`from_pairs`, `with_column`, `describe`,
  joins, reshape) run end-to-end via `chelis test` — closes the v0.2.0
  generic-specialization runtime gap
- 45 checked-in `parity/goldens/*.json` fixtures (frame/groupby/io/join/
  window/reshape) are generated from pandas
- `parity/run_parity.py` validates golden inventory, runs the
  pandas comparison check, executes a 2-fixture window runtime
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
- v0.7.6 testing cutover timing is recorded in
  `docs/testing_cutover_0.7.6.json`: node-local `--jobs auto` ran
  65 tests in 0:34.06; serial `--jobs 1` ran the same suite in 0:38.72.

What is not yet proven:

- publication of official Coral 0.7.35 release assets. The post-merge tag
  workflow must publish and checksum the official copies after fresh red-team
  review. The exact release-candidate gate is green: 74 positive, 4 negative,
  and 2 Chelis blocked probes plus the native chelis#941 expected-failure
  probe; strict pandas/runtime parity; all SKILL/mdBook examples; all three
  trivial-entry bare-C module smokes; conformance audit and bump-check; and
  byte-identical, corruption-rejecting artifact verification. Candidate SHA-256
  values are `457bc6a41246795f0ce77763e490b4869225faf837255d15e655fb3e709e9a8b`
  (CHB) and `8a95c0bb412c86040cba5210d4a305034761d5a205291c30b472c324b78650f5`
  (archive).
- native compile-link-run of the full production `drop_nan(Frame, ...)` call.
  Official Chelis 0.18.1 rejects its recursive generic `hamt__from_pairs_rec`
  specialization under chelis#941/[05-UNS-1]. The positive native regression
  covers mask creation, `any_nan`, `count_nan`, and the exact
  mask-to-index/gather drop core, not full Frame reconstruction.
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
