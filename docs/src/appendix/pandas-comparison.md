# Pandas comparison

Coral uses pandas as a reference for supported operations. These
conventions matter when comparing results:

| Area | Coral behavior |
|---|---|
| Grouping and `value_counts` | Keys keep first-seen order. Pandas normally sorts group keys or sorts value counts by frequency. |
| `outer_join` | Left rows remain in order, followed by right-only rows. Its key column is converted to strings. |
| Joins with overlapping names | A right non-key column receives the `_right` suffix. |
| `melt` | Output columns are `variable`, `value`, then id columns; rows are grouped by source value column. |
| Missing values | Float columns use NaN; integer columns have a separate bool mask; string and bool columns have no missing marker. |
| `describe` | Numeric columns use sample standard deviation (`ddof=1`); non-numeric columns are omitted. |

See [I/O](../io.md) for file formats and output limits, including integer
masks that are not preserved by the writers. See [limitations](limitations.md)
for column-type and execution boundaries.
