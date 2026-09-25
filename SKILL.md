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
import Coral.Frame (FloatCol, StringCol, BoolCol, from_pairs, nrows, ncols)
export (main)
def main() -> i64 = {
  prices = from_pairs([("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))), ("name", StringCol(["a", "b", "c"])), ("flag", BoolCol(neq(to_tensor([cast(1, i64), cast(0, i64), cast(1, i64)]), to_tensor([cast(0, i64), cast(0, i64), cast(0, i64)]))))])
  add(nrows(prices), ncols(prices))
}
```

```chelis
module Coral.Pat02
import Coral.Frame (BoolCol, from_pairs, filter, nrows, int_col_of_list)
export (main)
def main() -> i64 = {
  frame = from_pairs([("qty", int_col_of_list([cast(5, i64), cast(6, i64), cast(7, i64)])), ("flag", BoolCol(neq(to_tensor([cast(1, i64), cast(0, i64), cast(1, i64)]), to_tensor([cast(0, i64), cast(0, i64), cast(0, i64)]))))])
  kept = filter(frame, neq(to_tensor([cast(1, i64), cast(0, i64), cast(1, i64)]), to_tensor([cast(0, i64), cast(0, i64), cast(0, i64)])))
  nrows(kept)
}
```

```chelis
module Coral.Pat03
import Coral.Frame (FloatCol, from_pairs, rename, with_column, drop_column, columns, ncols, int_col_of_list)
export (main)
def main() -> i64 = {
  frame = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32)]))), ("qty", int_col_of_list([cast(2, i64), cast(3, i64)]))])
  renamed = rename(frame, "price", "cost")
  extended = with_column(renamed, "extra", int_col_of_list([cast(1, i64), cast(1, i64)]))
  trimmed = drop_column(extended, "qty")
  add(ncols(trimmed), len(columns(trimmed)))
}
```

```chelis
module Coral.Pat04
import Coral.Frame (FloatCol, from_pairs, fill_nan, drop_nan, concat, describe, nrows, get_float_col, int_col_of_list)
export (main)
def main() -> f32 = {
  base = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), div(cast(0.0, f32), cast(0.0, f32)), cast(30.0, f32)]))), ("qty", int_col_of_list([cast(1, i64), cast(2, i64), cast(3, i64)]))])
  filled = from_pairs([("price", FloatCol(fill_nan(get_float_col(base, "price"), cast(99.0, f32)))), ("qty", int_col_of_list([cast(1, i64), cast(2, i64), cast(3, i64)]))])
  stacked = concat([drop_nan(base, "price"), drop_nan(filled, "price")])
  desc = describe(stacked)
  add(cast(nrows(desc), f32), index(to_list(get_float_col(desc, "price")), cast(0, i64)))
}
```

```chelis
module Coral.Pat05
import Coral.Window (rolling_mean, rolling_std, ewm)
export (main)
def main() -> f32 = {
  values = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])
  means = rolling_mean(copy(values), cast(3, i64))
  stds = rolling_std(copy(values), cast(3, i64))
  smooth = ewm(values, cast(0.5, f32))
  mean_tail = index(to_list(copy(means)), cast(4, i64))
  std_tail = index(to_list(copy(stds)), cast(4, i64))
  smooth_tail = index(to_list(copy(smooth)), cast(4, i64))
  _ = drop(means)
  _ = drop(stds)
  _ = drop(smooth)
  add(mean_tail, add(std_tail, smooth_tail))
}
```

```chelis
module Coral.Pat06
import Coral.Frame (StringCol, from_pairs, nrows, int_col_of_list)
import Coral.GroupBy (group_by, agg_sum)
export (main)
def main() -> i64 = {
  frame = from_pairs([("city", StringCol(["london", "paris", "london"])), ("qty", int_col_of_list([cast(5, i64), cast(6, i64), cast(7, i64)]))])
  totals = agg_sum(group_by(frame, "city"), "qty")
  nrows(totals)
}
```

```chelis
module Coral.Pat07
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join)
export (main)
def main() -> i64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([cast(1, i64), cast(2, i64), cast(3, i64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(left_join(left, right, "customer"))
}
```

```chelis
module Coral.Pat08
import Coral.Frame (FloatCol, StringCol, BoolCol, from_pairs, ncols, int_col_of_list)
import Coral.Io (write_csv_frame, write_json_frame)
export (main)
def main() -> i64 = {
  frame = from_pairs([("id", int_col_of_list([cast(1, i64), cast(2, i64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))), ("flag", BoolCol(neq(to_tensor([cast(1, i64), cast(0, i64)]), to_tensor([cast(0, i64), cast(0, i64)])))), ("city", StringCol(["london", "paris"]))])
  csv_unit = write_csv_frame(frame, "skill-io.csv")
  json_unit = write_json_frame(frame, "skill-io.json")
  ncols(frame)
}
```

```chelis
module Coral.Pat09
import Coral.Frame (StringCol, from_pairs, nrows)
import Coral.GroupBy (value_counts)
export (main)
def main() -> i64 = {
  df = from_pairs([("city", StringCol(["london", "paris", "london"]))])
  vc = value_counts(df, "city")
  nrows(vc)
}
```

```chelis
module Coral.Pat10
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (outer_join)
export (main)
def main() -> i64 = {
  left = from_pairs([("customer", StringCol(["a", "b"])), ("qty", int_col_of_list([cast(1, i64), cast(2, i64)]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(40.0, f32)])))])
  nrows(outer_join(left, right, "customer"))
}
```

```chelis
module Coral.Pat11
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows)
import Coral.Reshape (melt)
export (main)
def main() -> i64 = {
  df = from_pairs([("city", StringCol(["london", "paris", "london"])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  melted = melt(df, ["city"], ["price"])
  nrows(melted)
}
```

## 4. Gotchas

- Integer columns use a two-field `IntCol(values, missing_mask)` representation;
  always construct them with `int_col_of_list([...])`, never
  `IntCol(to_tensor([...]))` directly.
- Integer missing values use the `_col` helpers, which take a Frame and a
  column name: `fill_nan_col`, `drop_nan_col`, `is_nan_col`, `any_nan_col`,
  `count_nan_col`. Float NaN uses the unsuffixed helpers, which take the float
  tensor from `get_float_col` (`drop_nan` takes a Frame and column name).
- Filtering is mask-first: build a `tensor[n, bool]` mask, then call
  `filter(df, mask)`.
- Tensor comparison operands must have matching shapes. To compare a column
  with a scalar threshold, map the scalar predicate over the column's
  elements and convert the resulting bool list to a tensor; a direct
  `gt(tensor, scalar)` is rejected (`tests_neg/frame/tensor_scalar_gt_neg.ch`).
- Grouping and joins match keys by host-side equality and keep first-seen key
  order (pandas `sort=False`). Keys may be int, float, or string columns.
- `agg` takes each value column at most once (coral#37), and its `AggCount`
  spec needs a float or int column (coral#38); use `agg_count` or
  `value_counts` for plain row counts.
- Bool columns are not supported as group keys. A bool non-key column fails
  every join, and a bool key fails `inner_join` and `left_join`
  (`spec/scope.md` deferrals D1 and D2).
- `outer_join` row order: matched and left-only rows in left order, then
  right-only rows appended. Its key column comes back as strings whatever the
  key type (deferral D9); `inner_join` and `left_join` keep the key type.
- Overlapping right-hand column names in a join get a `_right` suffix.
- `melt` is column-major: all rows for `value_cols[0]` come before
  `value_cols[1]`. `pivot` and `melt` take float value columns and string
  id/index columns only (deferral D4).
- `sort_by` works on int, float, bool, and string columns, ascending or
  descending; string order is lexicographic.
- `describe` summarizes int and float columns, skips string and bool columns,
  skips NaN and masked entries, and uses the sample standard deviation
  (`ddof=1`).
- Parquet is unavailable: `read_parquet_frame` and `write_parquet_frame`
  exist but fail at runtime (chelis#850).
- Only `Coral.Window`'s `rolling_mean` and `ewm` are compared with pandas by
  execution (`parity/run_parity.py`). The other modules' pandas goldens are
  references for the native tests in `tests/*.ch`, which run with
  `chelis test tests/ --jobs auto`.

## 5. API Surface

- `Coral.Frame`: `Column` (`IntCol`, `FloatCol`, `StringCol`, `BoolCol`),
  `from_pairs`, `from_columns`, `empty`, `int_col_of_list`; accessors
  `get_column`, `get_float_col`, `get_int_col`, `get_string_col`,
  `get_bool_col`, `columns`, `column_type`, `column_len`, `nrows`, `ncols`;
  `filter`, `head`, `tail`, `slice`, `sort_by`; `with_column`, `mutate`,
  `rename`, `drop_column`; float NaN `is_nan`, `fill_nan`, `drop_nan`,
  `any_nan`, `count_nan` and their integer `_col` forms; `concat`,
  `describe`.
- `Coral.GroupBy`: `group_by`, `agg_sum`, `agg_mean`, `agg_count`, `agg_min`,
  `agg_max`, `agg` with `AggFn` specs (`AggSum`, `AggMean`, `AggCount`,
  `AggMin`, `AggMax`), `value_counts`. Sum, mean, min, and max skip masked
  integer entries; counts include them.
- `Coral.Join`: `inner_join`, `left_join`, `outer_join`.
- `Coral.Reshape`: `pivot`, `melt`, `stack`, `unstack`.
- `Coral.Window`: `rolling_sum`, `rolling_mean`, `rolling_std`,
  `rolling_min`, `rolling_max`, `ewm`. Each maps `tensor[n, f32]` to
  `tensor[n, f32]`; the rolling functions return NaN until the window is full.
- `Coral.Io`: `read_csv_frame`, `write_csv_frame`, `read_json_frame`,
  `write_json_frame`; `read_parquet_frame` and `write_parquet_frame` fail at
  runtime.
- `Coral.AsOf`: `asof_lookup`, `asof_join` over `i64` key tensors and `f32`
  value tensors, and their host-list forms `asof_lookup_list`,
  `asof_join_list`.

`Coral.Frame.column_len[n](col: Column[n]) -> i64` returns the stored length
of a float, integer, string, or boolean column, including zero for empty columns.
