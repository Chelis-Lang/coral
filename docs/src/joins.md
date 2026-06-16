# Joins

`Coral.Join` covers `inner_join`, `left_join`, and `outer_join` with string keys.
The implementation uses host-path equality matching rather than sort-merge ordering.

```chelis
module Coral.BookJoin
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join, outer_join)
export (main)
def main() -> int64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(left_join(left, right, "customer"))
}
```

## outer_join

`outer_join` includes all rows from both frames. Left-only rows get NaN/empty for right
columns; right-only rows get 0 with an integer mask (missing) for left int columns and
NaN for left float columns.

Row order: left-sequential traversal first, then right-only rows appended at the end.

## Semantics notes

- Right-hand key column is suppressed in the output
- Overlapping right column names are suffixed with `_right`
- Bool output columns from the joined right side are deferred
- Integer columns from the source frame have their missing-value mask propagated through joins
