# Coral SKILL.md

## 1. Identity

Coral is the typed dataframe shell for Chelis.
It targets pandas-style data manipulation with typed column access,
numeric tensor columns, and host-path string operations.

## 2. Import Patterns

### Surf

```chelis-fragment
import Coral.Frame (Frame, from_pairs, get_float_col, filter, sort_by, with_column, int_col_of_list)
import Coral.GroupBy (group_by, agg_sum, agg_mean, agg_count, value_counts)
import Coral.Join (inner_join, left_join, outer_join)
import Coral.Reshape (pivot, melt, stack, unstack)
import Coral.Window (rolling_mean, ewm)
import Coral.Io (read_csv_frame, write_csv_frame, read_json_frame, write_json_frame)
import Coral.PlayerData (team_starting_strength_fixture)
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
  prices = from_pairs([("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))), ("name", StringCol(["a", "b", "c"])), ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)]))))])
  add(nrows(prices), ncols(prices))
}
```

```chelis
module Coral.Pat02
import Coral.Frame (from_pairs, filter, nrows, int_col_of_list)
export (main)
def main() -> int64 = {
  frame = from_pairs([("qty", int_col_of_list([cast(5, int64), cast(6, int64), cast(7, int64)])), ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)]))))])
  kept = filter(frame, neq(to_tensor([cast(1, int64), cast(0, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64), cast(0, int64)])))
  nrows(kept)
}
```

```chelis
module Coral.Pat03
import Coral.Frame (from_pairs, rename, with_column, drop_column, columns, ncols, int_col_of_list)
export (main)
def main() -> int64 = {
  frame = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32)]))), ("qty", int_col_of_list([cast(2, int64), cast(3, int64)]))])
  renamed = rename(frame, "price", "cost")
  extended = with_column(renamed, "extra", int_col_of_list([cast(1, int64), cast(1, int64)]))
  trimmed = drop_column(extended, "qty")
  add(ncols(trimmed), len(columns(trimmed)))
}
```

```chelis
module Coral.Pat04
import Coral.Frame (from_pairs, fill_nan, drop_nan, concat, describe, nrows, get_float_col, int_col_of_list)
export (main)
def main() -> f32 = {
  base = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), div(cast(0.0, f32), cast(0.0, f32)), cast(30.0, f32)]))), ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))])
  filled = from_pairs([("price", FloatCol(fill_nan(get_float_col(base, "price"), cast(99.0, f32)))), ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))])
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

```chelis
module Coral.Pat06
import Coral.Frame (from_pairs, nrows, int_col_of_list)
import Coral.GroupBy (group_by, agg_sum)
export (main)
def main() -> int64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "london"])), ("qty", int_col_of_list([cast(5, int64), cast(6, int64), cast(7, int64)]))])
  totals = agg_sum(group_by(frame, "city"), "qty")
  nrows(totals)
}
```

```chelis
module Coral.Pat07
import Coral.Frame (from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join)
export (main)
def main() -> int64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(left_join(left, right, "customer"))
}
```

```chelis
module Coral.Pat08
import Coral.Frame (from_pairs, ncols, int_col_of_list)
import Coral.Io (write_csv_frame, write_json_frame)
export (main)
def main() -> int64 = {
  frame = from_pairs([("id", int_col_of_list([cast(1, int64), cast(2, int64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))), ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)])))), ("city", StringCol(["london", "paris"]))])
  csv_unit = write_csv_frame(frame, "skill-io.csv")
  json_unit = write_json_frame(frame, "skill-io.json")
  ncols(frame)
}
```

```chelis
module Coral.Pat09
import Coral.Frame (from_pairs, nrows)
import Coral.GroupBy (value_counts)
export (main)
def main() -> int64 = {
  df = from_pairs([("city", StringCol(["london", "paris", "london"]))])
  vc = value_counts(df, "city")
  nrows(vc)
}
```

```chelis
module Coral.Pat10
import Coral.Frame (from_pairs, nrows, int_col_of_list)
import Coral.Join (outer_join)
export (main)
def main() -> int64 = {
  left = from_pairs([("customer", StringCol(["a", "b"])), ("qty", int_col_of_list([cast(1, int64), cast(2, int64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(outer_join(left, right, "customer"))
}
```

```chelis
module Coral.Pat11
import Coral.Frame (from_pairs, nrows)
import Coral.Reshape (melt)
export (main)
def main() -> int64 = {
  df = from_pairs([("city", StringCol(["london", "paris", "london"])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  melted = melt(df, ["city"], ["price"])
  nrows(melted)
}
```

## 4. Gotchas

- Integer columns use a two-field `IntCol(values, bool_mask)` representation; always use
  `int_col_of_list([...])` to construct int columns — never `IntCol(to_tensor([...]))` directly.
- Integer NaN uses `_col` suffix helpers (column-form variants taking a Frame +
  column name): `fill_nan_col`, `drop_nan_col`, `is_nan_col`, `any_nan_col`,
  `count_nan_col`. Float NaN uses the non-suffixed versions (operate on tensors).
- Prefer mask-first filtering over scalar predicate helpers.
- String grouping and joins use host-path equality logic (not sort-merge).
- String `sort_by` is supported and golden-validated: lexicographic ascending and descending, with runtime parity for the insertion sort and comparison path.
- `outer_join` row order: left-sequential first, then right-only rows appended.
- `melt` is column-major: all rows for value_col[0] appear before value_col[1].
- Parquet is upstream-blocked (`import Std.Io.Parquet` resolves at check time on v0.7.6, but the runtime path is still not callable; functions intentionally fail).
- `describe` skips NaN for float columns and masked entries for int columns; uses sample std (`ddof=1`).
- `Coral.Window` and `Coral.Frame` both have an executed runtime parity lane: pandas goldens + runtime build/link/execute lane (in `parity/run_parity.py`). GroupBy, Join, and IO are fixture-backed plus compile-checked.
- Stripped Frame/GroupBy/Join bare builds are fully clean on `chelis v0.7.6`.
- Tests in `tests/*.ch` run via `chelis test tests/ --jobs auto` (chelis v0.7.6) and assert mathematical identities, hand-computed values, structural properties, and round-trip identities. Pandas comparison work lives in `parity/`.
- `chelis test` evaluator gap is fully resolved as of v0.3.1: tensor-tensor `eq`/`neq`/`lt`/`gt` (since v0.2.5), `to_tensor([bool, ...])`, and tensor-scalar `gt(tensor, scalar)` (since v0.3.1) all work. IntCol construction, `is_nan`/`any_nan`/`count_nan` tensor exports, `agg_count`, `value_counts`, int CSV round-trip, and bool CSV/JSON round-trips all run end-to-end via `chelis test`.

## 5. API Surface

- `Coral.Frame`: typed columns, accessors, filtering, sorting, mutation (`mutate`/`with_column`), int+float NaN helpers, concat, `describe`, `int_col_of_list`
- `Coral.GroupBy`: `group_by`, aggregations (sum/mean/count/min/max), `value_counts`; masked int rows skipped in agg
- `Coral.Join`: `inner_join`, `left_join`, `outer_join`
- `Coral.Reshape`: `pivot`, `melt`, `stack`, `unstack`
- `Coral.Window`: `rolling_mean`, `rolling_std`, `rolling_max`, `ewm`
- `Coral.Io`: CSV + JSON read/write; Parquet upstream-blocked
- `Coral.PlayerData`: deterministic placeholder `match_lineup`, `recent_form`,
  `team_starting_strength`, `team_starting_strength_fixture`, and
  `position_distribution` accessors for football-specific probes
