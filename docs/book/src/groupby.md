# GroupBy

`Coral.GroupBy.group_by(frame, key_name)` groups rows by one integer,
float, or string column and returns a `GroupedFrame`. Groups appear in the
order their keys first occur. A `key_name` the frame lacks fails with
`missing column: NAME`. A bool key column is rejected: the aggregation
that builds the result fails.

Missing keys group together. Every NaN key in a float column falls into
one group, and every masked entry in an integer column falls into one
group whose result key is masked.

## Aggregations

Each aggregation returns a frame with the key column first, one row per
group.

| Call | Value column | Result column | Result type |
|---|---|---|---|
| `agg_sum(grouped, col)` | float or integer | `<col>_sum` | Same as the input |
| `agg_mean(grouped, col)` | float or integer | `<col>_mean` | Float |
| `agg_min(grouped, col)` | float or integer | `<col>_min` | Same as the input |
| `agg_max(grouped, col)` | float or integer | `<col>_max` | Same as the input |
| `agg_count(grouped)` | none | `count` | Integer, no missing entries |
| `value_counts(frame, key_name)` | none | `count` | Integer, no missing entries |

`value_counts(frame, key_name)` is `agg_count(group_by(frame, key_name))`.
`agg_count` counts every row in the group, including rows with missing
values and rows whose key is missing. A string or bool value column fails,
for example with `agg_sum: only float and int columns are supported`.

Use `agg(grouped, specs)` for several results in one frame. A spec pairs a
value-column name with `AggSum`, `AggMean`, `AggCount`, `AggMin`, or
`AggMax`; the result columns follow the spec order with the names in the
table above, and `AggCount` produces `count`. Each value column may appear
only once: a repeated name fails with `agg: column not found`. `AggCount`
in this form also needs a float or integer value column. For a plain row
count, use `agg_count`.

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

## Missing values in value columns

Integer and float columns are treated differently:

- **Masked integers are skipped** by sum, mean, min, and max. A group whose
  values are all masked gives a sum of `0` and a mean of NaN, and
  `agg_min` and `agg_max` fail with an index error.
- **Float NaNs are not skipped.** A NaN makes the group's sum and mean NaN.
  `agg_min` and `agg_max` start from the group's first value: a NaN in the
  first row gives NaN, and a NaN in a later row is passed over. For
  values `[NaN, 2.0]`, `agg_min` is NaN; for `[2.0, NaN]`, it is `2.0`.

To get pandas-style results that skip NaN, call `drop_nan` on the value
column before grouping.

`agg` is one of the functions `chelis build` rejects; see
[limitations](appendix/limitations.md).
