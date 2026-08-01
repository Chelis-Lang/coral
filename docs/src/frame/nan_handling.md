# NaN Handling

## Float columns

Float NaN values are handled via IEEE 754 semantics (`x != x` is true iff NaN).
At the 0.18.1 compiler pin, Coral computes the float mask through an O(n)
scalar host-map because native tensor `neq` is not yet IEEE-correct
([chelis#630](https://github.com/Chelis-Lang/chelis/issues/630)).
Note the asymmetry with the column-form helpers below: float helpers operate on
*tensors* (extract the column with `get_float_col` first), while the `_col`
helpers take a `Frame` plus a column name.

- `is_nan(col)` — returns a bool tensor (true = missing)
- `fill_nan(col, fill_val)` — replace NaN with `fill_val` in a float tensor
- `drop_nan(df, col_name)` — remove rows where the column is NaN
- `any_nan(col)` — true if any value is NaN
- `count_nan(col)` — count of NaN values

## Integer columns

Integer columns carry an explicit boolean missing-value mask (`true` = missing).
The mask is propagated through joins (sentinel rows), aggregations (masked rows
are skipped), and concat. Use the `_col` variants:

- `is_nan_col(df, col_name)` — returns the bool mask tensor
- `fill_nan_col(df, col_name, fill_val)` — replace masked entries with `fill_val`
- `drop_nan_col(df, col_name)` — remove rows where the mask is true
- `any_nan_col(df, col_name)` — true if any entry is masked
- `count_nan_col(df, col_name)` — count of masked entries

To construct an int column directly: `int_col_of_list([1, 2, 3])` creates an
`IntCol` with an all-false (no missing) mask.
