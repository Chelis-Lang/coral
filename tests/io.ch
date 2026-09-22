module Coral.Tests.Io
import Std.Test (assert_true, assert_eq, assert_close)
import Coral.Frame (Frame, Column, FloatCol, StringCol, BoolCol, ColumnType, from_pairs, nrows, ncols, columns, get_float_col, get_string_col, get_int_col, get_bool_col, int_col_of_list)
import Coral.Io (write_csv_frame, read_csv_frame, write_json_frame, read_json_frame)
import Std.Io (write_text)
def zero_i64() -> i64 = cast(0, i64)
def one_i64() -> i64 = cast(1, i64)
def test_csv_write_then_read_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("price", FloatCol(to_tensor([cast(10.5, f32), cast(20.25, f32)]))), ("city", StringCol(["paris", "london"]))])
  _ = write_csv_frame(df, "test_io_roundtrip.csv")
  back = read_csv_frame("test_io_roundtrip.csv")
  prices = to_list(get_float_col(back, "price"))
  cities = get_string_col(back, "city")
  _ = assert_eq(nrows(back), cast(2, i64), "csv roundtrip nrows == 2")
  _ = assert_eq(ncols(back), cast(2, i64), "csv roundtrip ncols == 2")
  _ = assert_close(index(prices, zero_i64()), cast(10.5, f32), cast(0.001, f32), "price[0] == 10.5")
  _ = assert_close(index(prices, one_i64()), cast(20.25, f32), cast(0.001, f32), "price[1] == 20.25")
  _ = assert_eq(index(cities, zero_i64()), "paris", "city[0] == paris")
  assert_eq(index(cities, one_i64()), "london", "city[1] == london")
}
def test_json_write_then_read_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("price", FloatCol(to_tensor([cast(1.25, f32), cast(2.75, f32)]))), ("city", StringCol(["oslo", "berlin"]))])
  _ = write_json_frame(df, "test_io_roundtrip.json")
  back = read_json_frame("test_io_roundtrip.json")
  prices = to_list(get_float_col(back, "price"))
  cities = get_string_col(back, "city")
  _ = assert_eq(nrows(back), cast(2, i64), "json roundtrip nrows == 2")
  _ = assert_eq(ncols(back), cast(2, i64), "json roundtrip ncols == 2")
  _ = assert_close(index(prices, zero_i64()), cast(1.25, f32), cast(0.001, f32), "price[0] == 1.25")
  _ = assert_eq(index(cities, zero_i64()), "oslo", "city[0] == oslo")
  assert_eq(index(cities, one_i64()), "berlin", "city[1] == berlin")
}
def test_csv_bool_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("flag", BoolCol(to_tensor([true, false, true]))), ("name", StringCol(["a", "b", "c"]))])
  _ = write_csv_frame(df, "test_io_bool.csv")
  back = read_csv_frame("test_io_bool.csv")
  flags = to_list(get_bool_col(back, "flag"))
  trues = fold(fn (acc: i64, x: bool) -> if x then add(acc, one_i64()) else acc, zero_i64(), flags)
  _ = assert_eq(nrows(back), cast(3, i64), "bool roundtrip nrows == 3")
  _ = assert_eq(trues, cast(2, i64), "bool roundtrip preserves true-count == 2")
  _ = assert_true(index(flags, zero_i64()), "flag[0] == true")
  assert_true(index(flags, cast(2, i64)), "flag[2] == true")
}
def test_json_bool_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("flag", BoolCol(to_tensor([true, true, false, true]))), ("score", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])))])
  _ = write_json_frame(df, "test_io_bool.json")
  back = read_json_frame("test_io_bool.json")
  flags = to_list(get_bool_col(back, "flag"))
  trues = fold(fn (acc: i64, x: bool) -> if x then add(acc, one_i64()) else acc, zero_i64(), flags)
  _ = assert_eq(nrows(back), cast(4, i64), "json bool roundtrip nrows == 4")
  assert_eq(trues, cast(3, i64), "json bool roundtrip preserves true-count == 3")
}
def test_csv_int_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("qty", int_col_of_list([cast(7, i64), cast(42, i64), cast(99, i64)])), ("name", StringCol(["a", "b", "c"]))])
  _ = write_csv_frame(df, "test_io_int.csv")
  back = read_csv_frame("test_io_int.csv")
  qtys = to_list(get_int_col(back, "qty"))
  qsum = fold(fn (acc: i64, v: i64) -> add(acc, v), zero_i64(), qtys)
  _ = assert_eq(nrows(back), cast(3, i64), "int round-trip nrows == 3")
  _ = assert_eq(qsum, cast(148, i64), "int round-trip preserves values: 7+42+99 == 148")
  assert_eq(index(qtys, one_i64()), cast(42, i64), "qty[1] == 42")
}
def test_csv_two_column_roundtrip() -> unit ! { Test, IO } = {
  df = from_pairs([("amount", FloatCol(to_tensor([cast(0.25, f32), cast(0.75, f32)]))), ("label", StringCol(["a", "b"]))])
  _ = write_csv_frame(df, "smoke_io.csv")
  back = read_csv_frame("smoke_io.csv")
  amounts = to_list(get_float_col(back, "amount"))
  labels = get_string_col(back, "label")
  _ = assert_eq(ncols(back), cast(2, i64), "smoke ncols == 2")
  _ = assert_close(index(amounts, zero_i64()), cast(0.25, f32), cast(0.001, f32), "amount[0] == 0.25")
  _ = assert_eq(index(labels, one_i64()), "b", "label[1] == b")
  assert_eq(index(labels, zero_i64()), "a", "label[0] == a")
}
def test_json_bigint_preserves_exact_digits() -> unit ! { Test, IO } = {
  _ = write_text("test_io_bigint.json", "[{\"id\": 99999999999999999999, \"tag\": \"a\"}, {\"id\": \"n/a\", \"tag\": \"b\"}]")
  back = read_json_frame("test_io_bigint.json")
  ids = get_string_col(back, "id")
  _ = assert_eq(nrows(back), cast(2, i64), "bigint json nrows == 2")
  _ = assert_eq(index(ids, zero_i64()), "99999999999999999999", "JsonBigInt keeps its exact decimal spelling")
  assert_eq(index(ids, one_i64()), "n/a", "non-numeric sibling cell is unchanged")
}
def test_json_bigint_only_column_infers_float() -> unit ! { Test, IO } = {
  _ = write_text("test_io_bigint_num.json", "[{\"id\": 99999999999999999999}, {\"id\": 123}]")
  back = read_json_frame("test_io_bigint_num.json")
  ids = to_list(get_float_col(back, "id"))
  _ = assert_eq(nrows(back), cast(2, i64), "bigint numeric json nrows == 2")
  _ = assert_close(index(ids, zero_i64()), cast(1e20, f32), cast(1000000000000000.0, f32), "out-of-int64 id infers as f32, not as an empty cell")
  assert_close(index(ids, one_i64()), cast(123.0, f32), cast(0.001, f32), "in-range sibling id survives the same inference")
}
