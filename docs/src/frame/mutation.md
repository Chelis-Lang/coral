# Changing columns

`with_column(frame, name, column)` adds a column or replaces one with the
same name. `mutate` does the same thing. The new column must have the frame's
row count. `rename` changes a column name and rejects a name already in use;
`drop_column` removes a named column.

```chelis
module Coral.BookMutation
import Coral.Frame (FloatCol, from_pairs, with_column, rename, drop_column, int_col_of_list, ncols)
export (main)
def main() -> i64 = {
  frame = from_pairs([("price", FloatCol(to_tensor([10.0f32, 20.0f32])))])
  renamed = rename(frame, "price", "cost")
  extended = with_column(renamed, "qty", int_col_of_list([2i64, 3i64]))
  trimmed = drop_column(extended, "cost")
  ncols(trimmed)
}
```

`main` returns `1`: only `qty` remains. The operations return new frame
values; use the returned frame for subsequent steps.
