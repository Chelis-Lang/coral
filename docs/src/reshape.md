# Reshape

`Coral.Reshape` provides wide-to-long and long-to-wide transformations on
`Frame` values. All four operations are evaluator-tested on the 0.18.1
release line. The stripped bare-C Frame/GroupBy/Join gates pass on the
official release after the chelis#935 fix.

Validated operations in the current slice:

- `melt` — wide to long: repeat id columns, pivot value columns into `variable`/`value` rows
- `pivot` — long to wide: unique values of `columns_col` become new column names
- `stack` — thin shim: `melt` with no id columns, all columns as value columns
- `unstack` — thin shim: `pivot` on a stacked frame given an explicit index column

v0.1 constraints:

- `values_col` for `pivot` must be `FloatCol`; other types fail with a runtime error.
- `value_cols` for `melt` must all be `FloatCol`.
- `index_col` and `columns_col` for `pivot` must be `StringCol`.
- `id_cols` for `melt` must be `StringCol`.

```chelis
module Coral.BookReshape
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols)
import Coral.Reshape (melt)
export (main)
def main() -> int64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "oslo"])), ("qty", FloatCol(to_tensor([cast(5.0, f32), cast(6.0, f32), cast(7.0, f32)]))), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  melted = melt(frame, ["city"], ["qty", "price"])
  nrows(melted)
}
```

The output frame has columns `variable`, `value`, and `city` with
`nrows = 3 * 2 = 6` (one row per original row per value column).

The honest gate today is fixture-backed plus compile-checked. A full
executed runtime parity lane for Reshape will follow when the bare-build
harness is extended to cover multi-column frames.
