# Filtering

`Coral.Frame.filter(frame, mask)` keeps the rows marked `true` by a
`tensor[n, bool]` mask. The mask must have the frame's row count. The
result has one row for each true entry, in its original order.

Chelis does not compare a tensor with a scalar by implicit broadcasting.
For a scalar threshold, map a predicate over the column values and convert
the booleans to a tensor:

```chelis
module Coral.BookFilter
import Coral.Frame (FloatCol, from_pairs, filter, get_float_col, nrows)
export (main)
def main() -> i64 = {
  frame = from_pairs([("price", FloatCol(to_tensor([10.0f32, 80.0f32, 100.0f32])))])
  mask = to_tensor(map(fn (price: f32) -> gt(price, 75.0f32), to_list(get_float_col(frame, "price"))))
  kept = filter(frame, mask)
  nrows(kept)
}
```

`main` returns `2`. To compare two tensor columns directly, their shapes
and dtypes must match; see the Chelis Guide's
[standard-library operations](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/stdlib.md).
