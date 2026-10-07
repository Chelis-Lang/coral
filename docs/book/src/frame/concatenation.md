# Concatenation

`Coral.Frame.concat` stacks frames vertically. Pass frames with the same
column names and types and a shared static row count. The result has the
rows of each input in list order.

`concat` takes its output columns and their order from the first frame,
then looks up each of those columns by name in every later frame:

| Later frame | Result |
|---|---|
| Same columns in a different order | Accepted; values are matched by name, and the first frame's order is kept |
| An extra column | The column is omitted, without an error |
| Missing a first-frame column | Fails with `missing column: NAME` |
| A first-frame column with a different type | Fails with the accessor error for the first frame's type, such as `column is not int: NAME` |

An empty list returns a frame with no columns and zero rows.

```chelis
module Coral.BookConcat
import Coral.Frame (BoolCol, from_pairs, concat, nrows, int_col_of_list)
export (main)
def main() -> i64 = {
  lhs = from_pairs([("id", int_col_of_list([1i64, 2i64])), ("flag", BoolCol(to_tensor([true, false])))])
  rhs = from_pairs([("id", int_col_of_list([3i64, 4i64])), ("flag", BoolCol(to_tensor([true, true])))])
  nrows(concat([lhs, rhs]))
}
```

`main` returns `4`. `concat` accepts `IntCol`, `FloatCol`, `StringCol`,
and `BoolCol`; it carries integer missing-value masks through to the
result. A different row count can be rejected because all inputs share the
same `Frame[n]` type in this function's signature.
