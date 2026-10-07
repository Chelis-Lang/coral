# Missing values

Float columns use IEEE NaN for missing numeric values. Integer columns
store an `i64` tensor alongside a bool mask where `true` means missing.
String and bool columns have no missing-value marker.

## Float columns

The tensor helpers take a borrowed float tensor, usually one read with
`get_float_col`. `drop_nan` takes the frame and a column name.

| Function | Signature | Result |
|---|---|---|
| `is_nan` | `(col: &tensor[n, f32]) -> tensor[n, bool]` | `true` where the value is NaN |
| `fill_nan` | `(col: &tensor[n, f32], value: f32) -> tensor[n, f32]` | Copy with each NaN replaced by `value` |
| `any_nan` | `(col: &tensor[n, f32]) -> bool` | Whether any value is NaN |
| `count_nan` | `(col: &tensor[n, f32]) -> i64` | Number of NaNs |
| `drop_nan` | `(df: Frame[n], col_name: string) -> Frame[k]` | Frame without the rows where `col_name` is NaN |

`is_nan` tests each value with `neq(value, value)`, which is true only for
NaN; infinities are not missing. `fill_nan` returns a tensor, so put it
back with `with_column(frame, name, FloatCol(filled))`. `drop_nan` fails with
`missing column: NAME` for a name the frame lacks and with
`column is not float: NAME` for a column that is not float.

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

`main` returns `2`. For the tensor `[1.0, NaN, 3.0]` held in `col`,
`is_nan(&col)` is `[false, true, false]`, `fill_nan(&col, 0.0f32)` is
`[1.0, 0.0, 3.0]`, `any_nan(&col)` is `true`, and `count_nan(&col)` is `1`.

## Integer columns

The `_col` helpers take the frame and a column name. On a column that is
not an integer column they fail, for example with
`is_nan_col: column is not int: NAME`.

| Function | Signature | Result |
|---|---|---|
| `is_nan_col` | `(df: Frame[n], col_name: string) -> tensor[n, bool]` | The column's mask |
| `fill_nan_col` | `(df: Frame[n], col_name: string, fill_val: i64) -> Frame[n]` | Frame with each missing entry set to `fill_val` and the mask cleared |
| `drop_nan_col` | `(df: Frame[n], col_name: string) -> Frame[k]` | Frame without the rows where the column is missing |
| `any_nan_col` | `(df: Frame[n], col_name: string) -> bool` | Whether any entry is missing |
| `count_nan_col` | `(df: Frame[n], col_name: string) -> i64` | Number of missing entries |

Build a column with missing entries directly from its two tensors:
`IntCol(to_tensor([5i64, 0i64, 7i64]), to_tensor([false, true, false]))`.
For that column, `is_nan_col` returns `[false, true, false]`,
`fill_nan_col(frame, "qty", -1i64)` stores `[5, -1, 7]`, `drop_nan_col`
keeps two rows, `any_nan_col` is `true`, and `count_nan_col` is `1`.

`get_int_col` returns only the values tensor, where a missing entry reads
as its stored number. Use the `_col` helpers when the mask matters.

## How other operations treat missing values

| Operation | Float NaN | Masked integer |
|---|---|---|
| `describe` | Left out | Left out |
| GroupBy `agg_sum`, `agg_mean`, `agg_min`, `agg_max` | Not skipped; see [GroupBy](../groupby.md) | Skipped |
| GroupBy keys | All NaN keys form one group | All masked keys form one group |
| Join keys | NaN matches NaN | Masked matches masked |
| Joins and `concat` | Carried through | Mask carried through |
| Rolling and `ewm` | Propagates; see [Window](../window.md) | Not applicable |
| CSV and JSON writers | CSV writes `NaN`; JSON writes `null` | Mask ignored; the stored number is written |

The writers do not encode an integer mask: a missing entry stored as `0`
is written as `0`, and reading the file back does not restore the mask.
See [I/O](../io.md) before writing a frame with missing integers.
