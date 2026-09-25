# GroupBy

`Coral.GroupBy` groups a frame by one key column and aggregates the groups.
Keys are matched by host-side equality and keep first-seen order, like pandas
with `sort=False`. Key columns may be int, float, or string; bool keys are not
supported yet. `agg_sum`, `agg_mean`, `agg_min`, and `agg_max` take float or
int value columns, and masked integer entries are skipped.

Operations:

- `group_by`
- `agg_sum`
- `agg_mean`
- `agg_count`
- `agg_min`
- `agg_max`
- `agg` for explicit multi-aggregation specs in requested order. Each value
  column may appear in at most one spec
  ([coral#37](https://github.com/Chelis-Lang/coral/issues/37)), and an
  `AggCount` spec needs a float or int column
  ([coral#38](https://github.com/Chelis-Lang/coral/issues/38))
- `value_counts` — frequency table for a single column (returns a Frame with the key column and a `"count"` column)

```chelis
module Coral.BookGroupBy
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.GroupBy (group_by, agg, AggFn, AggSum, AggMean)
export (main)
def main() -> i64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "london"])), ("qty", int_col_of_list([cast(5, i64), cast(6, i64), cast(7, i64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  grouped = group_by(frame, "city")
  totals = agg(grouped, [("qty", AggSum), ("price", AggMean)])
  nrows(totals)
}
```

The native tests in `tests/groupby.ch` check these operations against
hand-computed values; `parity/goldens/groupby/` holds the pandas results for
the same inputs.
