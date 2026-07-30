# Rolling And EWM

`Coral.Window` is the first Coral module with a runtime-executed pandas parity
lane in the checked-in test harness.

Validated operations in the current slice:

- `rolling_sum`
- `rolling_mean`
- `rolling_std` using sample standard deviation (`ddof=1`)
- `rolling_min`
- `rolling_max`
- `ewm(alpha, adjust=False)`

Every operation has the shape contract
`tensor[n, f32] -> tensor[n, f32]`: rolling windows retain leading NaNs
rather than shortening the output, and EWM emits one value per input value.
The positive test suite and a mismatched-extent negative contract pin this
relationship at compile time.

```chelis
module Coral.BookWindow
import Coral.Window (rolling_mean, rolling_std, ewm)
export (main)
def main() -> f32 = {
  values = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  means = rolling_mean(copy(values), cast(3, int64))
  stds = rolling_std(copy(values), cast(3, int64))
  smooth = ewm(values, cast(0.5, f32))
  mean_tail = index(to_list(copy(means)), cast(4, int64))
  std_tail = index(to_list(copy(stds)), cast(4, int64))
  smooth_tail = index(to_list(copy(smooth)), cast(4, int64))
  _ = drop(means)
  _ = drop(stds)
  _ = drop(smooth)
  add(mean_tail, add(std_tail, smooth_tail))
}
```
