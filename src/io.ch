module Coral.IO
import Coral.Frame (Column, Frame, from_pairs, columns, get_column)
import Std.IO (write_text)
import Std.IO.Csv (read_csv)
import Std.IO.Json (Json, json_array, json_object, load_json)
export (read_csv_frame, write_csv_frame, read_json_frame, write_json_frame, read_parquet_frame, write_parquet_frame)

def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)

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

def column_values(rows: List[Dict[string, string]], name: string) -> List[string] = map(fn (row: Dict[string, string]) -> match dict_get(row, name) with { | Some(value) => value | None => "" }, rows)

def infer_csv_column[n](values: List[string]) -> Column[n] = {
  if all_ints(values) then {
    xs = to_tensor(map(fn (value: string) -> unwrap_int(value), values))
    xs_zeros = to_tensor(map(fn (unused: int64) -> zero_i64(), to_list(xs)))
    xs_mask = neq(copy(xs_zeros), xs_zeros)
    IntCol(xs, xs_mask)
  }
  else if all_floats(values) then FloatCol(to_tensor(map(fn (value: string) -> unwrap_float(value), values)))
  else if all_bools(values) then BoolCol(bools_to_tensor(map(fn (value: string) -> eq(value, "true"), values)))
  else StringCol(values)
}

def all_ints(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, is_some_int(value)), true, values)
def all_floats(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, is_some_float(value)), true, values)
def all_bools(values: List[string]) -> bool = fold(fn (acc: bool, value: string) -> and(acc, or(eq(value, "true"), eq(value, "false"))), true, values)

def is_some_int(value: string) -> bool = match to_int(value) with { | Some(v) => true | None => false }
def is_some_float(value: string) -> bool = match to_float(value) with { | Some(v) => true | None => false }
def unwrap_int(value: string) -> int64 = match to_int(value) with { | Some(v) => v | None => cast(0, int64) }
def unwrap_float(value: string) -> f32 = match to_float(value) with { | Some(v) => cast(v, f32) | None => cast(0.0, f32) }

def render_csv[n](df: Frame[n]) -> string = {
  names = columns(df)
  header = join_strings(names, ",")
  body = csv_rows(df, cast(0, int64), [])
  if eq(len(body), zero_i64()) then string_concat(header, "\n") else string_concat(string_concat(header, "\n"), string_concat(join_strings(body, "\n"), "\n"))
}

def csv_rows[n](df: Frame[n], idx: int64, acc: List[string]) -> List[string] = {
  if gte(idx, row_count(df)) then acc else csv_rows(df, add(idx, one_i64()), append(acc, csv_row(df, columns(df), idx, [])))
}

def csv_row[n](df: Frame[n], names: List[string], idx: int64, acc: List[string]) -> string = {
  if eq(len(names), zero_i64()) then join_strings(acc, ",") else csv_row(df, drop(names, one_i64()), idx, append(acc, column_value_string(get_column(df, index(names, zero_i64())), idx)))
}

def render_json[n](df: Frame[n]) -> string = {
  string_concat("[", string_concat(join_strings(json_rows_out(df, cast(0, int64), []), ","), "]"))
}

def json_rows_out[n](df: Frame[n], idx: int64, acc: List[string]) -> List[string] = {
  if gte(idx, row_count(df)) then acc else json_rows_out(df, add(idx, one_i64()), append(acc, json_row(df, columns(df), idx, [])))
}

def json_row[n](df: Frame[n], names: List[string], idx: int64, acc: List[string]) -> string = {
  if eq(len(names), zero_i64()) then string_concat("{", string_concat(join_strings(acc, ","), "}")) else {
    name = index(names, zero_i64())
    cell = string_concat("\"", string_concat(name, string_concat("\":", json_cell(get_column(df, name), idx))))
    json_row(df, drop(names, one_i64()), idx, append(acc, cell))
  }
}

def json_cell[n](col: Column[n], idx: int64) -> string = {
  match col with {
    | IntCol(xs, imask) => to_string(index(to_list(xs), idx))
    | FloatCol(xs) => to_string(index(to_list(xs), idx))
    | StringCol(xs) => string_concat("\"", string_concat(index(xs, idx), "\""))
    | BoolCol(xs) => to_string(index(to_list(xs), idx))
  }
}

def column_value_string[n](col: Column[n], idx: int64) -> string = {
  match col with {
    | IntCol(xs, imask) => to_string(index(to_list(xs), idx))
    | FloatCol(xs) => to_string(index(to_list(xs), idx))
    | StringCol(xs) => index(xs, idx)
    | BoolCol(xs) => to_string(index(to_list(xs), idx))
  }
}

def row_count[n](df: Frame[n]) -> int64 = {
  names = columns(df)
  if eq(len(names), zero_i64()) then zero_i64() else match get_column(df, index(names, zero_i64())) with {
    | IntCol(xs, imask) => numel(copy(xs))
    | FloatCol(xs) => numel(copy(xs))
    | StringCol(xs) => len(xs)
    | BoolCol(xs) => numel(copy(xs))
  }
}

def join_strings(values: List[string], sep: string) -> string = join_from(values, sep, true, "")

def join_from(values: List[string], sep: string, first: bool, acc: string) -> string = {
  if eq(len(values), zero_i64()) then acc else {
    head = index(values, zero_i64())
    next = if first then string_concat(acc, head) else string_concat(acc, string_concat(sep, head))
    join_from(drop(values, one_i64()), sep, false, next)
  }
}

def json_rows(items: List[Json], acc: List[Dict[string, string]]) -> List[Dict[string, string]] = {
  if eq(len(items), zero_i64()) then acc else {
    row = index(items, zero_i64())
    next = match json_object(Some(row)) with {
      | Some(entries) => append(acc, dict_of(map_json_entries(dict_entries(entries), [])))
      | None => fail("read_json_frame: expected object entries")
    }
    json_rows(drop(items, one_i64()), next)
  }
}

def map_json_entries(entries: List[(string, Json)], acc: List[(string, string)]) -> List[(string, string)] = {
  if eq(len(entries), zero_i64()) then acc else {
    entry = index(entries, zero_i64())
    next = append(acc, (entry.0, render_json_value(entry.1)))
    map_json_entries(drop(entries, one_i64()), next)
  }
}

def render_json_value(value: Json) -> string = {
  match value with {
    | JsonString(text) => text
    | JsonInt(n) => to_string(n)
    | JsonFloat(n) => to_string(n)
    | JsonBool(flag) => to_string(flag)
    | JsonNull => ""
    | _ => ""
  }
}

def bools_to_tensor[n](values: List[bool]) -> tensor[n, bool] = {
  ints = to_tensor(map(fn (flag: bool) -> if flag then one_i64() else zero_i64(), values))
  zeros = to_tensor(map(fn (flag: bool) -> zero_i64(), values))
  neq(copy(ints), zeros)
}

-- read_parquet_frame and write_parquet_frame require Std.IO.Parquet,
-- which is not yet in the chelis runtime. Tracked as upstream blocker.
def read_parquet_frame[n](path: string) -> Frame[n] = fail("read_parquet_frame requires Std.IO.Parquet (not in current runtime)")
def write_parquet_frame[n](df: Frame[n], path: string) -> string = fail("write_parquet_frame requires Std.IO.Parquet (not in current runtime)")
