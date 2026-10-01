# Rolling and exponentially weighted values

`Coral.Window` works on a one-dimensional `tensor[n, f32]` and returns a
tensor with the same length. Its operations are `rolling_sum`,
`rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`, and `ewm`.
Use a positive rolling window; the positions before a full window is
available contain NaN. `rolling_std` uses sample standard deviation
(`ddof=1`). `ewm(values, alpha)` starts at the first input value and then
uses `alpha * value + (1 - alpha) * previous` (`adjust=False`); supply an
`alpha` between `0` and `1`.

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

`main` returns `4.0`, the mean of `3.0`, `4.0`, and `5.0`. The rolling
functions and `ewm` also have Chelis tests. Executed comparisons against
pandas through generated C cover `rolling_mean` and `ewm` on bare tensors;
they do not establish compiled `Frame` support or GPU behavior. See
[Pandas comparison](appendix/pandas_comparison.md) for the coverage boundary.
