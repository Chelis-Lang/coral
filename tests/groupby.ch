module Coral.Tests.GroupBy
import Std.Test (assert_eq, assert_close)
import Coral.Frame (Column, FloatCol, StringCol, ColumnType, Frame, from_pairs, nrows, ncols, get_float_col, get_int_col, get_string_col, columns, int_col_of_list)
import Coral.GroupBy (group_by, agg_sum, agg_mean, agg_min, agg_max, agg_count, value_counts, agg, AggSum, AggMean, AggMin, AggMax)
def zero_i64() -> i64 = cast(0, i64)
def one_i64() -> i64 = cast(1, i64)
def tensor_sum_f32[n](t: tensor[n, f32]) -> f32 = fold(fn (acc: f32, v: f32) -> add(acc, v), cast(0.0, f32), to_list(t))
def tensor_min_f32[n](t: tensor[n, f32]) -> f32 = {
  values = to_list(t)
  fold(fn (acc: f32, v: f32) -> if lt(v, acc) then v else acc, index(values, zero_i64()), skip(values, one_i64()))
}
def tensor_max_f32[n](t: tensor[n, f32]) -> f32 = {
  values = to_list(t)
  fold(fn (acc: f32, v: f32) -> if gt(v, acc) then v else acc, index(values, zero_i64()), skip(values, one_i64()))
}
def test_agg_sum_groups_correctly() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  total = tensor_sum_f32(get_float_col(result, "qty_sum"))
  _ = assert_eq(nrows(result), cast(2, i64), "agg_sum nrows == 2")
  _ = assert_eq(ncols(result), cast(2, i64), "agg_sum ncols == 2")
  assert_close(total, cast(6.0, f32), cast(0.00001, f32), "sum of group sums == 6.0")
}
def test_agg_min_max() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["x", "x", "x"])), ("qty", FloatCol(to_tensor([cast(5.0, f32), cast(2.0, f32), cast(8.0, f32)])))])
  min_result = agg_min(group_by(df, "city"), "qty")
  max_result = agg_max(group_by(df, "city"), "qty")
  min_val = tensor_min_f32(get_float_col(min_result, "qty_min"))
  max_val = tensor_max_f32(get_float_col(max_result, "qty_max"))
  _ = assert_eq(nrows(min_result), cast(1, i64), "agg_min nrows == 1")
  _ = assert_close(min_val, cast(2.0, f32), cast(0.00001, f32), "min == 2.0")
  _ = assert_eq(nrows(max_result), cast(1, i64), "agg_max nrows == 1")
  assert_close(max_val, cast(8.0, f32), cast(0.00001, f32), "max == 8.0")
}
def test_agg_mean_floats() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["g", "g", "g"])), ("price", FloatCol(to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])))])
  result = agg_mean(group_by(df, "city"), "price")
  v = index(to_list(get_float_col(result, "price_mean")), zero_i64())
  _ = assert_eq(nrows(result), cast(1, i64), "agg_mean nrows == 1")
  assert_close(v, cast(4.0, f32), cast(0.00001, f32), "mean of [2,4,6] == 4")
}
def test_agg_sum_returns_2_columns() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  assert_eq(ncols(result), cast(2, i64), "key + agg column == 2")
}
def test_agg_sum_distinct_groups_partition() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "b", "a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(10.0, f32), cast(100.0, f32), cast(1000.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  vs = get_float_col(result, "qty_sum")
  vmin = tensor_min_f32(vs)
  vmax = tensor_max_f32(vs)
  _ = assert_eq(nrows(result), cast(2, i64), "two distinct groups")
  _ = assert_close(vmin, cast(101.0, f32), cast(0.001, f32), "min group sum == 101 (a)")
  assert_close(vmax, cast(1010.0, f32), cast(0.001, f32), "max group sum == 1010 (b)")
}
def test_agg_mean_two_groups() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b", "b"])), ("price", FloatCol(to_tensor([cast(2.0, f32), cast(4.0, f32), cast(10.0, f32), cast(20.0, f32)])))])
  result = agg_mean(group_by(df, "city"), "price")
  vs = get_float_col(result, "price_mean")
  vmin = tensor_min_f32(vs)
  vmax = tensor_max_f32(vs)
  _ = assert_eq(nrows(result), cast(2, i64), "two groups")
  _ = assert_close(vmin, cast(3.0, f32), cast(0.00001, f32), "min group mean == 3 (a)")
  assert_close(vmax, cast(15.0, f32), cast(0.00001, f32), "max group mean == 15 (b)")
}
def test_agg_count_per_group() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b"]))])
  result = agg_count(group_by(df, "city"))
  counts = to_list(get_int_col(result, "count"))
  cmin = fold(fn (acc: i64, v: i64) -> if lt(v, acc) then v else acc, index(counts, zero_i64()), skip(counts, one_i64()))
  cmax = fold(fn (acc: i64, v: i64) -> if gt(v, acc) then v else acc, index(counts, zero_i64()), skip(counts, one_i64()))
  csum = fold(fn (acc: i64, v: i64) -> add(acc, v), zero_i64(), counts)
  _ = assert_eq(nrows(result), cast(2, i64), "two groups")
  _ = assert_eq(cmin, cast(1, i64), "smallest group has 1 element")
  _ = assert_eq(cmax, cast(2, i64), "largest group has 2 elements")
  assert_eq(csum, cast(3, i64), "counts sum to total rows")
}
def test_value_counts_distinct_keys() -> unit ! { Test } = {
  df = from_pairs([("k", StringCol(["a", "b", "a", "c", "a"]))])
  result = value_counts(df, "k")
  counts = to_list(get_int_col(result, "count"))
  cmax = fold(fn (acc: i64, v: i64) -> if gt(v, acc) then v else acc, index(counts, zero_i64()), skip(counts, one_i64()))
  csum = fold(fn (acc: i64, v: i64) -> add(acc, v), zero_i64(), counts)
  _ = assert_eq(nrows(result), cast(3, i64), "three unique keys")
  _ = assert_eq(cmax, cast(3, i64), "most frequent has 3 occurrences")
  assert_eq(csum, cast(5, i64), "counts sum to total rows")
}
def test_agg_multi_matches_pandas_golden() -> unit ! { Test } = {
  -- Input and expected values from parity/goldens/groupby/agg_multi_city.json,
  -- minus its row-count column, which agg cannot express yet (coral#37, coral#38).
  df = from_pairs([("city", StringCol(["london", "paris", "paris", "oslo", "london"])), ("qty", int_col_of_list([cast(5, i64), cast(6, i64), cast(7, i64), cast(8, i64), cast(9, i64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32), cast(40.0, f32), cast(50.0, f32)])))])
  result = agg(group_by(df, "city"), [("qty", AggSum), ("price", AggMean)])
  cities = get_string_col(result, "city")
  sums = to_list(get_int_col(result, "qty_sum"))
  means = to_list(get_float_col(result, "price_mean"))
  _ = assert_eq(columns(result), ["city", "qty_sum", "price_mean"], "key first, then specs in order")
  _ = assert_eq(cities, ["london", "paris", "oslo"], "first-seen key order")
  _ = assert_eq(sums, [cast(14, i64), cast(13, i64), cast(8, i64)], "qty sums per city")
  _ = assert_close(index(means, cast(0, i64)), cast(30.0, f32), cast(0.00001, f32), "london price mean")
  _ = assert_close(index(means, cast(1, i64)), cast(25.0, f32), cast(0.00001, f32), "paris price mean")
  assert_close(index(means, cast(2, i64)), cast(40.0, f32), cast(0.00001, f32), "oslo price mean")
}
def test_agg_multi_min_max_int_key() -> unit ! { Test } = {
  df = from_pairs([("store", int_col_of_list([cast(2, i64), cast(1, i64), cast(2, i64), cast(1, i64)])), ("price", FloatCol(to_tensor([cast(4.0, f32), cast(9.0, f32), cast(1.5, f32), cast(3.0, f32)]))), ("qty", int_col_of_list([cast(7, i64), cast(2, i64), cast(5, i64), cast(8, i64)]))])
  result = agg(group_by(df, "store"), [("price", AggMax), ("qty", AggMin)])
  stores = to_list(get_int_col(result, "store"))
  maxes = to_list(get_float_col(result, "price_max"))
  mins = to_list(get_int_col(result, "qty_min"))
  _ = assert_eq(columns(result), ["store", "price_max", "qty_min"], "key first, then specs in order")
  _ = assert_eq(stores, [cast(2, i64), cast(1, i64)], "first-seen int key order")
  _ = assert_close(index(maxes, cast(0, i64)), cast(4.0, f32), cast(0.00001, f32), "store 2 max price")
  _ = assert_close(index(maxes, cast(1, i64)), cast(9.0, f32), cast(0.00001, f32), "store 1 max price")
  assert_eq(mins, [cast(5, i64), cast(2, i64)], "min qty per store")
}
