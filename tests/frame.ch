module Coral.Tests.Frame
import Std.Test (assert_true, assert_eq, assert_close)
import Coral.Frame (Frame, Column, FloatCol, StringCol, BoolCol, ColumnType, from_pairs, nrows, ncols, columns, filter, head, tail, slice, sort_by, with_column, drop_column, rename, concat, describe, get_float_col, get_int_col, get_bool_col, get_string_col, int_col_of_list)
def test_construction_nrows_ncols() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  _ = assert_eq(nrows(df), cast(3, i64), "nrows == 3")
  assert_eq(ncols(df), cast(1, i64), "ncols == 1")
}
def test_construction_multiple_cols() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))), ("b", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  _ = assert_eq(nrows(df), cast(3, i64), "nrows == 3")
  assert_eq(ncols(df), cast(2, i64), "ncols == 2")
}
def test_empty_tensor_columns_have_zero_rows() -> unit ! { Test } = {
  float_df = from_pairs([("value", FloatCol(to_tensor([])))])
  int_df = from_pairs([("value", int_col_of_list([]))])
  bool_df = from_pairs([("value", BoolCol(to_tensor([])))])
  string_df = from_pairs([("value", StringCol([]))])
  _ = assert_eq(nrows(float_df), cast(0, i64), "empty float tensor has zero rows")
  _ = assert_eq(nrows(int_df), cast(0, i64), "empty int tensor has zero rows")
  _ = assert_eq(nrows(bool_df), cast(0, i64), "empty bool tensor has zero rows")
  assert_eq(nrows(string_df), cast(0, i64), "empty string list has zero rows")
}
def test_head_tail_slice() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])))])
  h = head(df, cast(2, i64))
  t = tail(df, cast(2, i64))
  s = slice(df, cast(1, i64), cast(4, i64))
  _ = assert_eq(nrows(h), cast(2, i64), "head 2")
  _ = assert_eq(nrows(t), cast(2, i64), "tail 2")
  _ = assert_eq(nrows(s), cast(3, i64), "slice 1..4 has 3 rows")
  hv = to_list(get_float_col(h, "a"))
  _ = assert_eq(index(hv, cast(0, i64)), cast(1.0, f32), "head[0] == 1.0")
  _ = assert_eq(index(hv, cast(1, i64)), cast(2.0, f32), "head[1] == 2.0")
  tv = to_list(get_float_col(t, "a"))
  _ = assert_eq(index(tv, cast(0, i64)), cast(4.0, f32), "tail[0] == 4.0")
  assert_eq(index(tv, cast(1, i64)), cast(5.0, f32), "tail[1] == 5.0")
}
def test_with_column_then_drop() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  df2 = with_column(df, "b", FloatCol(to_tensor([cast(7.0, f32), cast(8.0, f32), cast(9.0, f32)])))
  _ = assert_eq(ncols(df2), cast(2, i64), "after with_column ncols == 2")
  df3 = drop_column(df2, "b")
  assert_eq(ncols(df3), cast(1, i64), "after drop_column ncols == 1")
}
def test_rename_changes_column_list() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  df2 = rename(df, "a", "b")
  names = columns(df2)
  _ = assert_eq(len(names), cast(1, i64), "one column after rename")
  assert_eq(index(names, cast(0, i64)), "b", "renamed column is 'b'")
}
def test_sort_by_float_ascending() -> unit ! { Test } = {
  df = from_pairs([("k", FloatCol(to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])))])
  sorted = sort_by(df, "k", true)
  vals = to_list(get_float_col(sorted, "k"))
  _ = assert_eq(index(vals, cast(0, i64)), cast(1.0, f32), "first is 1.0")
  _ = assert_eq(index(vals, cast(1, i64)), cast(2.0, f32), "middle is 2.0")
  assert_eq(index(vals, cast(2, i64)), cast(3.0, f32), "last is 3.0")
}
def test_sort_by_int_ascending() -> unit ! { Test } = {
  df = from_pairs([("k", int_col_of_list([cast(3, i64), cast(1, i64), cast(2, i64)]))])
  sorted = sort_by(df, "k", true)
  vals = to_list(get_int_col(sorted, "k"))
  _ = assert_eq(index(vals, cast(0, i64)), cast(1, i64), "first is 1")
  _ = assert_eq(index(vals, cast(1, i64)), cast(2, i64), "middle is 2")
  assert_eq(index(vals, cast(2, i64)), cast(3, i64), "last is 3")
}
def test_sort_by_bool_ascending() -> unit ! { Test } = {
  df = from_pairs([("k", BoolCol(to_tensor([true, false, true])))])
  sorted = sort_by(df, "k", true)
  vals = to_list(get_bool_col(sorted, "k"))
  _ = assert_eq(index(vals, cast(0, i64)), false, "first is false")
  _ = assert_eq(index(vals, cast(1, i64)), true, "middle is true")
  assert_eq(index(vals, cast(2, i64)), true, "last is true")
}
def test_sort_by_string_ascending() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", true)
  names = get_string_col(sorted, "city")
  _ = assert_eq(index(names, cast(0, i64)), "berlin", "first is berlin")
  _ = assert_eq(index(names, cast(1, i64)), "oslo", "middle is oslo")
  assert_eq(index(names, cast(2, i64)), "paris", "last is paris")
}
def test_sort_by_string_descending() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", false)
  names = get_string_col(sorted, "city")
  _ = assert_eq(index(names, cast(0, i64)), "paris", "first is paris")
  assert_eq(index(names, cast(2, i64)), "berlin", "last is berlin")
}
def test_concat_doubles_rows() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  out = concat([df, df])
  assert_eq(nrows(out), cast(6, i64), "concat doubles rows to 6")
}
def test_describe_returns_8_rows() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])))])
  d = describe(df)
  assert_eq(nrows(d), cast(8, i64), "describe always has 8 stat rows")
}
def test_filter_via_elementwise_threshold() -> unit ! { Test } = {
  df = from_pairs([("price", FloatCol(to_tensor([cast(10.0, f32), cast(50.0, f32), cast(100.0, f32), cast(200.0, f32), cast(300.0, f32)])))])
  mask = to_tensor(map(fn (value: f32) -> gt(value, 75.0f32), to_list(get_float_col(df, "price"))))
  kept = filter(df, mask)
  total = fold(fn (acc: f32, v: f32) -> add(acc, v), cast(0.0, f32), to_list(get_float_col(kept, "price")))
  _ = assert_eq(nrows(kept), cast(3, i64), "filter keeps 3 rows above 75")
  assert_close(total, cast(600.0, f32), cast(0.001, f32), "kept sum 100+200+300 == 600")
}
