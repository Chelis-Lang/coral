# Joins

`Coral.Join` matches rows by equality on one named key column. Use
`inner_join(left, right, on)` for matches, `left_join` to keep every left
row, and `outer_join` to include right-only rows too. Integer, float, and
string keys work; bool keys fail for inner and left joins. A bool non-key
column in either input causes any join to fail.

Joins traverse left rows in order. An outer join appends right-only rows
after them. The right key column appears only once in the result. If a
right non-key column has the same name as a left column, Coral adds the
`_right` suffix.

```chelis
module Coral.BookJoin
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join)
export (main)
def main() -> i64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([1i64, 2i64, 3i64]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([10.0f32, 40.0f32])))])
  nrows(left_join(left, right, "customer"))
}
```

`main` returns `3`. The unmatched `b` row has a NaN `score`. For either
unmatched side of an outer join, a missing float value becomes NaN, a
missing string becomes `""`, and a missing integer becomes `0` with a
true missing-value mask. `outer_join` returns the key column as strings
even when the input keys are integers or floats; inner and left joins keep
the key's type.
