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
- `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`
- `ewm(alpha, adjust=False)`

Documented deltas:

- string `sort_by` is deferred
- runtime reef-import builds for HAMT-backed Coral programs are blocked on
  `chelis v0.1.13`, so the current acceptance gate is compile-level plus
  pandas-backed checked-in goldens
- GroupBy, Join, Window, and IO are still ahead of their own parity lanes
