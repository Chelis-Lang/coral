# Joins

`Coral.Join` currently covers string-key `inner_join` and `left_join`, with
results locked to checked-in pandas fixtures for the supported output slice.
The current implementation uses host-path equality matching rather than
sort-merge ordering.

```chelis
module Coral.BookJoin
import Coral.Frame (from_pairs, nrows)
import Coral.Join (left_join)
export (main)

def main() -> int64 = {
  left = from_pairs([
    ("customer", StringCol(["a", "b", "a"])),
    ("qty", IntCol(to_tensor([cast(1, int64), cast(2, int64), cast(3, int64)])))
  ])
  right = from_pairs([
    ("customer", StringCol(["a", "c"])),
    ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))
  ])
  nrows(left_join(left, right, "customer"))
}
```

Current scope notes:

- `inner_join` and `left_join` are validated
- right-hand key column duplication is suppressed
- overlapping right column names are suffixed with `_right`
- bool output columns from the joined right side are still deferred
- `outer_join` remains out of scope for the current pass

As with GroupBy, the current proof is fixture-backed plus compile-checked while
the upstream multi-module bare-build issue remains open.
