# Describe

`Coral.Frame.describe` is the first Frame feature that depends on published
Nautilus. It currently targets pandas-style summary rows for numeric columns:
`count`, `mean`, `std`, `min`, `25%`, `50%`, `75%`, and `max`.

For float columns, NaN values are skipped before summary statistics are computed.
The standard deviation follows pandas and uses sample `ddof=1`.

```chelis
module Coral.BookDescribe
import Coral.Frame (from_pairs, describe, nrows, get_float_col, int_col_of_list)
export (main)
def main() -> f32 = {
  frame = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), div(cast(0.0, f32), cast(0.0, f32)), cast(40.0, f32)]))), ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))])
  summary = describe(frame)
  add(cast(nrows(summary), f32), index(to_list(get_float_col(summary, "price")), cast(0, int64)))
}
```
