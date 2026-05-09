module Coral.Join
import Coral.Frame (Column, Frame, KeyValue, columns, from_pairs, get_column, key_id, key_values, nrows)
export (inner_join, left_join, outer_join)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def neg_one_i64() -> int64 = cast(-1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def inner_join[n, m, k](left: Frame[n], right: Frame[m], on: string) -> Frame[k] = build_join(left, right, on, false)
def left_join[n, m, k](left: Frame[n], right: Frame[m], on: string) -> Frame[k] = build_join(left, right, on, true)
def outer_join[n, m, k](left: Frame[n], right: Frame[m], on: string) -> Frame[k] = {
  lkeys = key_values(left, on)
  rkeys = key_values(right, on)
  left_pairs = join_pairs(lkeys, rkeys, true, zero_i64(), [])
  right_extra = right_unmatched_pairs(lkeys, rkeys, zero_i64(), [])
  all_pairs = append_pairs(left_pairs, right_extra)
  assemble_outer_join(left, right, on, lkeys, rkeys, all_pairs)
}
def build_join[n, m, k](left: Frame[n], right: Frame[m], on: string, keep_left: bool) -> Frame[k] = {
  left_keys = key_values(left, on)
  right_keys = key_values(right, on)
  pairs = join_pairs(left_keys, right_keys, keep_left, zero_i64(), [])
  assemble_join(left, right, on, pairs)
}
def key_display(value: KeyValue) -> string = {
  match value with {
    | KeyIntValue(v) => to_string(v)
    | KeyFloatValue(v) => to_string(v)
    | KeyStringValue(v) => v
    | KeyBoolValue(v) => to_string(v)
  }
}
def build_outer_key_strs(lkeys: List[KeyValue], rkeys: List[KeyValue], left_rows: List[int64], right_rows: List[int64], acc: List[string]) -> List[string] = { if eq(len(left_rows), zero_i64()) then acc else {
  lr = index(left_rows, zero_i64())
  rr = index(right_rows, zero_i64())
  v = if lt(lr, zero_i64()) then key_display(index(rkeys, rr)) else key_display(index(lkeys, lr))
  build_outer_key_strs(lkeys, rkeys, drop(left_rows, one_i64()), drop(right_rows, one_i64()), append(acc, v))
} }
def assemble_outer_join[n, m, k](left: Frame[n], right: Frame[m], on: string, lkeys: List[KeyValue], rkeys: List[KeyValue], pairs: List[(int64, int64)]) -> Frame[k] = {
  left_rows = map(fn (pair: (int64, int64)) -> pair.0, pairs)
  right_rows = map(fn (pair: (int64, int64)) -> pair.1, pairs)
  key_strs = build_outer_key_strs(lkeys, rkeys, left_rows, right_rows, [])
  left_cols = map(fn (name: string) -> if eq(name, on) then (name, StringCol(key_strs)) else (name, build_column(get_column(left, name), left_rows, false)), columns(left))
  right_cols = map(fn (name: string) -> if eq(name, on) then ("", StringCol([])) else (right_name(columns(left), name), build_column(get_column(right, name), right_rows, true)), columns(right))
  from_pairs(append_named(left_cols, right_cols))
}
def assemble_join[n, m, k](left: Frame[n], right: Frame[m], on: string, pairs: List[(int64, int64)]) -> Frame[k] = {
  left_rows = map(fn (pair: (int64, int64)) -> pair.0, pairs)
  right_rows = map(fn (pair: (int64, int64)) -> pair.1, pairs)
  left_cols = map(fn (name: string) -> (name, build_column(get_column(left, name), left_rows, false)), columns(left))
  right_cols = map(fn (name: string) -> if eq(name, on) then ("", StringCol([])) else (right_name(columns(left), name), build_column(get_column(right, name), right_rows, true)), columns(right))
  from_pairs(append_named(left_cols, right_cols))
}
def right_unmatched_pairs(left_keys: List[KeyValue], right_keys: List[KeyValue], idx: int64, acc: List[(int64, int64)]) -> List[(int64, int64)] = { if gte(idx, len(right_keys)) then acc else {
  right_key = index(right_keys, idx)
  matches = matching_rows(left_keys, key_id(right_key), zero_i64(), [])
  if eq(len(matches), zero_i64()) then right_unmatched_pairs(left_keys, right_keys, add(idx, one_i64()), append(acc, (neg_one_i64(), idx))) else right_unmatched_pairs(left_keys, right_keys, add(idx, one_i64()), acc)
} }
def right_name(left_names: List[string], name: string) -> string = if contains_name(left_names, name) then string_concat(name, "_right") else name
def join_pairs(left_keys: List[KeyValue], right_keys: List[KeyValue], keep_left: bool, idx: int64, acc: List[(int64, int64)]) -> List[(int64, int64)] = { if gte(idx, len(left_keys)) then acc else {
  matches = matching_rows(right_keys, key_id(index(left_keys, idx)), zero_i64(), [])
  next = if eq(len(matches), zero_i64()) then if keep_left then append(acc, (idx, neg_one_i64())) else acc else append_pairs(acc, left_pairs(idx, matches))
  join_pairs(left_keys, right_keys, keep_left, add(idx, one_i64()), next)
} }
def matching_rows(keys: List[KeyValue], key: string, idx: int64, acc: List[int64]) -> List[int64] = { if gte(idx, len(keys)) then acc else {
  next = if eq(key_id(index(keys, idx)), key) then append(acc, idx) else acc
  matching_rows(keys, key, add(idx, one_i64()), next)
} }
def left_pairs(left_row: int64, right_rows: List[int64]) -> List[(int64, int64)] = map(fn (right_row: int64) -> (left_row, right_row), right_rows)
def append_pairs(lhs: List[(int64, int64)], rhs: List[(int64, int64)]) -> List[(int64, int64)] = { if eq(len(rhs), zero_i64()) then lhs else append_pairs(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64())) }
def append_named(lhs: List[(string, Column[n])], rhs: List[(string, Column[n])]) -> List[(string, Column[n])] = { if eq(len(rhs), zero_i64()) then lhs else {
  entry = index(rhs, zero_i64())
  if eq(entry.0, "") then append_named(lhs, drop(rhs, one_i64())) else append_named(append(lhs, entry), drop(rhs, one_i64()))
} }
def build_column[n, k](col: Column[n], rows: List[int64], allow_missing: bool) -> Column[k] = { match col with {
  | IntCol(xs, xmask) => {
  xs_list = to_list(xs)
  xmask_list = to_list(xmask)
  int_vals = to_tensor(map(fn (row: int64) -> if lt(row, zero_i64()) then cast(0, int64) else index(xs_list, row), rows))
  mask_ints = to_tensor(map(fn (row: int64) -> if lt(row, zero_i64()) then one_i64() else if index(xmask_list, row) then one_i64() else zero_i64(), rows))
  mask_zeros = to_tensor(map(fn (row: int64) -> zero_i64(), rows))
  __borrow_migration_out_0 = IntCol(int_vals, neq(copy(mask_ints), mask_zeros))
  _ = drop(mask_ints)
  _ = drop(mask_zeros)
  __borrow_migration_out_0
}
  | FloatCol(xs) => FloatCol(to_tensor(map(fn (row: int64) -> if lt(row, zero_i64()) then nan_f32() else index(to_list(xs), row), rows)))
  | StringCol(xs) => StringCol(map(fn (row: int64) -> if lt(row, zero_i64()) then "" else index(xs, row), rows))
  | BoolCol(xs) => fail("join: bool output columns are not supported yet")
} }
def contains_name(names: List[string], target: string) -> bool = fold(fn (acc: bool, value: string) -> or(acc, eq(value, target)), false, names)
