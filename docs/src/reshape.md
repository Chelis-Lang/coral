# Reshape

`Coral.Reshape` changes a frame between wide and long layouts:

| Operation | Result |
|---|---|
| `melt(frame, id_cols, value_cols)` | Repeats string id columns and places float value columns into `variable` and `value` columns |
| `pivot(frame, index_col, columns_col, values_col)` | Makes one float output column per distinct string value in `columns_col` |
| `stack(frame)` | Calls `melt` with no id columns and every column as a value column |
| `unstack(frame, index_col)` | Calls `pivot` using `variable` and `value` |

`melt` needs string id columns and float value columns. It emits all rows
for the first value column, then all rows for the next. `pivot` needs
string index and category columns and a float values column. A missing
index/category combination produces NaN; when several input rows have
the same combination, the first matching value is used.

```chelis
module Coral.BookReshape
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows)
import Coral.Reshape (melt)
export (main)
def main() -> i64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "oslo"])), ("qty", FloatCol(to_tensor([5.0f32, 6.0f32, 7.0f32]))), ("price", FloatCol(to_tensor([10.0f32, 20.0f32, 30.0f32])))])
  melted = melt(frame, ["city"], ["qty", "price"])
  nrows(melted)
}
```

`main` returns `6`: three source rows for each of two value columns.
The output column order is `variable`, `value`, then `city`.
