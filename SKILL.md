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

```chelis
module Coral.Pat05
import Coral.Window (rolling_mean, rolling_std, ewm)
export (main)

def main() -> f32 = {
  values = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  means = rolling_mean(values, cast(3, int64))
  stds = rolling_std(values, cast(3, int64))
  smooth = ewm(values, cast(0.5, f32))
  add(index(to_list(means), cast(4, int64)), add(index(to_list(stds), cast(4, int64)), index(to_list(smooth), cast(4, int64))))
}
```

```chelis
module Coral.Pat06
import Coral.Frame (from_pairs, nrows)
import Coral.GroupBy (group_by, agg_sum)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("city", StringCol(["london", "paris", "london"])),
    ("qty", IntCol(to_tensor([cast(5, int64), cast(6, int64), cast(7, int64)])))
  ])
  totals = agg_sum(group_by(frame, "city"), "qty")
  nrows(totals)
}
```

```chelis
module Coral.Pat07
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

```chelis
module Coral.Pat08
import Coral.Frame (from_pairs, ncols)
import Coral.IO (write_csv_frame, write_json_frame)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("id", IntCol(to_tensor([cast(1, int64), cast(2, int64)]))),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)])))),
    ("city", StringCol(["london", "paris"]))
  ])
  csv_unit = write_csv_frame(frame, "skill-io.csv")
  json_unit = write_json_frame(frame, "skill-io.json")
  ncols(frame)
}
```

## 4. Gotchas

- Prefer mask-first filtering over scalar predicate helpers.
- The current validated frame slice is `from_pairs`, typed access, filter, head/tail/slice, mutation, NaN helpers, concat, and `describe`.
- String grouping and joins use host-path equality logic.
- String `sort_by` is intentionally deferred.
- Reshape and Parquet are not first-pass features.
- `describe` follows pandas-style NaN skipping for float columns and uses sample standard deviation (`ddof=1`).
- `Coral.IO` is currently fixture-backed plus compile-checked; it does not yet have an executed runtime parity lane.
- `Coral.Window` currently has the strongest executed parity story: pandas-backed goldens plus a runtime build/link/execute test lane.
- End-to-end runtime proof for stripped Frame/GroupBy/Join bare builds is still blocked on `chelis v0.1.17`; compile-level probes remain the honest gate for those paths today.

## 5. API Surface

- `Coral.Frame`: typed columns, accessors, filtering, sorting, mutation, NaN helpers, concat, `describe`
- `Coral.GroupBy`: grouping and aggregations
- `Coral.Join`: `inner_join`, `left_join`
- `Coral.Window`: rolling and EWM
- `Coral.IO`: CSV and JSON read/write
