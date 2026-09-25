# Joins

`Coral.Join` covers `inner_join`, `left_join`, and `outer_join` on a named key
column. Keys may be int, float, or string, and are matched by host-side
equality rather than a sort-merge.

```chelis
module Coral.BookJoin
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join, outer_join)
export (main)
def main() -> i64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([cast(1, i64), cast(2, i64), cast(3, i64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(left_join(left, right, "customer"))
}
```

## outer_join

`outer_join` includes all rows from both frames. Left-only rows get NaN/empty for right
columns; right-only rows get 0 with an integer mask (missing) for left int columns and
NaN for left float columns.

Row order: left-sequential traversal first, then right-only rows appended at the end.

`outer_join` returns the key column as a string column whatever the key type,
so an int key `2` comes back as `"2"`. `inner_join` and `left_join` keep the
key's type.

## Semantics notes

- Right-hand key column is suppressed in the output
- Overlapping right column names are suffixed with `_right`
- A bool non-key column in either input frame fails every join at runtime,
  and a bool key column fails `inner_join` and `left_join`
- Integer columns from the source frame have their missing-value mask propagated through joins
