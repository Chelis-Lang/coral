# Sorted-key lookup

`Coral.AsOf` finds, for a requested `i64` key, the value attached to the
latest right-hand key at or before it. Its functions take keys and `f32`
values as tensors or lists; they do not take `Frame` values. A request
earlier than every right-hand key, or a lookup with no right-hand keys,
returns the fallback you pass.

| Function | Signature | Result |
|---|---|---|
| `asof_lookup` | `(keys: tensor[m, i64], values: tensor[m, f32], key: i64, fallback: f32) -> f32` | One value |
| `asof_join` | `(left_keys: tensor[n, i64], right_keys: tensor[m, i64], right_values: tensor[m, f32], fallback: f32) -> tensor[n, f32]` | One value per left key, in left order |
| `asof_lookup_list` | `(keys: List[i64], values: List[f32], key: i64, fallback: f32) -> f32` | One value |
| `asof_join_list` | `(left_keys: List[i64], right_keys: List[i64], right_values: List[f32], fallback: f32) -> List[f32]` | One value per left key |

Keys and values are one-dimensional. In the tensor forms, `right_keys` and
`right_values` share the length `m`, so the checker rejects tensors of
different lengths before the program runs:

```text
error: `Coral.AsOf.asof_join` argument 3, axis 0: expected 2, got 3
```

The list forms check at run time and fail with
`asof_lookup: key/value length mismatch`.

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

## Pitfalls

- **Sort the right-hand keys ascending.** The lookup scans right-hand keys
  from the start and stops at the first key greater than the request.
  Coral does not check the order, so unsorted keys give a wrong answer
  without an error: with right keys `[10, 30, 20]` and values
  `[1.0, 3.0, 2.0]`, a request for `25` returns `1.0`, not `2.0`.
- **Duplicate right-hand keys.** The last of the equal keys wins. With
  right keys `[10, 10, 20]` and values `[1.0, 2.0, 3.0]`, requests for `10`
  and `15` both return `2.0`.
- **Values pass through unchanged.** A NaN stored as a right-hand value is
  returned as NaN.
