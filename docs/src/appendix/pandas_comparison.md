# Pandas Comparison

Coral uses pandas as its behavioral reference. `parity/gen_goldens.py`
records pandas results for fixed inputs as JSON goldens under
`parity/goldens/`, and CI confirms on every change that the goldens still
match pandas.

Covered by goldens:

- construction from typed pairs, boolean-mask filtering, `head`, `tail`,
  `slice`, `rename`, `with_column`, `drop_column`
- float and integer NaN helpers, vertical `concat`, numeric `describe`,
  `value_counts`
- `sort_by` on string columns, ascending and descending
- single-key `group_by` with `sum`, `mean`, `count`, `min`, `max`, and a
  multi-aggregation spec
- `inner_join`, `left_join`, and `outer_join` on a string key
- CSV and JSON read and write for int, float, bool, and string columns
- `pivot`, `melt`, `stack`, `unstack`
- `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`,
  `rolling_max`, and `ewm(alpha, adjust=False)`

How Coral is checked against them:

- `rolling_mean` and `ewm` are compiled to native code, run, and compared
  with their goldens by `parity/run_parity.py`.
- For everything else, the native tests in `tests/*.ch` assert
  hand-computed values for the same behaviors; the goldens are the
  reference those expectations are written against, not an automated
  comparison.

Documented deltas from pandas:

- Grouping keeps first-seen key order (pandas `sort=False`).
- Missing values: float columns use NaN, integer columns carry a separate
  mask, and string and bool columns have no missing marker (joins pad
  unmatched string cells with `""`).
- `outer_join` returns its key column as strings.
- Overlapping right-hand column names in a join get a `_right` suffix.
- `describe` uses the sample standard deviation (`ddof=1`), as pandas does,
  and skips non-numeric columns.
