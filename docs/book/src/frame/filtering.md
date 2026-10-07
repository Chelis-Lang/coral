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
and dtypes must match; see the
[Chelis operation reference](https://chelis.ch/docs/chelis/stdlib/).

The checker rejects a mask whose length differs from the frame's row
count, reporting `dimension mismatch: Lit(2) vs Lit(3)` for a two-entry
mask on a three-row frame. An all-false mask returns a frame with the same
columns and zero rows.

## Select rows by position

| Function | Signature | Rows kept |
|---|---|---|
| `head` | `(df: Frame[n], count: i64) -> Frame[k]` | The first `count` rows |
| `tail` | `(df: Frame[n], count: i64) -> Frame[k]` | The last `count` rows |
| `slice` | `(df: Frame[n], start: i64, finish: i64) -> Frame[k]` | Rows `start` up to but not including `finish` |

Counts and bounds are clamped rather than rejected. A negative `count`
keeps no rows; a `count` larger than the frame keeps every row. `slice`
clamps `start` to `0` and `finish` to the row count, and returns zero rows
when `finish <= start`. On a five-row frame, `head(f, 10)` keeps all five
rows, `head(f, -1)` and `slice(f, 3, 1)` keep none, and `slice(f, 1, 3)`
keeps rows 1 and 2.

## Sort rows

`sort_by(df: Frame[n], name: string, ascending: bool) -> Frame[n]`
reorders every column by the values in column `name`. A missing name fails
with `sort_by: column not found`.

- **Order.** An ascending sort keeps equal keys in their input order.
  `ascending = false` reverses the whole ascending result, so equal keys
  appear in reverse input order.
- **NaN.** Float NaNs sort after every number when ascending, and first
  when descending. Sorting `[3.0, NaN, 1.0, 2.0, 1.0]` ascending gives
  `[1.0, 1.0, 2.0, 3.0, NaN]`.
- **Integer masks.** A masked integer sorts by its stored number, usually
  `0`, not as a missing value.
- **Bool.** `false` sorts before `true`.
- **Strings.** Strings compare character by character with Coral's own
  ranking, not Unicode code points: lowercase `a` to `z`, then uppercase
  `A` to `Z`, then digits `0` to `9`, then `_ - . space % / : + * # @`.
  Every other character ranks after those and equal to the others. A
  prefix sorts before a longer string. Sorting
  `["b", "B", "a", "ab", "b", ""]` ascending gives
  `["", "a", "ab", "b", "b", "B"]`.
