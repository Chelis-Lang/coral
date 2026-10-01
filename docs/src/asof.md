# Sorted-key lookup

`Coral.AsOf` finds the latest key at or before a requested `i64` key. Its
functions take key tensors or lists and `f32` values; they do not take
`Frame` values. Keep the right-hand keys in ascending order. Coral does
not check that order. Supply a fallback value for a request before the
first right-hand key.

- `asof_lookup(keys, values, key, fallback)` returns one `f32` value.
- `asof_join(left_keys, right_keys, right_values, fallback)` returns an
  `f32` tensor with one result for each left key.
- `asof_lookup_list` and `asof_join_list` offer the same operations on
  host lists.

```chelis
module Coral.BookAsOf
import Coral.AsOf (asof_join)
export (main)
def main() -> f32 = {
  left_keys = to_tensor([5i64, 10i64, 25i64, 35i64])
  right_keys = to_tensor([10i64, 20i64, 30i64])
  values = to_tensor([1.0f32, 2.0f32, 3.0f32])
  matches = asof_join(left_keys, right_keys, values, -1.0f32)
  index(to_list(matches), 2i64)
}
```

The four matches are `-1.0`, `1.0`, `2.0`, and `3.0`; `main` returns
`2.0`.
