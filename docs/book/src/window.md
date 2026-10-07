# Rolling and exponentially weighted values

`Coral.Window` works on a one-dimensional `tensor[n, f32]` and returns a
tensor of the same length `n`. Take a column out of a frame with
`get_float_col` first.

| Function | Signature | Value at position `i` |
|---|---|---|
| `rolling_sum` | `(col: tensor[n, f32], window: i64) -> tensor[n, f32]` | Sum of the `window` values ending at `i` |
| `rolling_mean` | same | That sum divided by `window` |
| `rolling_std` | same | Sample standard deviation (`ddof=1`) of those values |
| `rolling_min` | same | Smallest of those values |
| `rolling_max` | same | Largest of those values |
| `ewm` | `(col: tensor[n, f32], alpha: f32) -> tensor[n, f32]` | `alpha * col[i] + (1 - alpha) * result[i - 1]`, with `result[0] = col[0]` |

The rolling functions put NaN at the first `window - 1` positions, which
come before the first full window. A window longer than the input gives all
NaN. `ewm` is the pandas `adjust=False` form.

```chelis
module Coral.BookWindow
import Coral.Window (rolling_mean)
export (main)
def main() -> f32 = {
  values = to_tensor([1.0f32, 2.0f32, 3.0f32, 4.0f32, 5.0f32])
  means = rolling_mean(values, 3i64)
  index(to_list(means), 4i64)
}
```

`main` returns `4.0`, the mean of `3.0`, `4.0`, and `5.0`.

For the input `[1.0, 2.0, 4.0, 8.0, 16.0]`, these calls return:

| Call | Result |
|---|---|
| `rolling_sum(v, 2)` | `[NaN, 3.0, 6.0, 12.0, 24.0]` |
| `rolling_std(v, 2)` | `[NaN, 0.70710677, 1.4142135, 2.828427, 5.656854]` |
| `rolling_min(v, 3)` | `[NaN, NaN, 1.0, 2.0, 4.0]` |
| `ewm(v, 0.5)` | `[1.0, 1.5, 2.75, 5.375, 10.6875]` |

## Input domain and edge cases

- **Window size.** Pass `window >= 1`. A negative window fails with
  `take requires non-negative count`. A window of `0` is not rejected but
  is meaningless: `rolling_sum` returns zeros, `rolling_mean` returns NaN,
  and `rolling_min` and `rolling_max` fail with an index error.
- **Window of one.** `rolling_std(v, 1)` is NaN everywhere, because the
  sample divisor `window - 1` is zero.
- **NaN inputs are not skipped.** Every window that contains a NaN gives
  NaN for all five rolling functions. For `[1.0, NaN, 3.0, 4.0, 5.0]`,
  `rolling_sum(v, 2)` is `[NaN, NaN, NaN, 7.0, 9.0]`. In `ewm`, a NaN makes
  that position and every later position NaN. Fill or drop NaNs first; see
  [Missing values](frame/nan-handling.md).
- **`alpha`.** Use a value in `(0, 1]`; `1` returns the input unchanged.
  Coral does not check the range: `ewm(v, 2.0)` runs and returns
  `[1.0, 3.0, 5.0, 11.0, 21.0]`, which is not a smoothed series.
- **Empty input.** `ewm` of an empty tensor returns an empty tensor.
