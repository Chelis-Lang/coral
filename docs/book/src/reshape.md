# Reshape

`Coral.Reshape` changes a frame between wide and long layouts. Every
function returns a new `Frame[m]`.

| Operation | Signature | Result |
|---|---|---|
| `melt` | `(df: Frame[n], id_cols: List[string], value_cols: List[string]) -> Frame[m]` | Repeats string id columns and places float value columns into `variable` and `value` columns |
| `pivot` | `(df: Frame[n], index_col: string, columns_col: string, values_col: string) -> Frame[m]` | Makes one float output column per distinct string value in `columns_col` |
| `stack` | `(df: Frame[n]) -> Frame[m]` | `melt` with no id columns and every column as a value column |
| `unstack` | `(df: Frame[n], index_col: string) -> Frame[m]` | `pivot` with `variable` as the category column and `value` as the values column |

## melt and stack

`melt` needs string id columns and float value columns. It emits all rows
for the first value column, then all rows for the next. The output column
order is `variable`, `value`, then the id columns. Columns named in
neither list are dropped. Do not name an id column `variable` or `value`:
the id column silently replaces that output column. Melting a string id
column named `value` returns only `variable` and `value`, where `value`
now holds the id strings.

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

`stack` passes every column as a value column, so every column must be
float. A frame with a string or integer column fails with
`melt: value_cols must be float`; use `melt` and name the id columns
instead. Stacking float columns `a = [1.0, 2.0]` and `b = [3.0, 4.0]`
gives columns `variable` and `value`, with values `[1.0, 2.0, 3.0, 4.0]`.

## pivot and unstack

`pivot` needs string index and category columns and a float values
column; another type fails with `pivot: index_col must be string`,
`pivot: columns_col must be string`, or `pivot: values_col must be float`.

- **Layout.** The index column comes first, then one float column per
  distinct category. Rows follow the order in which index values first
  appear; generated columns follow the order in which categories first
  appear.
- **Gaps and duplicates.** A missing index/category combination gives
  NaN. When several input rows share a combination, the first one wins.
- **Other columns** are dropped.
- **Name clash.** A category equal to the index column's name silently
  replaces the index column with that category's float values. Rename
  the index column first if a category could share its name.

For an input with `day = ["tue", "mon", "tue", "mon", "tue"]`,
`field = ["qty", "qty", "price", "price", "qty"]`, and
`v = [1.0, 2.0, 3.0, 4.0, 9.0]`, `pivot(long, "day", "field", "v")` returns
columns `day`, `qty`, `price` with `day = ["tue", "mon"]`,
`qty = [1.0, 2.0]`, and `price = [3.0, 4.0]`. The second `tue`/`qty` row
(`9.0`) is ignored.

`unstack(frame, index_col)` reverses a `melt` that had one id column:
melting `city`, `qty`, `price` on `city` and then unstacking on `city`
returns columns `city`, `qty`, `price` again.
