# Pandas Comparison

Coral uses pandas as its behavioral reference for the first validated frame slice.

Current parity-backed scope:

- construction from typed pairs
- boolean-mask filtering
- `head`, `tail`, and `slice`
- `rename`, `with_column`, and `drop_column`
- float-NaN helpers
- vertical `concat`
- numeric `describe`
- single-key `group_by` with `sum` / `mean` / `count` / `min` / `max`
- string-key `inner_join` and `left_join` for the current supported output slice
- CSV/JSON read-write expectations for int / float / bool / string columns
- `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`
- `ewm(alpha, adjust=False)`

Documented deltas:

- string `sort_by` is deferred
- stripped Frame/GroupBy/Join bare builds now link and run correctly on
  `chelis v0.1.18`; a non-fatal Phase 0e panic in `chelis build` remains
  (see `docs/UPSTREAM_BUGS.md`); acceptance gate is fixture goldens plus
  the compile-level probe in `tests/run_coral_tests.py`
- GroupBy, Join, and IO are currently fixture-backed plus compile-checked
- Window is the only module family with an executed runtime parity lane today
