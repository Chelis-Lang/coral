module Coral.Tests.Nan
import Std.Test (assert_true, assert_false, assert_eq, assert_close)
import Coral.Frame (Frame, Column, IntCol, FloatCol, from_pairs, nrows, ncols, get_float_col, get_int_col, fill_nan, drop_nan, is_nan, any_nan, count_nan, drop_nan_col)
def zero_i64() -> i64 = cast(0, i64)
def one_i64() -> i64 = cast(1, i64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def is_nan_scalar(x: f32) -> bool = neq(x, x)
def test_scalar_nan_self_inequality() -> unit ! { Test } = {
  nan = nan_f32()
  _ = assert_true(is_nan_scalar(nan), "NaN != NaN is true")
  _ = assert_false(is_nan_scalar(cast(1.0, f32)), "1.0 == 1.0 (not NaN)")
  assert_false(is_nan_scalar(cast(0.0, f32)), "0.0 == 0.0 (not NaN)")
}
def test_is_nan_detects_nan() -> unit ! { Test } = {
  t = to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32)])
  vals = to_list(t)
  _ = assert_eq(is_nan_scalar(index(vals, zero_i64())), false, "idx 0 not NaN")
  _ = assert_eq(is_nan_scalar(index(vals, one_i64())), true, "idx 1 is NaN")
  __borrow_migration_out_0 = assert_eq(is_nan_scalar(index(vals, cast(2, i64))), false, "idx 2 not NaN")
  __borrow_migration_out_0
}
def test_fill_nan_replaces_only_nan() -> unit ! { Test } = {
  t = to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32)])
  filled = fill_nan(t, cast(99.0, f32))
  vals = to_list(filled)
  _ = assert_close(index(vals, zero_i64()), cast(1.0, f32), cast(0.00001, f32), "idx 0 stays 1.0")
  _ = assert_close(index(vals, one_i64()), cast(99.0, f32), cast(0.00001, f32), "idx 1 becomes 99.0")
  __borrow_migration_out_1 = assert_close(index(vals, cast(2, i64)), cast(2.0, f32), cast(0.00001, f32), "idx 2 stays 2.0")
  __borrow_migration_out_1
}
def test_fill_nan_no_nans_is_identity() -> unit ! { Test } = {
  t = to_tensor([cast(1.5, f32), cast(2.5, f32), cast(3.5, f32)])
  filled = fill_nan(t, cast(-1.0, f32))
  vals = to_list(filled)
  _ = assert_close(index(vals, zero_i64()), cast(1.5, f32), cast(0.00001, f32), "idx 0 unchanged")
  _ = assert_close(index(vals, one_i64()), cast(2.5, f32), cast(0.00001, f32), "idx 1 unchanged")
  __borrow_migration_out_2 = assert_close(index(vals, cast(2, i64)), cast(3.5, f32), cast(0.00001, f32), "idx 2 unchanged")
  __borrow_migration_out_2
}
def test_fill_nan_all_nan_replaces_all() -> unit ! { Test } = {
  t = to_tensor([nan_f32(), nan_f32(), nan_f32()])
  filled = fill_nan(t, cast(7.0, f32))
  vals = to_list(filled)
  _ = assert_close(index(vals, zero_i64()), cast(7.0, f32), cast(0.00001, f32), "idx 0 filled 7.0")
  _ = assert_close(index(vals, one_i64()), cast(7.0, f32), cast(0.00001, f32), "idx 1 filled 7.0")
  __borrow_migration_out_3 = assert_close(index(vals, cast(2, i64)), cast(7.0, f32), cast(0.00001, f32), "idx 2 filled 7.0")
  __borrow_migration_out_3
}
def any_nan_scalar(values: List[f32]) -> bool = fold(fn (acc: bool, x: f32) -> or(acc, neq(x, x)), false, values)
def test_any_nan_true_when_present() -> unit ! { Test } = {
  with_nan = to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32)])
  without_nan = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  _ = assert_true(any_nan_scalar(to_list(with_nan)), "any NaN: true when present")
  __borrow_migration_out_4 = assert_false(any_nan_scalar(to_list(without_nan)), "any NaN: false when absent")
  __borrow_migration_out_4
}
def count_nan_scalar(values: List[f32]) -> i64 = fold(fn (acc: i64, x: f32) -> if neq(x, x) then add(acc, one_i64()) else acc, zero_i64(), values)
def test_count_nan_counts_nans() -> unit ! { Test } = {
  t = to_tensor([nan_f32(), cast(1.0, f32), nan_f32(), cast(2.0, f32)])
  c = count_nan_scalar(to_list(t))
  _ = assert_eq(c, cast(2, i64), "count of NaNs == 2")
  zeros = to_tensor([cast(1.0, f32), cast(2.0, f32)])
  __borrow_migration_out_0 = assert_eq(count_nan_scalar(to_list(zeros)), zero_i64(), "no NaNs in clean tensor")
  __borrow_migration_out_0
}
def test_nan_in_frame_float_col() -> unit ! { Test } = {
  df = from_pairs([("x", FloatCol(to_tensor([cast(1.0, f32), nan_f32(), cast(3.0, f32)])))])
  _ = assert_eq(nrows(df), cast(3, i64), "frame nrows == 3")
  vals = to_list(get_float_col(df, "x"))
  _ = assert_close(index(vals, zero_i64()), cast(1.0, f32), cast(0.00001, f32), "x[0] == 1.0")
  _ = assert_eq(is_nan_scalar(index(vals, one_i64())), true, "x[1] is NaN")
  assert_close(index(vals, cast(2, i64)), cast(3.0, f32), cast(0.00001, f32), "x[2] == 3.0")
}
def test_fill_nan_then_frame_roundtrip() -> unit ! { Test } = {
  raw = to_tensor([cast(1.0, f32), nan_f32(), cast(3.0, f32)])
  filled = fill_nan(raw, cast(0.0, f32))
  df = from_pairs([("x", FloatCol(filled))])
  vals = to_list(get_float_col(df, "x"))
  _ = assert_eq(nrows(df), cast(3, i64), "filled frame nrows == 3")
  _ = assert_close(index(vals, zero_i64()), cast(1.0, f32), cast(0.00001, f32), "x[0] == 1.0")
  _ = assert_close(index(vals, one_i64()), cast(0.0, f32), cast(0.00001, f32), "x[1] filled to 0.0")
  __borrow_migration_out_5 = assert_close(index(vals, cast(2, i64)), cast(3.0, f32), cast(0.00001, f32), "x[2] == 3.0")
  __borrow_migration_out_5
}
def test_is_nan_tensor_export() -> unit ! { Test } = {
  t = to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32), nan_f32(), cast(3.0, f32)])
  m = is_nan(t)
  cnt = fold(fn (acc: i64, x: bool) -> if x then add(acc, one_i64()) else acc, zero_i64(), to_list(m))
  _ = assert_eq(cnt, cast(2, i64), "tensor is_nan: two trues for two NaNs")
  bs = to_list(m)
  _ = assert_eq(index(bs, zero_i64()), false, "is_nan[0] == false (1.0 is not NaN)")
  __borrow_migration_out_6 = assert_eq(index(bs, one_i64()), true, "is_nan[1] == true (NaN)")
  __borrow_migration_out_6
}
def test_count_nan_tensor_export() -> unit ! { Test } = {
  t = to_tensor([nan_f32(), cast(1.0, f32), nan_f32(), cast(2.0, f32), nan_f32()])
  c = count_nan(t)
  _ = assert_eq(c, cast(3, i64), "count_nan: 3 NaNs")
  clean = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  __borrow_migration_out_7 = assert_eq(count_nan(clean), zero_i64(), "count_nan on clean tensor == 0")
  __borrow_migration_out_7
}
def test_any_nan_tensor_export() -> unit ! { Test } = {
  with_nan = to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32)])
  without_nan = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  _ = assert_true(any_nan(with_nan), "any_nan tensor: true when present")
  __borrow_migration_out_8 = assert_false(any_nan(without_nan), "any_nan tensor: false when absent")
  __borrow_migration_out_8
}
def test_drop_nan_uses_ieee_safe_mask() -> unit ! { Test } = {
  df = from_pairs([("value", FloatCol(to_tensor([cast(1.0, f32), nan_f32(), cast(2.0, f32)])))])
  kept = drop_nan(df, "value")
  values = to_list(get_float_col(kept, "value"))
  _ = assert_eq(nrows(kept), cast(2, i64), "drop_nan keeps two finite rows")
  _ = assert_close(index(values, zero_i64()), cast(1.0, f32), cast(0.00001, f32), "first finite value stays")
  assert_close(index(values, one_i64()), cast(2.0, f32), cast(0.00001, f32), "second finite value stays")
}
def test_drop_nan_col_uses_tensor_native_not() -> unit ! { Test } = {
  df = from_pairs([("value", IntCol(to_tensor([cast(10, i64), cast(20, i64), cast(30, i64)]), to_tensor([false, true, false])))])
  kept = drop_nan_col(df, "value")
  values = to_list(get_int_col(kept, "value"))
  _ = assert_eq(nrows(kept), cast(2, i64), "drop_nan_col keeps two unmasked rows")
  _ = assert_eq(index(values, zero_i64()), cast(10, i64), "first unmasked int stays")
  assert_eq(index(values, one_i64()), cast(30, i64), "second unmasked int stays")
}
