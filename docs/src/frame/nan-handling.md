# Missing values

Float columns use IEEE NaN for missing numeric values. The helpers
`is_nan`, `fill_nan`, `any_nan`, and `count_nan` take the float tensor from
`get_float_col`; `drop_nan(frame, name)` removes rows from a frame.
`is_nan` tests each value with `neq(value, value)`, which is true for NaN.

```chelis
module Coral.BookMissing
import Coral.Frame (FloatCol, from_pairs, drop_nan, nrows)
export (main)
def main() -> i64 = {
  frame = from_pairs([("value", FloatCol(to_tensor([1.0f32, div(0.0f32, 0.0f32), 3.0f32])))])
  kept = drop_nan(frame, "value")
  nrows(kept)
}
```

`main` returns `2`.

Integer columns store an `i64` tensor alongside a bool mask (`true` means
missing). Use `is_nan_col(frame, name)`, `fill_nan_col`, `drop_nan_col`,
`any_nan_col`, and `count_nan_col` for those columns. `get_int_col` returns
only the values tensor, so use the `_col` helpers when the mask matters.
Grouping skips masked entries for sum, mean, min, and max; counts include
the rows. Joins and concatenation carry the mask into their results.

String and bool columns have no missing-value marker. The CSV and JSON
writers do not encode an integer mask: they write the underlying number,
including `0` in a missing position. See [I/O](../io.md) before writing a
frame with missing integers.
