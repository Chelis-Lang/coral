module Coral.Io
import Coral.Frame (Column, IntCol, FloatCol, StringCol, BoolCol, Frame, from_pairs, columns, get_column)
import Std.Io (write_text)
import Std.Text (join)
import Std.Io.Csv (read_csv)
import Std.Io.Json (Json, JsonString, JsonInt, JsonBigInt, JsonFloat, JsonBool, JsonNull, JsonArray, JsonObject, json_array, json_object, load_json, to_json)
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
    rows = json_rows(items)
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
  header = join(names, ",")
  body = csv_rows(df)
  if eq(len(body), zero_i64()) then string_concat(header, "\n") else string_concat(string_concat(header, "\n"), string_concat(join(body, "\n"), "\n"))
}
-- Rows are assembled column-major: each column is converted to its full list of
-- cell strings once, and the columns are then folded together one row at a
-- time. Nothing walks rows by recursion, and nothing captures a per-column list
-- in a closure the row walk re-enters. The per-row and per-column recursions
-- this replaced exhausted the evaluator stack at roughly 2,300 rows, which is
-- inside the frame sizes this API is for, so the bound is a correctness
-- property of the writer and not a tuning choice.
def csv_rows[n](df: Frame[n]) -> List[string] = join_columns_by_row(csv_column_table(df, columns(df)), ",")
-- `df` is moved into this closure capture, so the capture has to be its last
-- use; taking `names` as an argument keeps `columns` on the caller's side of
-- that move.
def csv_column_table[n](df: Frame[n], names: List[string]) -> List[List[string]] = map(fn (name: string) -> csv_column_cells(get_column(df, name)), names)
-- Column 0's cells are the partial rows, and each further column is zipped onto
-- them, so the fold is over columns and each step is one `map` over rows. The
-- shape matters on the build lane too, not only in the evaluator: a cell table
-- captured once and indexed per row lowers to `inconsistent live owners` on the
-- C host lane, which is why the row index is never a closure capture here.
--
-- The equal-length check is not redundant with `from_pairs`, which does reject
-- mismatched columns: `with_column` does not check its column's length, so a
-- frame whose columns disagree is reachable. The check is not merely a guard
-- for this rewrite either. Indexing every column at the first column's length
-- trapped out of bounds only when column 0 was the longest; when column 0 was
-- the shortest it wrote a file truncated to that length with no diagnostic, so
-- half the ragged shapes were already silent data loss. A bare `zip` fold would
-- make all of them silent. This refuses every one of them and names the
-- property that failed.
def join_columns_by_row(column_cells: List[List[string]], sep: string) -> List[string] =
  if eq(len(column_cells), zero_i64()) then [] else {
    width = len(index(column_cells, zero_i64()))
    even = fold(fn (acc: bool, column: List[string]) -> and(acc, eq(len(column), width)), true, column_cells)
    if not(even) then fail("Coral.Io: cannot write a frame whose columns have different lengths") else fold(fn (acc: List[string], column: List[string]) -> zip_with_separator(acc, column, sep), index(column_cells, zero_i64()), skip(column_cells, one_i64()))
  }
def zip_with_separator(left: List[string], right: List[string], sep: string) -> List[string] = map(fn (pair: (string, string)) -> string_concat(pair.0, string_concat(sep, pair.1)), zip(left, right))
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
def render_json[n](df: Frame[n]) -> string = string_concat("[", string_concat(join(json_rows_out(df), ","), "]"))
-- Column-major and column-folded for the same reasons as `csv_rows`. Each
-- column is labelled with its own key first, so the shared fold joins strings
-- that already carry their `"key":value` spelling.
def json_rows_out[n](df: Frame[n]) -> List[string] = {
  names = columns(df)
  keys = map(fn (name: string) -> to_json(JsonString(name)), names)
  labelled = map(fn (field: (string, List[Json])) -> json_column_fields(field.0, field.1), zip(keys, json_column_table(df, names)))
  map(fn (row: string) -> string_concat("{", string_concat(row, "}")), join_columns_by_row(labelled, ","))
}
def json_column_table[n](df: Frame[n], names: List[string]) -> List[List[Json]] = map(fn (name: string) -> json_column_cells(get_column(df, name)), names)
def json_column_fields(key: string, cells: List[Json]) -> List[string] = map(fn (cell: Json) -> string_concat(key, string_concat(":", to_json(cell))), cells)
-- Every key and every value is serialized by `Std.Io.Json.to_json`, so quoting,
-- escaping and number spelling are the stdlib's rules and not Coral's.
-- Only the object and array framing is assembled here, because
-- `to_json` on a whole `JsonObject` emits keys in Unicode scalar-key order
-- while `read_json_frame` preserves document order: a whole-document tree build
-- would make write-then-read permute a frame's columns, which CSV does not do.
-- The framing carries no value-dependent behaviour, so no cell content can
-- change meaning in it.
-- Returning `List[Json]` rather than rendered text is the structural half of
-- that separation: the CSV writer's `csv_column_cells` returns `List[string]`,
-- so neither helper can be reached from the other format's writer by accident. A
-- one-line substitution between the two is a type error instead of a silent
-- change of output.
def json_column_cells[n](col: Column[n]) -> List[Json] =
  match col with {
    | IntCol(xs, imask) => map(fn (value: i64) -> JsonInt(value), to_list(xs))
    | FloatCol(xs) => map(fn (value: f32) -> json_float_value(value), to_list(xs))
    | StringCol(xs) => map(fn (value: string) -> JsonString(value), xs)
    | BoolCol(xs) => map(fn (value: bool) -> JsonBool(value), to_list(xs))
  }
