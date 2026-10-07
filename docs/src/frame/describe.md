# Describe

`Coral.Frame.describe(frame)` summarizes numeric columns and skips string
and bool columns. The result has a `stat` string column with eight rows:
`count`, `mean`, `std`, `min`, `25%`, `50%`, `75%`, and `max`. Each float or
integer input column becomes a `FloatCol` of results under the same name,
in the input's column order.

NaNs in float columns and masked values in integer columns are left out
before any statistic is computed, so `count` is the number of valid
values. Standard deviation uses the sample divisor (`ddof=1`). Integer
values are converted to `f32`.

Infinities are not left out. They follow IEEE arithmetic: `mean` becomes
`inf` or NaN, `std` becomes NaN, and a quartile that interpolates against
an infinity becomes `inf` or NaN. For `[1.0, inf, 3.0]` the result is
`[3.0, inf, NaN, 1.0, 2.0, NaN, inf, inf]`. Replace infinities before
calling `describe` if you need finite statistics.

The quartiles use linear interpolation, the pandas default: for quantile
`q` over the `c` sorted valid values, the position is `q * (c - 1)`, and a
fractional position interpolates between its two neighbors. For
`[1.0, 2.0, 3.0, 4.0]`, `25%`, `50%`, and `75%` are `1.75`, `2.5`, and
`3.25`, and `std` is `1.2909944`.

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

## Small and empty columns

| Valid values | Result column |
|---|---|
| None (all NaN or all masked) | `count` is `0.0`; the other seven rows are NaN |
| One | `std` is NaN; `mean`, `min`, the quartiles, and `max` equal that value |
| Two or more | Every row is a number |

For a column holding `5.0` and three NaNs, the result is
`[1.0, 5.0, NaN, 5.0, 5.0, 5.0, 5.0, 5.0]`.

`describe` is one of the functions that `chelis build` rejects; see
[limitations](../appendix/limitations.md).
