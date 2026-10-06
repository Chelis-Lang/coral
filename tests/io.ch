module Coral.Tests.Io
import Std.Test (assert_true, assert_eq, assert_close)
import Coral.Frame (Frame, Column, FloatCol, StringCol, BoolCol, ColumnType, from_pairs, nrows, ncols, columns, get_float_col, get_string_col, get_int_col, get_bool_col, int_col_of_list)
import Coral.Io (write_csv_frame, read_csv_frame, write_json_frame, read_json_frame)
import Std.Io (write_text, read_text)
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
def test_json_float_preserves_exact_token_text() -> unit ! { Test, IO } = {
  _ = write_text("test_io_float_token.json", "[{\"value\": 1.2500e+02}, {\"value\": \"n/a\"}]")
  back = read_json_frame("test_io_float_token.json")
  values = get_string_col(back, "value")
  _ = assert_eq(nrows(back), cast(2, i64), "float-token JSON nrows == 2")
  _ = assert_eq(index(values, zero_i64()), "1.2500e+02", "JsonFloat keeps the original exponent token")
  assert_eq(index(values, one_i64()), "n/a", "mixed string sibling stays unchanged")
}
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def pinf_f32() -> f32 = div(cast(1.0, f32), cast(0.0, f32))
def ninf_f32() -> f32 = div(cast(-1.0, f32), cast(0.0, f32))
def test_json_non_finite_floats_render_as_null() -> unit ! { Test, IO } = {
  df = from_pairs([("v", FloatCol(to_tensor([nan_f32(), pinf_f32(), ninf_f32(), cast(1.5, f32)]))), ("k", StringCol(["a", "b", "c", "d"]))])
  _ = write_json_frame(df, "test_io_non_finite.json")
  text = read_text("test_io_non_finite.json")
  assert_eq(text, "[{\"v\":null,\"k\":\"a\"},{\"v\":null,\"k\":\"b\"},{\"v\":null,\"k\":\"c\"},{\"v\":1.5,\"k\":\"d\"}]", "NaN, +inf and -inf each render as the JSON null literal, and a finite sibling is untouched")
}
def test_json_finite_floats_never_render_as_null() -> unit ! { Test, IO } = {
  df = from_pairs([("v", FloatCol(to_tensor([cast(1.5, f32), cast(-2.25, f32), cast(0.0, f32), cast(-0.0, f32), cast(3.4028234e38, f32), cast(-3.4028234e38, f32), cast(1e-44, f32)])))])
  _ = write_json_frame(df, "test_io_finite_floats.json")
  text = read_text("test_io_finite_floats.json")
  assert_eq(text, "[{\"v\":1.5},{\"v\":-2.25},{\"v\":0.0},{\"v\":-0.0},{\"v\":3.4028235e38},{\"v\":-3.4028235e38},{\"v\":1e-44}]", "every finite float keeps its numeric spelling: signed zero, both ends of the f32 range, and a subnormal")
}
def test_csv_non_finite_floats_keep_their_own_spelling() -> unit ! { Test, IO } = {
  df = from_pairs([("v", FloatCol(to_tensor([nan_f32(), pinf_f32(), ninf_f32(), cast(1.5, f32)])))])
  _ = write_csv_frame(df, "test_io_non_finite.csv")
  text = read_text("test_io_non_finite.csv")
  assert_eq(text, "v\nNaN\ninf\n-inf\n1.5\n", "the CSV writer is unaffected: a non-finite float keeps to_string's spelling and does not become JSON null")
}
def test_json_null_float_cell_reads_back_as_missing() -> unit ! { Test, IO } = {
  df = from_pairs([("v", FloatCol(to_tensor([nan_f32(), cast(1.5, f32)])))])
  _ = write_json_frame(df, "test_io_non_finite_roundtrip.json")
  back = read_json_frame("test_io_non_finite_roundtrip.json")
  vs = to_list(get_float_col(back, "v"))
  _ = assert_eq(nrows(back), cast(2, i64), "non-finite json roundtrip nrows == 2")
  _ = assert_true(neq(index(vs, zero_i64()), index(vs, zero_i64())), "the null cell reads back as a missing float, not as a number")
  assert_close(index(vs, one_i64()), cast(1.5, f32), cast(0.001, f32), "the finite sibling survives the roundtrip")
}
def test_json_csv_missing_numeric_cell_writes_valid_null() -> unit ! { Test, IO } = {
  _ = write_text("test_io_missing_cell.csv", "v,k\n1.5,a\n,b\n2.5,c\n")
  df = read_csv_frame("test_io_missing_cell.csv")
  _ = write_json_frame(df, "test_io_missing_cell.json")
  text = read_text("test_io_missing_cell.json")
  assert_eq(text, "[{\"v\":1.5,\"k\":\"a\"},{\"v\":null,\"k\":\"b\"},{\"v\":2.5,\"k\":\"c\"}]", "a blank numeric CSV cell reaches JSON as null, not as a bare NaN token")
}
-- coral#55: every column name and string cell reaches the file through
-- `Std.Io.Json.to_json`, so the escaping rules are the stdlib's. These tests
-- assert the written bytes and the read-back value, because the backslash case
-- below produced a *valid* document with a changed value: both halves have to
-- be pinned or the silent half passes again.
def test_json_quote_in_string_cell_is_escaped() -> unit ! { Test, IO } = {
  df = from_pairs([("note", StringCol(["say \"hi\"", "plain"]))])
  _ = write_json_frame(df, "test_io_quote_cell.json")
  text = read_text("test_io_quote_cell.json")
  back = read_json_frame("test_io_quote_cell.json")
  notes = get_string_col(back, "note")
  _ = assert_eq(text, "[{\"note\":\"say \\\"hi\\\"\"},{\"note\":\"plain\"}]", "a quote inside a cell is written as the two-character escape, not raw")
  _ = assert_eq(index(notes, zero_i64()), "say \"hi\"", "the quoted cell reads back with both quotes intact")
  assert_eq(index(notes, one_i64()), "plain", "the sibling cell that needs no escaping is unchanged")
}
def test_json_backslash_cell_roundtrips_without_losing_characters() -> unit ! { Test, IO } = {
  df = from_pairs([("note", StringCol(["a\\b"]))])
  _ = write_json_frame(df, "test_io_backslash_cell.json")
  text = read_text("test_io_backslash_cell.json")
  back = read_json_frame("test_io_backslash_cell.json")
  notes = get_string_col(back, "note")
  _ = assert_eq(text, "[{\"note\":\"a\\\\b\"}]", "a backslash is doubled, so `\\b` cannot be read as the JSON backspace escape")
  _ = assert_eq(index(notes, zero_i64()), "a\\b", "the three characters survive the roundtrip")
  assert_eq(string_len(index(notes, zero_i64())), cast(3, i64), "three characters, not the one that an unescaped backslash left behind")
}
def test_json_control_characters_in_cells_are_escaped() -> unit ! { Test, IO } = {
  df = from_pairs([("note", StringCol(["l1\nl2", "t\tb", "r\rn"]))])
  _ = write_json_frame(df, "test_io_control_cell.json")
  text = read_text("test_io_control_cell.json")
  back = read_json_frame("test_io_control_cell.json")
  notes = get_string_col(back, "note")
  _ = assert_eq(text, "[{\"note\":\"l1\\nl2\"},{\"note\":\"t\\tb\"},{\"note\":\"r\\rn\"}]", "newline, tab and carriage return each use their two-character escape; RFC 8259 forbids the raw control byte")
  _ = assert_eq(index(notes, zero_i64()), "l1\nl2", "the newline cell reads back exactly")
  _ = assert_eq(index(notes, one_i64()), "t\tb", "the tab cell reads back exactly")
  assert_eq(index(notes, cast(2, i64)), "r\rn", "the carriage-return cell reads back exactly")
}
def test_json_quote_in_column_name_is_escaped() -> unit ! { Test, IO } = {
  df = from_pairs([("na\"me", StringCol(["x"]))])
  _ = write_json_frame(df, "test_io_quote_name.json")
  text = read_text("test_io_quote_name.json")
  back = read_json_frame("test_io_quote_name.json")
  _ = assert_eq(text, "[{\"na\\\"me\":\"x\"}]", "a quote inside a column name is escaped in the object key, not left to truncate the key")
  _ = assert_eq(ncols(back), one_i64(), "the escaped key parses back as exactly one column")
  assert_eq(index(columns(back), zero_i64()), "na\"me", "the column name survives the roundtrip")
}
def test_json_safe_text_is_not_over_escaped() -> unit ! { Test, IO } = {
  df = from_pairs([("p", StringCol(["a/b", "c d", "e-f_g"]))])
  _ = write_json_frame(df, "test_io_safe_text.json")
  text = read_text("test_io_safe_text.json")
  assert_eq(text, "[{\"p\":\"a/b\"},{\"p\":\"c d\"},{\"p\":\"e-f_g\"}]", "the forward slash and ordinary punctuation stay as themselves: RFC 8259 permits an unescaped solidus and nothing here is doubled")
}
-- coral#55: `JsonFloat(f64, string)` is only serializable when its text is a
-- float-form token whose correctly rounded f64 prints back to the stored value.
-- An f32 cell's shortest text is not the widened f64's shortest text -- 0.1f32
-- widens to an f64 that prints 0.10000000149011612 -- so the writer pairs the
-- f32's own text with the f64 that text parses to. Integral cells matter
-- separately: a float-form token must carry a fraction or an exponent, so a
-- spelling without `.0` would be rejected outright.
def test_json_float_spellings_survive_the_json_value_path() -> unit ! { Test, IO } = {
  df = from_pairs([("v", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(100.0, f32), cast(0.1, f32), cast(1e20, f32)])))])
  _ = write_json_frame(df, "test_io_float_spellings.json")
  text = read_text("test_io_float_spellings.json")
  assert_eq(text, "[{\"v\":1.0},{\"v\":2.0},{\"v\":100.0},{\"v\":0.1},{\"v\":1e20}]", "an integral float keeps its `.0`, a value whose f32 and f64 shortest texts differ keeps the f32 one, and e-notation is unchanged")
}
-- coral#55 deliberately did NOT adopt a whole-document `JsonObject` build:
-- `Std.Io.Json`'s object rendering emits keys in Unicode scalar-key order,
-- while `read_json_frame` preserves document order, so a tree build would make
-- write-then-read permute a frame's columns. Column order is observable Coral
-- behaviour and CSV preserves it; this pins that JSON agrees.
def test_json_preserves_frame_column_order() -> unit ! { Test, IO } = {
  df = from_pairs([("v", StringCol(["1"])), ("k", StringCol(["2"])), ("aa", StringCol(["3"]))])
  _ = write_json_frame(df, "test_io_column_order.json")
  text = read_text("test_io_column_order.json")
  back = read_json_frame("test_io_column_order.json")
  names = columns(back)
  _ = assert_eq(text, "[{\"v\":\"1\",\"k\":\"2\",\"aa\":\"3\"}]", "the object keys follow the frame's column order, not a sorted order")
  _ = assert_eq(index(names, zero_i64()), "v", "read-back column 0 is still v")
  _ = assert_eq(index(names, one_i64()), "k", "read-back column 1 is still k")
  assert_eq(index(names, cast(2, i64)), "aa", "read-back column 2 is still aa")
}
