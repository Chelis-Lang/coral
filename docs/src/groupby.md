# GroupBy

`Coral.GroupBy` currently validates a single-key aggregation slice against
checked-in pandas goldens. The current implementation uses host-path key
equality and preserves first-seen key order (`sort=False`-style behavior).

Validated operations in the current slice:

- `group_by`
- `agg_sum`
- `agg_mean`
- `agg_count`
- `agg_min`
- `agg_max`
- `agg` for explicit multi-aggregation specs in requested order
- `value_counts` — frequency table for a single column (returns a Frame with the key column and a `"count"` column)

```chelis
module Coral.BookGroupBy
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.GroupBy (group_by, agg, AggFn, AggSum, AggMean)
export (main)
def main() -> int64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "london"])), ("qty", int_col_of_list([cast(5, int64), cast(6, int64), cast(7, int64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  grouped = group_by(frame, "city")
  totals = agg(grouped, [("qty", AggSum), ("price", AggMean)])
  nrows(totals)
}
```

The honest gate today is fixture-backed plus evaluator-tested. The stripped
Frame/GroupBy/Join bare probes also build, link, and run on the official
Chelis 0.18.1 / Nautilus 0.7.38 chain after chelis#935's nullary generic
`Hamt.Empty` lowering fix.
