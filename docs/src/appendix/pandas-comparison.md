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
- stripped bare-build runtime proof for Frame/GroupBy/Join is still blocked on
  `chelis v0.1.17`, so the current acceptance gate is compile-level plus
  pandas-backed checked-in goldens
- GroupBy, Join, and IO are currently fixture-backed plus compile-checked
- Window is the only module family with an executed runtime parity lane today
