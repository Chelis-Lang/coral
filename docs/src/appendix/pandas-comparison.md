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
- `sort_by` on int, float, bool, and string columns
- single-key `group_by` with `sum` / `mean` / `count` / `min` / `max`
- string-key `inner_join` and `left_join` for the current supported output slice
- CSV/JSON read-write expectations for int / float / bool / string columns
- `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`
- `ewm(alpha, adjust=False)`

Documented deltas:

- stripped Frame/GroupBy/Join bare builds are fully clean on `chelis v0.2.5`:
  build, link, and execution all pass; acceptance gate is fixture goldens plus
  the compile-level probe in `parity/run_parity.py`
- GroupBy, Join, and IO are currently fixture-backed plus compile-checked
- Window and Frame both have an executed runtime parity lane; GroupBy, Join, and IO are fixture-backed plus compile-checked
- Chelis-native correctness lives in `tests/*.ch` (`chelis test tests/`); pandas
  comparison work and goldens live in `parity/`
