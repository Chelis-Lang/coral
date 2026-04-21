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
import Coral.Frame (from_pairs, get_float_col, nrows)
export (main)

def main() -> int64 = {
  prices = from_pairs([
    ("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))),
    ("name", StringCol(["a", "b", "c"]))
  ])
  nrows(prices)
}
```

```chelis
module Coral.Pat02
import Coral.Window (rolling_mean)
export (main)

def main() -> tensor[n, f32] =
  rolling_mean(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]), cast(2, int64))
```

## 4. Gotchas

- Prefer mask-first filtering over scalar predicate helpers.
- String grouping and joins use host-path equality logic.
- String `sort_by` is intentionally deferred.
- Reshape and Parquet are not first-pass features.

## 5. API Surface

- `Coral.Frame`: typed columns, accessors, filtering, sorting, mutation, NaN helpers
- `Coral.GroupBy`: grouping and aggregations
- `Coral.Join`: `inner_join`, `left_join`
- `Coral.Window`: rolling and EWM
- `Coral.IO`: CSV and JSON read/write
