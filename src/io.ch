module Coral.Io
import Coral.Frame (Column, IntCol, FloatCol, StringCol, BoolCol, Frame, from_pairs, columns, get_column)
import Std.Io (write_text)
import Std.Io.Csv (read_csv)
import Std.Io.Json (Json, JsonString, JsonInt, JsonBigInt, JsonFloat, JsonBool, JsonNull, JsonArray, JsonObject, json_array, json_object, load_json)
export (read_csv_frame, write_csv_frame, read_json_frame, write_json_frame, read_parquet_frame, write_parquet_frame)
def zero_i64() -> i64 = cast(0, i64)
def one_i64() -> i64 = cast(1, i64)
def read_csv_frame[n](path: string) -> Frame[n] = {
  rows = read_csv(path)
  if eq(len(rows), zero_i64()) then from_pairs([]) else {
    headers = map(fn (pair: (string, string)) -> pair.0, dict_entries(index(rows, zero_i64())))
    from_pairs(map(fn (name: string) -> (name, infer_csv_column(column_values(rows, name))), headers))
  }
}
def write_csv_frame[n](df: Frame[n], path: string) -> unit = write_text(path, render_csv(df))
def read_json_frame[n](path: string) -> Frame[n] = {
  root = load_json(path)
  match json_array(Some(root)) with {
    | Some(items) => {
    rows = json_rows(items, [])
    if eq(len(rows), zero_i64()) then from_pairs([]) else {
      headers = map(fn (pair: (string, string)) -> pair.0, dict_entries(index(rows, zero_i64())))
      from_pairs(map(fn (name: string) -> (name, infer_csv_column(column_values(rows, name))), headers))
    }
  }
    | None => fail("read_json_frame: expected top-level array")
  }
}
def write_json_frame[n](df: Frame[n], path: string) -> unit = write_text(path, render_json(df))
def column_values(rows: List[Dict[string, string]], name: string) -> List[string] =
  map(fn (row: Dict[string, string]) -> match dict_get(row, name) with {
    | Some(value) => value
    | None => ""
  }, rows)
def infer_csv_column[n](values: List[string]) -> Column[n] =
  if all_ints(values) then {
    xs = to_tensor(map(fn (value: string) -> unwrap_int(value), values))
    xs_cpy = xs
    xs_zeros = to_tensor(map(fn (unused: i64) -> zero_i64(), to_list(xs_cpy)))
    xs_mask = neq(xs_zeros, xs_zeros)
    __borrow_migration_out_0 = IntCol(xs, xs_mask)
    __borrow_migration_out_0
  } else if has_int_with_nulls(values) then int_col_with_mask(values) else if all_floats(values) then FloatCol(to_tensor(map(fn (value: string) -> unwrap_float(value), values))) else if has_float_with_nulls(values) then float_col_with_nan(values) else if all_bools(values) then BoolCol(bools_to_tensor(map(fn (value: string) -> eq(value, "true"), values))) else StringCol(values)
def is_null_cell(value: string) -> bool = eq(value, "")
def all_ints(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, is_some_int(value)), true, values)
def all_floats(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, is_some_float(value)), true, values)
def all_bools(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, or(eq(value, "true"), eq(value, "false"))), true, values)
def has_int_with_nulls(values: List[string]) -> bool = {
  any_int = fold(fn (acc: bool, value: string) -> or(acc, is_some_int(value)), false, values)
  all_int_or_null = fold(fn (acc: bool, value: string) -> and(acc, or(is_null_cell(value), is_some_int(value))), true, values)
  and(any_int, all_int_or_null)
}
def has_float_with_nulls(values: List[string]) -> bool = {
  any_float = fold(fn (acc: bool, value: string) -> or(acc, is_some_float(value)), false, values)
  all_float_or_null = fold(fn (acc: bool, value: string) -> and(acc, or(is_null_cell(value), is_some_float(value))), true, values)
  and(any_float, all_float_or_null)
}
def int_col_with_mask[n](values: List[string]) -> Column[n] = {
  int_values = map(fn (v: string) -> if is_null_cell(v) then zero_i64() else unwrap_int(v), values)
  mask_values = map(fn (v: string) -> is_null_cell(v), values)
  IntCol(to_tensor(int_values), bools_to_tensor(mask_values))
}
def float_col_with_nan[n](values: List[string]) -> Column[n] = {
  float_values = map(fn (v: string) -> if is_null_cell(v) then nan_f32() else unwrap_float(v), values)
  FloatCol(to_tensor(float_values))
}
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def is_some_int(value: string) -> bool =
  match to_int(value) with {
    | Some(v) => true
    | None => false
  }
def is_some_float(value: string) -> bool =
  match to_float(value) with {
    | Some(v) => true
    | None => false
  }
def unwrap_int(value: string) -> i64 =
  match to_int(value) with {
    | Some(v) => v
    | None => cast(0, i64)
  }
def unwrap_float(value: string) -> f32 =
  match to_float(value) with {
    | Some(v) => cast(v, f32)
    | None => cast(0.0, f32)
  }
def render_csv[n](df: Frame[n]) -> string = {
  names = columns(df)
  header = join_strings(names, ",")
  body = csv_rows(df, cast(0, i64), [])
  if eq(len(body), zero_i64()) then string_concat(header, "\n") else string_concat(string_concat(header, "\n"), string_concat(join_strings(body, "\n"), "\n"))
}
def csv_rows[n](df: Frame[n], idx: i64, acc: List[string]) -> List[string] = if gte(idx, row_count(df)) then acc else csv_rows(df, add(idx, one_i64()), append(acc, csv_row(df, columns(df), idx, [])))
def csv_row[n](df: Frame[n], names: List[string], idx: i64, acc: List[string]) -> string =
  if eq(len(names), zero_i64()) then join_strings(acc, ",") else {
    hd = index(names, zero_i64())
    csv_row(df, skip(names, one_i64()), idx, append(acc, csv_quote_field(column_value_string(get_column(df, hd), idx))))
  }
