module Coral.Tests.GroupBy
import Std.Test (assert_eq, assert_close)
import Coral.Frame (Column, FloatCol, StringCol, ColumnType, Frame, from_pairs, nrows, ncols, get_float_col, get_int_col)
import Coral.GroupBy (group_by, agg_sum, agg_mean, agg_min, agg_max, agg_count, value_counts)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def tensor_sum_f32[n](t: tensor[n, f32]) -> f32 = fold(fn (acc: f32, v: f32) -> add(acc, v), cast(0.0, f32), to_list(t))
def tensor_min_f32[n](t: tensor[n, f32]) -> f32 = {
  values = to_list(t)
  fold(fn (acc: f32, v: f32) -> if lt(v, acc) then v else acc, index(values, zero_i64()), drop(values, one_i64()))
}
def tensor_max_f32[n](t: tensor[n, f32]) -> f32 = {
  values = to_list(t)
  fold(fn (acc: f32, v: f32) -> if gt(v, acc) then v else acc, index(values, zero_i64()), drop(values, one_i64()))
}
def test_agg_sum_groups_correctly() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  total = tensor_sum_f32(get_float_col(result, "qty_sum"))
  _ = assert_eq(nrows(result), cast(2, int64), "agg_sum nrows == 2")
  _ = assert_eq(ncols(result), cast(2, int64), "agg_sum ncols == 2")
  assert_close(total, cast(6.0, f32), cast(0.00001, f32), "sum of group sums == 6.0")
}
def test_agg_min_max() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["x", "x", "x"])), ("qty", FloatCol(to_tensor([cast(5.0, f32), cast(2.0, f32), cast(8.0, f32)])))])
  min_result = agg_min(group_by(df, "city"), "qty")
  max_result = agg_max(group_by(df, "city"), "qty")
  min_val = tensor_min_f32(get_float_col(min_result, "qty_min"))
  max_val = tensor_max_f32(get_float_col(max_result, "qty_max"))
  _ = assert_eq(nrows(min_result), cast(1, int64), "agg_min nrows == 1")
  _ = assert_close(min_val, cast(2.0, f32), cast(0.00001, f32), "min == 2.0")
  _ = assert_eq(nrows(max_result), cast(1, int64), "agg_max nrows == 1")
  assert_close(max_val, cast(8.0, f32), cast(0.00001, f32), "max == 8.0")
}
def test_agg_mean_floats() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["g", "g", "g"])), ("price", FloatCol(to_tensor([cast(2.0, f32), cast(4.0, f32), cast(6.0, f32)])))])
  result = agg_mean(group_by(df, "city"), "price")
  v = index(to_list(get_float_col(result, "price_mean")), zero_i64())
  _ = assert_eq(nrows(result), cast(1, int64), "agg_mean nrows == 1")
  assert_close(v, cast(4.0, f32), cast(0.00001, f32), "mean of [2,4,6] == 4")
}
def test_agg_sum_returns_2_columns() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  assert_eq(ncols(result), cast(2, int64), "key + agg column == 2")
}
def test_agg_sum_distinct_groups_partition() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "b", "a", "b"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(10.0, f32), cast(100.0, f32), cast(1000.0, f32)])))])
  result = agg_sum(group_by(df, "city"), "qty")
  vs = get_float_col(result, "qty_sum")
  vmin = tensor_min_f32(vs)
  vmax = tensor_max_f32(vs)
  _ = assert_eq(nrows(result), cast(2, int64), "two distinct groups")
  _ = assert_close(vmin, cast(101.0, f32), cast(0.001, f32), "min group sum == 101 (a)")
  assert_close(vmax, cast(1010.0, f32), cast(0.001, f32), "max group sum == 1010 (b)")
}
def test_agg_mean_two_groups() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b", "b"])), ("price", FloatCol(to_tensor([cast(2.0, f32), cast(4.0, f32), cast(10.0, f32), cast(20.0, f32)])))])
  result = agg_mean(group_by(df, "city"), "price")
  vs = get_float_col(result, "price_mean")
  vmin = tensor_min_f32(vs)
  vmax = tensor_max_f32(vs)
  _ = assert_eq(nrows(result), cast(2, int64), "two groups")
  _ = assert_close(vmin, cast(3.0, f32), cast(0.00001, f32), "min group mean == 3 (a)")
  assert_close(vmax, cast(15.0, f32), cast(0.00001, f32), "max group mean == 15 (b)")
}
def test_agg_count_per_group() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["a", "a", "b"]))])
  result = agg_count(group_by(df, "city"))
  counts = to_list(get_int_col(result, "count"))
  cmin = fold(fn (acc: int64, v: int64) -> if lt(v, acc) then v else acc, index(counts, zero_i64()), drop(counts, one_i64()))
  cmax = fold(fn (acc: int64, v: int64) -> if gt(v, acc) then v else acc, index(counts, zero_i64()), drop(counts, one_i64()))
  csum = fold(fn (acc: int64, v: int64) -> add(acc, v), zero_i64(), counts)
  _ = assert_eq(nrows(result), cast(2, int64), "two groups")
  _ = assert_eq(cmin, cast(1, int64), "smallest group has 1 element")
  _ = assert_eq(cmax, cast(2, int64), "largest group has 2 elements")
  assert_eq(csum, cast(3, int64), "counts sum to total rows")
}
def test_value_counts_distinct_keys() -> unit ! { Test } = {
  df = from_pairs([("k", StringCol(["a", "b", "a", "c", "a"]))])
  result = value_counts(df, "k")
  counts = to_list(get_int_col(result, "count"))
  cmax = fold(fn (acc: int64, v: int64) -> if gt(v, acc) then v else acc, index(counts, zero_i64()), drop(counts, one_i64()))
  csum = fold(fn (acc: int64, v: int64) -> add(acc, v), zero_i64(), counts)
  _ = assert_eq(nrows(result), cast(3, int64), "three unique keys")
  _ = assert_eq(cmax, cast(3, int64), "most frequent has 3 occurrences")
  assert_eq(csum, cast(5, int64), "counts sum to total rows")
}
