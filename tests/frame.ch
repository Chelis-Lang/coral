module Coral.Tests.Frame
import Std.Test (assert_true, assert_eq, assert_eq_int, assert_eq_string, assert_close)
import Coral.Frame (
  Frame, Column, ColumnType,
  from_pairs, nrows, ncols, columns,
  head, tail, slice, sort_by,
  with_column, drop_column, rename,
  concat, describe,
  get_float_col, get_string_col
)

def test_construction_nrows_ncols() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  _ = assert_eq_int(nrows(df), cast(3, int64), "nrows == 3");
  assert_eq_int(ncols(df), cast(1, int64), "ncols == 1")
}

def test_construction_multiple_cols() -> unit ! { Test } = {
  df = from_pairs([
    ("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))),
    ("b", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))
  ])
  _ = assert_eq_int(nrows(df), cast(3, int64), "nrows == 3");
  assert_eq_int(ncols(df), cast(2, int64), "ncols == 2")
}

def test_head_tail_slice() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])))])
  h = head(df, cast(2, int64))
  t = tail(df, cast(2, int64))
  s = slice(df, cast(1, int64), cast(4, int64))
  _ = assert_eq_int(nrows(h), cast(2, int64), "head 2");
  _ = assert_eq_int(nrows(t), cast(2, int64), "tail 2");
  _ = assert_eq_int(nrows(s), cast(3, int64), "slice 1..4 has 3 rows");
  -- Verify head returns the first 2 values 1.0 and 2.0
  hv = to_list(get_float_col(h, "a"))
  _ = assert_eq(index(hv, cast(0, int64)), cast(1.0, f32), "head[0] == 1.0");
  _ = assert_eq(index(hv, cast(1, int64)), cast(2.0, f32), "head[1] == 2.0");
  -- Verify tail returns the last 2 values 4.0 and 5.0
  tv = to_list(get_float_col(t, "a"))
  _ = assert_eq(index(tv, cast(0, int64)), cast(4.0, f32), "tail[0] == 4.0");
  assert_eq(index(tv, cast(1, int64)), cast(5.0, f32), "tail[1] == 5.0")
}

def test_with_column_then_drop() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  df2 = with_column(df, "b", FloatCol(to_tensor([cast(7.0, f32), cast(8.0, f32), cast(9.0, f32)])))
  _ = assert_eq_int(ncols(df2), cast(2, int64), "after with_column ncols == 2");
  df3 = drop_column(df2, "b")
  assert_eq_int(ncols(df3), cast(1, int64), "after drop_column ncols == 1")
}

def test_rename_changes_column_list() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  df2 = rename(df, "a", "b")
  names = columns(df2)
  _ = assert_eq_int(len(names), cast(1, int64), "one column after rename");
  assert_eq_string(index(names, cast(0, int64)), "b", "renamed column is 'b'")
}

def test_sort_by_float_ascending() -> unit ! { Test } = {
  df = from_pairs([("k", FloatCol(to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)])))])
  sorted = sort_by(df, "k", true)
  vals = to_list(get_float_col(sorted, "k"))
  _ = assert_eq(index(vals, cast(0, int64)), cast(1.0, f32), "first is 1.0");
  _ = assert_eq(index(vals, cast(1, int64)), cast(2.0, f32), "middle is 2.0");
  assert_eq(index(vals, cast(2, int64)), cast(3.0, f32), "last is 3.0")
}

def test_sort_by_string_ascending() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", true)
  names = get_string_col(sorted, "city")
  _ = assert_eq_string(index(names, cast(0, int64)), "berlin", "first is berlin");
  _ = assert_eq_string(index(names, cast(1, int64)), "oslo", "middle is oslo");
  assert_eq_string(index(names, cast(2, int64)), "paris", "last is paris")
}

def test_sort_by_string_descending() -> unit ! { Test } = {
  df = from_pairs([("city", StringCol(["paris", "berlin", "oslo"]))])
  sorted = sort_by(df, "city", false)
  names = get_string_col(sorted, "city")
  _ = assert_eq_string(index(names, cast(0, int64)), "paris", "first is paris");
  assert_eq_string(index(names, cast(2, int64)), "berlin", "last is berlin")
}

def test_concat_doubles_rows() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))])
  out = concat([df, df])
  assert_eq_int(nrows(out), cast(6, int64), "concat doubles rows to 6")
}

def test_describe_returns_8_rows() -> unit ! { Test } = {
  df = from_pairs([("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32), cast(5.0, f32)])))])
  d = describe(df)
  assert_eq_int(nrows(d), cast(8, int64), "describe always has 8 stat rows")
}
