# GroupBy

`Coral.GroupBy.group_by(frame, key_name)` groups rows by one integer,
float, or string column. Groups appear in the order their keys first
occur. Bool keys fail when grouping runs.

Call `agg_sum`, `agg_mean`, `agg_min`, or `agg_max` with a grouped frame and
a float or integer value-column name. Masked integer values are skipped.
`agg_count(grouped)` counts rows, including rows whose value columns have
missing entries. `value_counts(frame, key_name)` returns the key and a
`count` column.

Use `agg(grouped, specs)` for several results in the order listed. A spec
pairs a value-column name with `AggSum`, `AggMean`, `AggCount`, `AggMin`, or
`AggMax`. Each value column may appear only once, and `AggCount` in this
form also requires a float or integer value column. For a plain row count,
use `agg_count`.

```chelis
module Coral.BookGroupBy
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.GroupBy (group_by, agg, AggSum, AggMean)
export (main)
def main() -> i64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "london"])), ("qty", int_col_of_list([5i64, 6i64, 7i64])), ("price", FloatCol(to_tensor([10.0f32, 20.0f32, 30.0f32])))])
  grouped = group_by(frame, "city")
  totals = agg(grouped, [("qty", AggSum), ("price", AggMean)])
  nrows(totals)
}
```

`main` returns `2`, one row per city. The result columns are `city`,
`qty_sum`, and `price_mean`.
