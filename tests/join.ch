module Coral.Tests.Join
import Std.Test (assert_eq_int, assert_close)
import Coral.Frame (Column, Frame, from_pairs, nrows, ncols, get_float_col)
import Coral.Join (inner_join, left_join, outer_join)
def zero_i64() -> int64 = cast(0, int64)
def tensor_sum_f32[n](t: tensor[n, f32]) -> f32 = { fold(fn (acc: f32, v: f32) -> add(acc, v), cast(0.0, f32), to_list(t)) }
def tensor_sum_skip_nan[n](t: tensor[n, f32]) -> f32 = { fold(fn (acc: f32, v: f32) -> if neq(v, v) then acc else add(acc, v), cast(0.0, f32), to_list(t)) }
def test_inner_join_keeps_intersection() -> unit ! { Test } = {
  left = from_pairs([("customer", StringCol(["a", "b", "c"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  right = from_pairs([("customer", StringCol(["b", "c", "d"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  result = inner_join(left, right, "customer")
  qty_sum = tensor_sum_f32(get_float_col(result, "qty"))
  score_sum = tensor_sum_f32(get_float_col(result, "score"))
  _ = assert_eq_int(nrows(result), cast(2, int64), "inner join produces 2 matching rows")
  _ = assert_eq_int(ncols(result), cast(3, int64), "inner join produces customer + qty + score")
  _ = assert_close(qty_sum, cast(5.0, f32), cast(0.00001, f32), "kept qty values are 2 and 3 -> sum 5")
  assert_close(score_sum, cast(30.0, f32), cast(0.00001, f32), "kept score values are 10 and 20 -> sum 30")
}
def test_left_join_keeps_left_rows() -> unit ! { Test } = {
  left = from_pairs([("customer", StringCol(["a", "b", "c"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  right = from_pairs([("customer", StringCol(["b", "c", "d"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  result = left_join(left, right, "customer")
  qty_sum = tensor_sum_f32(get_float_col(result, "qty"))
  score_sum = tensor_sum_skip_nan(get_float_col(result, "score"))
  _ = assert_eq_int(nrows(result), cast(3, int64), "left join keeps all 3 left rows")
  _ = assert_eq_int(ncols(result), cast(3, int64), "left join produces customer + qty + score")
  _ = assert_close(qty_sum, cast(6.0, f32), cast(0.00001, f32), "qty 1 + 2 + 3 == 6")
  assert_close(score_sum, cast(30.0, f32), cast(0.00001, f32), "score skip-NaN: 10 + 20 == 30")
}
def test_outer_join_keeps_union() -> unit ! { Test } = {
  left = from_pairs([("customer", StringCol(["a", "b", "c"])), ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  right = from_pairs([("customer", StringCol(["b", "c", "d"])), ("score", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  result = outer_join(left, right, "customer")
  qty_sum = tensor_sum_skip_nan(get_float_col(result, "qty"))
  score_sum = tensor_sum_skip_nan(get_float_col(result, "score"))
  _ = assert_eq_int(nrows(result), cast(4, int64), "outer join produces 4 union rows")
  _ = assert_eq_int(ncols(result), cast(3, int64), "outer join produces customer + qty + score")
  _ = assert_close(qty_sum, cast(6.0, f32), cast(0.00001, f32), "qty skip-NaN sum == 6")
  assert_close(score_sum, cast(60.0, f32), cast(0.00001, f32), "score skip-NaN sum == 60")
}
def test_inner_join_one_match() -> unit ! { Test } = {
  left = from_pairs([("k", StringCol(["a", "b"])), ("v", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)])))])
  right = from_pairs([("k", StringCol(["b", "c"])), ("w", FloatCol(to_tensor([cast(20.0, f32), cast(30.0, f32)])))])
  result = inner_join(left, right, "k")
  v_sum = tensor_sum_f32(get_float_col(result, "v"))
  w_sum = tensor_sum_f32(get_float_col(result, "w"))
  _ = assert_eq_int(nrows(result), cast(1, int64), "single key matches")
  _ = assert_eq_int(ncols(result), cast(3, int64), "k + v + w == 3 cols")
  _ = assert_close(v_sum, cast(2.0, f32), cast(0.00001, f32), "v of matched row 'b' == 2")
  assert_close(w_sum, cast(20.0, f32), cast(0.00001, f32), "w of matched row 'b' == 20")
}
def test_inner_join_two_value_cols() -> unit ! { Test } = {
  left = from_pairs([("k", StringCol(["a", "b"])), ("v", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)])))])
  right = from_pairs([("k", StringCol(["a", "b", "c"])), ("w", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  result = inner_join(left, right, "k")
  v_sum = tensor_sum_f32(get_float_col(result, "v"))
  w_sum = tensor_sum_f32(get_float_col(result, "w"))
  _ = assert_eq_int(nrows(result), cast(2, int64), "two matches")
  _ = assert_eq_int(ncols(result), cast(3, int64), "k + v + w == 3 cols")
  _ = assert_close(v_sum, cast(3.0, f32), cast(0.00001, f32), "v sum 1 + 2 == 3 (left side preserved)")
  assert_close(w_sum, cast(30.0, f32), cast(0.00001, f32), "w sum 10 + 20 == 30 (right side independent of left)")
}
def test_inner_join_self_row_count() -> unit ! { Test } = {
  df = from_pairs([("k", StringCol(["a", "b"])), ("v", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)])))])
  result = inner_join(df, df, "k")
  _ = assert_eq_int(nrows(result), cast(2, int64), "self join keeps each row")
  assert_eq_int(ncols(result), cast(3, int64), "self join: k + v + v_right")
}
