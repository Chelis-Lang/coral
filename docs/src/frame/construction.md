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
`from_columns` and `empty` accept dictionaries, whose entry order determines
the resulting column order; use `from_pairs` when order matters.

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
and returns `2.0`. The other typed accessors are `get_int_col`,
`get_bool_col`, and `get_string_col`. A missing name or a mismatched
column type fails when the accessor runs.
