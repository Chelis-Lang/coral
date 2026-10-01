# Describe

`Coral.Frame.describe(frame)` summarizes numeric columns and skips string
and bool columns. The result has a `stat` string column with eight rows:
`count`, `mean`, `std`, `min`, `25%`, `50%`, `75%`, and `max`. Each numeric
input column has a corresponding `FloatCol` of results. Coral uses
`Nautilus.Stats` for these calculations.

NaNs in float columns and masked values in integer columns are left out of
the summary. Standard deviation uses the sample divisor (`ddof=1`).

```chelis
module Coral.BookDescribe
import Coral.Frame (FloatCol, from_pairs, describe, get_float_col)
export (main)
def main() -> f32 = {
  frame = from_pairs([("price", FloatCol(to_tensor([10.0f32, div(0.0f32, 0.0f32), 40.0f32])))])
  summary = describe(frame)
  index(to_list(get_float_col(summary, "price")), 0i64)
}
```

The first result is the count of non-NaN prices, so `main` returns `2.0`.
