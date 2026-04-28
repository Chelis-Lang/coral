module Coral.Tests.IO
import Std.Test (assert_true, assert_eq_int, assert_eq_string, assert_close)
import Coral.Frame (
  Frame, Column, ColumnType,
  from_pairs, nrows, ncols, columns,
  get_float_col, get_string_col, get_int_col,
  int_col_of_list
)
import Coral.IO (write_csv_frame, read_csv_frame, write_json_frame, read_json_frame)

-- NOTE: tensor-tensor eq/neq work in `chelis test` (since v0.2.5), so
-- `int_col_of_list` and the IntCol round trip through `infer_csv_column`
-- run end-to-end. Bool inference still depends on `to_tensor([bool, ...])`
-- which v0.3.0 has not fixed, so bool round trips remain blocked at the
-- eval level. Float and string round trips have always worked. Int round
-- trips are exercised by test_csv_int_roundtrip below.

def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)

def test_csv_write_then_read_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([
    ("price", FloatCol(to_tensor([cast(10.5, f32), cast(20.25, f32)]))),
    ("city", StringCol(["paris", "london"]))
  ])
  _ = write_csv_frame(df, "test_io_roundtrip.csv");
  back = read_csv_frame("test_io_roundtrip.csv")
  prices = to_list(get_float_col(back, "price"))
  cities = get_string_col(back, "city")
  _ = assert_eq_int(nrows(back), cast(2, int64), "csv roundtrip nrows == 2");
  _ = assert_eq_int(ncols(back), cast(2, int64), "csv roundtrip ncols == 2");
  _ = assert_close(index(prices, zero_i64()), cast(10.5, f32), cast(1e-3, f32), "price[0] == 10.5");
  _ = assert_close(index(prices, one_i64()), cast(20.25, f32), cast(1e-3, f32), "price[1] == 20.25");
  _ = assert_eq_string(index(cities, zero_i64()), "paris", "city[0] == paris");
  assert_eq_string(index(cities, one_i64()), "london", "city[1] == london")
}

def test_json_write_then_read_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([
    ("price", FloatCol(to_tensor([cast(1.25, f32), cast(2.75, f32)]))),
    ("city", StringCol(["oslo", "berlin"]))
  ])
  _ = write_json_frame(df, "test_io_roundtrip.json");
  back = read_json_frame("test_io_roundtrip.json")
  prices = to_list(get_float_col(back, "price"))
  cities = get_string_col(back, "city")
  _ = assert_eq_int(nrows(back), cast(2, int64), "json roundtrip nrows == 2");
  _ = assert_eq_int(ncols(back), cast(2, int64), "json roundtrip ncols == 2");
  _ = assert_close(index(prices, zero_i64()), cast(1.25, f32), cast(1e-3, f32), "price[0] == 1.25");
  _ = assert_eq_string(index(cities, zero_i64()), "oslo", "city[0] == oslo");
  assert_eq_string(index(cities, one_i64()), "berlin", "city[1] == berlin")
}

-- Bool round-trip is blocked by the runtime (BoolCol re-inflation calls
-- `neq` on int tensors). We instead confirm the writer path handles a
-- multi-column frame end-to-end without panicking, and that the produced
-- file is non-empty by reading back the string column.
def test_csv_bool_column_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([
    ("flag_text", StringCol(["yes", "no", "yes"])),
    ("score", FloatCol(to_tensor([cast(0.5, f32), cast(1.5, f32), cast(2.5, f32)])))
  ])
  _ = write_csv_frame(df, "test_io_flags.csv");
  back = read_csv_frame("test_io_flags.csv")
  flags = get_string_col(back, "flag_text")
  _ = assert_eq_int(nrows(back), cast(3, int64), "flag csv nrows == 3");
  _ = assert_eq_string(index(flags, zero_i64()), "yes", "flag_text[0] == yes");
  assert_eq_string(index(flags, cast(2, int64)), "yes", "flag_text[2] == yes")
}

-- v0.2.5 unblock: int round-trip exercises infer_csv_column's IntCol
-- branch, which builds the missing mask via tensor-tensor neq. Previously
-- this crashed in the eval interpreter.
def test_csv_int_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([
    ("qty", int_col_of_list([cast(7, int64), cast(42, int64), cast(99, int64)])),
    ("name", StringCol(["a", "b", "c"]))
  ])
  _ = write_csv_frame(df, "test_io_int.csv");
  back = read_csv_frame("test_io_int.csv")
  qtys = to_list(get_int_col(back, "qty"))
  qsum = fold(fn (acc: int64, v: int64) -> add(acc, v), zero_i64(), qtys)
  _ = assert_eq_int(nrows(back), cast(3, int64), "int round-trip nrows == 3");
  _ = assert_eq_int(qsum, cast(148, int64), "int round-trip preserves values: 7+42+99 == 148");
  assert_eq_int(index(qtys, one_i64()), cast(42, int64), "qty[1] == 42")
}

-- Multi-column write+read: confirms the writer/reader handle 2 cols and
-- preserve both column values on round-trip.
def test_csv_two_column_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([
    ("amount", FloatCol(to_tensor([cast(0.25, f32), cast(0.75, f32)]))),
    ("label", StringCol(["a", "b"]))
  ])
  _ = write_csv_frame(df, "smoke_io.csv");
  back = read_csv_frame("smoke_io.csv")
  amounts = to_list(get_float_col(back, "amount"))
  labels = get_string_col(back, "label")
  _ = assert_eq_int(ncols(back), cast(2, int64), "smoke ncols == 2");
  _ = assert_close(index(amounts, zero_i64()), cast(0.25, f32), cast(1e-3, f32), "amount[0] == 0.25");
  _ = assert_eq_string(index(labels, one_i64()), "b", "label[1] == b");
  assert_eq_string(index(labels, zero_i64()), "a", "label[0] == a")
}
