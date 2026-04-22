# GroupBy

`Coral.GroupBy` currently validates a single-key aggregation slice against
checked-in pandas goldens. The current implementation uses host-path key
equality and preserves first-seen key order (`sort=False`-style behavior).

Validated operations in the current slice:

- `group_by`
- `agg_sum`
- `agg_mean`
- `agg_count`
- `agg_min`
- `agg_max`
- `agg` for explicit multi-aggregation specs in requested order

```chelis
module Coral.BookGroupBy
import Coral.Frame (from_pairs, nrows)
import Coral.GroupBy (group_by, agg)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("city", StringCol(["london", "paris", "london"])),
    ("qty", IntCol(to_tensor([cast(5, int64), cast(6, int64), cast(7, int64)]))),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))
  ])
  grouped = group_by(frame, "city")
  totals = agg(grouped, [("qty", AggSum), ("price", AggMean)])
  nrows(totals)
}
```

The honest gate today is fixture-backed plus compile-checked. Stripped bare
builds for GroupBy now link and run on `chelis v0.1.18`; a non-fatal Phase 0e
panic in `chelis build` is still tracked in `docs/UPSTREAM_BUGS.md`.
