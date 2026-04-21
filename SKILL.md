# Coral SKILL.md

## 1. Identity

Coral is the typed dataframe shell for Chelis.
It targets pandas-style data manipulation with typed column access,
numeric tensor columns, and host-path string operations.

## 2. Import Patterns

### Surf

```chelis-fragment
import Coral.Frame (Frame, from_pairs, get_float_col, filter, sort_by, with_column)
import Coral.GroupBy (group_by, agg_sum, agg_mean, agg_count)
import Coral.Join (inner_join, left_join)
import Coral.Window (rolling_mean, ewm)
import Coral.IO (read_csv_frame, write_csv_frame, read_json_frame, write_json_frame)
```

### Deep

```deep-fragment
(import {} coral.frame (from_pairs get_float_col filter sort_by with_column))
(import {} coral.groupby (group_by agg_sum agg_mean agg_count))
(import {} coral.join (inner_join left_join))
(import {} coral.window (rolling_mean ewm))
```

## 3. Core Patterns

```chelis
module Coral.Pat01
import Coral.Frame (from_pairs, nrows, ncols)
export (main)

def main() -> int64 = {
  prices = from_pairs([
    ("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))),
    ("name", StringCol(["a", "b", "c"])),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)]))))
  ])
  add(nrows(prices), ncols(prices))
}
```

```chelis
module Coral.Pat02
import Coral.Frame (from_pairs, filter, nrows)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("qty", IntCol(to_tensor([cast(5, int64), cast(6, int64), cast(7, int64)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)]))))
  ])
  kept = filter(frame, neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)])))
  nrows(kept)
}
```

```chelis
module Coral.Pat03
import Coral.Frame (from_pairs, rename, with_column, drop_column, columns, ncols)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32)]))),
    ("qty", IntCol(to_tensor([cast(2, int64), cast(3, int64)])))
  ])
  renamed = rename(frame, "price", "cost")
  extended = with_column(renamed, "extra", IntCol(to_tensor([cast(1, int64), cast(1, int64)])))
  trimmed = drop_column(extended, "qty")
  add(ncols(trimmed), len(columns(trimmed)))
}
```

```chelis
module Coral.Pat04
import Coral.Frame (from_pairs, fill_nan, drop_nan, concat, describe, nrows, get_float_col)
export (main)

def main() -> f32 = {
  base = from_pairs([
    ("price", FloatCol(to_tensor([cast(10.0, f32), div(cast(0.0, f32), cast(0.0, f32)), cast(30.0, f32)]))),
    ("qty", IntCol(to_tensor([cast(1, int64), cast(2, int64), cast(3, int64)])))
  ])
  filled = from_pairs([
    ("price", FloatCol(fill_nan(get_float_col(base, "price"), cast(99.0, f32)))),
    ("qty", IntCol(to_tensor([cast(1, int64), cast(2, int64), cast(3, int64)])))
  ])
  stacked = concat([drop_nan(base, "price"), drop_nan(filled, "price")])
  desc = describe(stacked)
  add(cast(nrows(desc), f32), index(to_list(get_float_col(desc, "price")), cast(0, int64)))
}
```

## 4. Gotchas

- Prefer mask-first filtering over scalar predicate helpers.
- The current validated frame slice is `from_pairs`, typed access, filter, head/tail/slice, mutation, NaN helpers, concat, and `describe`.
- String grouping and joins use host-path equality logic.
- String `sort_by` is intentionally deferred.
- Reshape and Parquet are not first-pass features.
- `describe` follows pandas-style NaN skipping for float columns and uses sample standard deviation (`ddof=1`).
- End-to-end runtime proof for reef-importing HAMT-backed Coral builds is still blocked on `chelis v0.1.13`; compile-level probes are the honest gate today.

## 5. API Surface

- `Coral.Frame`: typed columns, accessors, filtering, sorting, mutation, NaN helpers, concat, `describe`
- `Coral.GroupBy`: grouping and aggregations
- `Coral.Join`: `inner_join`, `left_join`
- `Coral.Window`: rolling and EWM
- `Coral.IO`: CSV and JSON read/write
