# Construction

A `Frame` stores columns of one row count. `from_pairs` keeps the listed
column order and rejects duplicate names or unequal column lengths. The
four column forms are:

| Form | Stored values |
|---|---|
| `FloatCol` | `tensor[n, f32]` |
| `IntCol` | `tensor[n, i64]` and a `tensor[n, bool]` missing-value mask |
| `BoolCol` | `tensor[n, bool]` |
| `StringCol` | `List[string]` |

Use `int_col_of_list` to make an integer column with no missing entries.

| Function | Signature | Failure |
|---|---|---|
| `from_pairs` | `(pairs: List[(string, Column[n])]) -> Frame[n]` | `from_pairs: duplicate column name`, `from_pairs: mismatched column lengths` |
| `from_columns` | `(cols: Dict[string, Column[n]]) -> Frame[n]` | Same as `from_pairs` |
| `empty` | `(schema: Dict[string, ColumnType]) -> Frame[n]` | None |
| `int_col_of_list` | `(values: List[i64]) -> Column[n]` | None |

`from_pairs([])` returns a frame with no columns and zero rows.

`from_columns` and `empty` take their column order from the dictionary's
entry order, as `dict_entries` returns it; use `from_pairs` when you need
to state the order explicitly. `empty` makes a
frame with the named columns and zero rows; the `ColumnType` values are
`IntType`, `FloatType`, `StringType`, and `BoolType`.

```chelis
module Coral.BookConstruct
import Coral.Frame (FloatCol, StringCol, from_pairs, get_float_col)
export (main)
def main() -> f32 = {
  frame = from_pairs([("price", FloatCol(to_tensor([1.0f32, 2.0f32]))), ("name", StringCol(["a", "b"]))])
  prices = get_float_col(frame, "price")
  index(to_list(prices), 1i64)
}
```

`get_float_col` returns a Chelis tensor, so `main` reads the second price
and returns `2.0`.

```chelis
module Coral.BookEmpty
import Coral.Frame (IntType, StringType, empty, columns, nrows)
export (main)
def main() -> (List[string], i64) = {
  frame = empty(dict_of([("id", IntType), ("city", StringType)]))
  (columns(frame), nrows(frame))
}
```

`main` returns `[id, city]` and `0`.

## Reading a frame

| Function | Signature | Failure |
|---|---|---|
| `get_float_col` | `(df: Frame[n], name: string) -> tensor[n, f32]` | `missing column: NAME`, `column is not float: NAME` |
| `get_int_col` | `(df: Frame[n], name: string) -> tensor[n, i64]` | `missing column: NAME`, `column is not int: NAME` |
| `get_bool_col` | `(df: Frame[n], name: string) -> tensor[n, bool]` | `missing column: NAME`, `column is not bool: NAME` |
| `get_string_col` | `(df: Frame[n], name: string) -> List[string]` | `missing column: NAME`, `column is not string: NAME` |
| `get_column` | `(df: Frame[n], name: string) -> Column[n]` | `missing column: NAME` |
| `column_type` | `(df: Frame[n], name: string) -> ColumnType` | `missing column: NAME` |
| `columns` | `(df: Frame[n]) -> List[string]` | None |
| `nrows`, `ncols` | `(df: Frame[n]) -> i64` | None |

A missing name or a mismatched column type fails when the accessor runs.
`get_int_col` returns only the values; a missing entry reads as its stored
number, usually `0`. Read the mask with `is_nan_col` (see
[Missing values](nan-handling.md)) or match on `get_column` to
get both tensors of an `IntCol`.
