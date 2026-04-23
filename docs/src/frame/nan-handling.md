# NaN Handling

## Float columns

Float NaN values are handled via IEEE 754 semantics (`x != x` is true iff NaN):

- `is_nan(col)` — returns a bool tensor (true = missing)
- `fill_nan(df, col_name, fill_val)` — replace NaN with `fill_val`
- `drop_nan(df, col_name)` — remove rows where the column is NaN
- `any_nan(col)` — true if any value is NaN
- `count_nan(col)` — count of NaN values

## Integer columns

Integer columns carry an explicit boolean missing-value mask (`true` = missing).
The mask is propagated through joins (sentinel rows), aggregations (masked rows
are skipped), and concat. Use the `_int` variants:

- `is_nan_int(df, col_name)` — returns the bool mask tensor
- `fill_nan_int(df, col_name, fill_val)` — replace masked entries with `fill_val`
- `drop_nan_int(df, col_name)` — remove rows where the mask is true
- `any_nan_int(df, col_name)` — true if any entry is masked
- `count_nan_int(df, col_name)` — count of masked entries

To construct an int column directly: `int_col_of_list([1, 2, 3])` creates an
`IntCol` with an all-false (no missing) mask.