-- RFC 8259 has no NaN or Infinity literal, so a non-finite float cell becomes
-- `JsonNull`, the encoding pandas `to_json` uses for the same values. Reading
-- the document back turns that null into a missing float cell, unless no cell in
-- the column is finite, in which case inference sees only empty cells and gives a
-- string column. CSV output keeps its own spelling and is unaffected.
--
-- `JsonFloat(value, text)` is serializable only when `text` is a float-form
-- token -- it must carry a fraction or an exponent -- whose correctly rounded
-- f64 prints back to `value`. A Coral float cell is f32, and an f32's shortest
-- text is not the widened f64's shortest text: 0.1f32 widens to an f64 that
-- prints `0.10000000149011612`, so pairing the f32 text with the widened value
-- is rejected, and pairing the widened value with its own text would rewrite
-- every spelling the file used to carry. The cell's own text is therefore
-- paired with the f64 that text parses to, which is what the read path's
-- `parse_number` stores for the same token. That pairing satisfies the
-- round-trip half of the rule by construction, because the stored value *is*
-- the text's parse; the float-token half stays `to_json`'s to enforce, and a
-- text it rejects aborts there with the stdlib's own message. The `None` arm
-- below is unreachable for a finite f32 -- `to_string` of one is always a
-- parseable number -- and fails loudly rather than becoming null so that a
-- future change which does reach it cannot pass silently.
def json_float_value(x: f32) -> Json =
  if not(is_finite_f32(x)) then JsonNull else {
    text = to_string(x)
    match to_float(text) with {
      | Some(value) => JsonFloat(value, text)
      | None => fail("write_json_frame: a finite float cell produced text that is not a JSON number token")
    }
  }
-- `sub(x, x)` is zero for every finite float and NaN for NaN and both
-- infinities, so this rejects exactly the three values JSON cannot spell. No
-- ordering bound does: a finite bound wrongly rejects the f32 extremes, and
-- negating it wrongly accepts NaN, because every ordering comparison against
-- NaN is false whichever way it is written. Equality is not ordering --
-- `neq(x, x)` is true for NaN, and alone it would still emit the infinities.
def is_finite_f32(x: f32) -> bool = eq(sub(x, x), cast(0.0, f32))
def csv_column_cells[n](col: Column[n]) -> List[string] =
  match col with {
    | IntCol(xs, imask) => map(fn (value: i64) -> csv_quote_field(to_string(value)), to_list(xs))
    | FloatCol(xs) => map(fn (value: f32) -> csv_quote_field(to_string(value)), to_list(xs))
    | StringCol(xs) => map(fn (value: string) -> csv_quote_field(value), xs)
    | BoolCol(xs) => map(fn (value: bool) -> csv_quote_field(to_string(value)), to_list(xs))
  }
-- A `map` over the document's items, not a recursion over them, for the same
-- reason as the writers. This path has a second and lower row ceiling that is
-- not Coral's: `Std.Io.Json.load_json` is itself depth-proportional to the
-- element count at the pinned toolchain, so the document is already parsed --
-- or already over budget -- before this `map` runs. See
-- `docs/UPSTREAM_BUGS.md`.
def json_rows(items: List[Json]) -> List[Dict[string, string]] = map(fn (item: Json) -> json_row_dict(item), items)
def json_row_dict(item: Json) -> Dict[string, string] =
  match json_object(Some(item)) with {
    | Some(entries) => dict_of(map(fn (entry: (string, Json)) -> (entry.0, render_json_value(entry.1)), dict_entries(entries)))
    | None => fail("read_json_frame: expected object entries")
  }
def render_json_value(value: Json) -> string =
  match value with {
    | JsonString(text) => text
    | JsonInt(n) => to_string(n)
    | JsonBigInt(digits) => digits
    | JsonFloat(_, text) => text
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
-- Parquet file I/O is deferred: spec/scope.md Deferrals (D10).
def read_parquet_frame[n](path: string) -> Frame[n] = fail("read_parquet_frame requires implemented Std.Io.Parquet support")
def write_parquet_frame[n](df: Frame[n], path: string) -> string = fail("write_parquet_frame requires implemented Std.Io.Parquet support")
