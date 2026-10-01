# Concatenation

`Coral.Frame.concat` stacks frames vertically. Pass frames with the same
column names and types, in the same order, and a shared static row count.
The result has the rows of each input in list order.

`concat` takes its output columns and order from the first frame. It does
not validate the complete schema of every later frame: an additional column
in a later frame is omitted. Check the schemas yourself before combining
frames from different sources.

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