def csv_quote_field(value: string) -> string =
  if csv_needs_quoting(value) then {
    escaped = csv_escape_quotes(value, zero_i64(), "")
    string_concat("\"", string_concat(escaped, "\""))
  } else value
def csv_needs_quoting(value: string) -> bool = {
  has_comma = string_contains_char(value, ",", zero_i64())
  has_quote = string_contains_char(value, "\"", zero_i64())
  has_newline = string_contains_char(value, "\n", zero_i64())
  or(has_comma, or(has_quote, has_newline))
}
def string_contains_char(s: string, c: string, idx: i64) -> bool = if gte(idx, string_len(s)) then false else if eq(string_slice(s, idx, one_i64()), c) then true else string_contains_char(s, c, add(idx, one_i64()))
def csv_escape_quotes(s: string, idx: i64, acc: string) -> string =
  if gte(idx, string_len(s)) then acc else {
    ch = string_slice(s, idx, one_i64())
    next = if eq(ch, "\"") then string_concat(acc, "\"\"") else string_concat(acc, ch)
    csv_escape_quotes(s, add(idx, one_i64()), next)
  }
def render_json[n](df: Frame[n]) -> string = string_concat("[", string_concat(join_strings(json_rows_out(df, cast(0, i64), []), ","), "]"))
def json_rows_out[n](df: Frame[n], idx: i64, acc: List[string]) -> List[string] = if gte(idx, row_count(df)) then acc else json_rows_out(df, add(idx, one_i64()), append(acc, json_row(df, columns(df), idx, [])))
def json_row[n](df: Frame[n], names: List[string], idx: i64, acc: List[string]) -> string =
  if eq(len(names), zero_i64()) then string_concat("{", string_concat(join_strings(acc, ","), "}")) else {
    name = index(names, zero_i64())
    cell = string_concat("\"", string_concat(name, string_concat("\":", json_cell(get_column(df, name), idx))))
    json_row(df, skip(names, one_i64()), idx, append(acc, cell))
  }
def json_cell[n](col: Column[n], idx: i64) -> string =
  match col with {
    | IntCol(xs, imask) => to_string(index(to_list(xs), idx))
    | FloatCol(xs) => to_string(index(to_list(xs), idx))
    | StringCol(xs) => string_concat("\"", string_concat(index(xs, idx), "\""))
    | BoolCol(xs) => to_string(index(to_list(xs), idx))
  }
def column_value_string[n](col: Column[n], idx: i64) -> string =
  match col with {
    | IntCol(xs, imask) => to_string(index(to_list(xs), idx))
    | FloatCol(xs) => to_string(index(to_list(xs), idx))
    | StringCol(xs) => index(xs, idx)
    | BoolCol(xs) => to_string(index(to_list(xs), idx))
  }
def row_count[n](df: Frame[n]) -> i64 = {
  names = columns(df)
  if eq(len(names), zero_i64()) then zero_i64() else match get_column(df, index(names, zero_i64())) with {
    | IntCol(xs, imask) => numel(xs)
    | FloatCol(xs) => numel(xs)
    | StringCol(xs) => len(xs)
    | BoolCol(xs) => numel(xs)
  }
}
def join_strings(values: List[string], sep: string) -> string = join_from(values, sep, true, "")
def join_from(values: List[string], sep: string, first: bool, acc: string) -> string =
  if eq(len(values), zero_i64()) then acc else {
    head = index(values, zero_i64())
    next = if first then string_concat(acc, head) else string_concat(acc, string_concat(sep, head))
    join_from(skip(values, one_i64()), sep, false, next)
  }
def json_rows(items: List[Json], acc: List[Dict[string, string]]) -> List[Dict[string, string]] =
  if eq(len(items), zero_i64()) then acc else {
    row = index(items, zero_i64())
    next = match json_object(Some(row)) with {
      | Some(entries) => append(acc, dict_of(map_json_entries(dict_entries(entries), [])))
      | None => fail("read_json_frame: expected object entries")
    }
    json_rows(skip(items, one_i64()), next)
  }
def map_json_entries(entries: List[(string, Json)], acc: List[(string, string)]) -> List[(string, string)] =
  if eq(len(entries), zero_i64()) then acc else {
    entry = index(entries, zero_i64())
    next = append(acc, (entry.0, render_json_value(entry.1)))
    map_json_entries(skip(entries, one_i64()), next)
  }
def render_json_value(value: Json) -> string =
  match value with {
    | JsonString(text) => text
    | JsonInt(n) => to_string(n)
    | JsonBigInt(digits) => digits
    | JsonFloat(n) => to_string(n)
    | JsonBool(flag) => to_string(flag)
    | JsonNull => ""
    | JsonArray(items) => ""
    | JsonObject(entries) => ""
  }
def bools_to_tensor[n](values: List[bool]) -> tensor[n, bool] = {
  ints = to_tensor(map(fn (flag: bool) -> if flag then one_i64() else zero_i64(), values))
  zeros = to_tensor(map(fn (flag: bool) -> zero_i64(), values))
  __borrow_migration_out_1 = neq(ints, zeros)
  __borrow_migration_out_1
}
-- Parquet stubs: Std.Io.Parquet has no runtime implementation (chelis#850).
def read_parquet_frame[n](path: string) -> Frame[n] = fail("read_parquet_frame requires Std.Io.Parquet (not in current runtime)")
def write_parquet_frame[n](df: Frame[n], path: string) -> string = fail("write_parquet_frame requires Std.Io.Parquet (not in current runtime)")
