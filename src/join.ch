module Coral.Join
import Coral.Frame (Column, Frame, KeyValue, columns, from_pairs, get_column, key_id, key_values, nrows)
export (inner_join, left_join)

def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def neg_one_i64() -> int64 = cast(-1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def inner_join[n, m, k](left: Frame[n], right: Frame[m], on: string) -> Frame[k] = build_join(left, right, on, false)
def left_join[n, m, k](left: Frame[n], right: Frame[m], on: string) -> Frame[k] = build_join(left, right, on, true)

def build_join[n, m, k](left: Frame[n], right: Frame[m], on: string, keep_left: bool) -> Frame[k] = {
  left_keys = key_values(left, on)
  right_keys = key_values(right, on)
  pairs = join_pairs(left_keys, right_keys, keep_left, zero_i64(), [])
  left_rows = map(fn (pair: (int64, int64)) -> pair.0, pairs)
  right_rows = map(fn (pair: (int64, int64)) -> pair.1, pairs)
  left_cols = map(fn (name: string) -> (name, build_column(get_column(left, name), left_rows, false)), columns(left))
  right_cols = map(fn (name: string) -> if eq(name, on) then ("", StringCol([])) else (right_name(columns(left), name), build_column(get_column(right, name), right_rows, true)), columns(right))
  from_pairs(append_named(left_cols, right_cols))
}

def right_name(left_names: List[string], name: string) -> string = if contains_name(left_names, name) then string_concat(name, "_right") else name

def join_pairs(left_keys: List[KeyValue], right_keys: List[KeyValue], keep_left: bool, idx: int64, acc: List[(int64, int64)]) -> List[(int64, int64)] = {
  if gte(idx, len(left_keys)) then acc else {
    matches = matching_rows(right_keys, key_id(index(left_keys, idx)), zero_i64(), [])
    next = if eq(len(matches), zero_i64()) then if keep_left then append(acc, (idx, neg_one_i64())) else acc else append_pairs(acc, left_pairs(idx, matches))
    join_pairs(left_keys, right_keys, keep_left, add(idx, one_i64()), next)
  }
}

def matching_rows(keys: List[KeyValue], key: string, idx: int64, acc: List[int64]) -> List[int64] = {
  if gte(idx, len(keys)) then acc else {
    next = if eq(key_id(index(keys, idx)), key) then append(acc, idx) else acc
    matching_rows(keys, key, add(idx, one_i64()), next)
  }
}

def left_pairs(left_row: int64, right_rows: List[int64]) -> List[(int64, int64)] = map(fn (right_row: int64) -> (left_row, right_row), right_rows)

def append_pairs(lhs: List[(int64, int64)], rhs: List[(int64, int64)]) -> List[(int64, int64)] = {
  if eq(len(rhs), zero_i64()) then lhs else append_pairs(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
}

def append_named(lhs: List[(string, Column[n])], rhs: List[(string, Column[n])]) -> List[(string, Column[n])] = {
  if eq(len(rhs), zero_i64()) then lhs else {
    entry = index(rhs, zero_i64())
    if eq(entry.0, "") then append_named(lhs, drop(rhs, one_i64())) else append_named(append(lhs, entry), drop(rhs, one_i64()))
  }
}

def build_column[n, k](col: Column[n], rows: List[int64], allow_missing: bool) -> Column[k] = {
  match col with {
    | IntCol(xs) => IntCol(to_tensor(map(fn (row: int64) -> if lt(row, zero_i64()) then cast(0, int64) else index(to_list(xs), row), rows)))
    | FloatCol(xs) => FloatCol(to_tensor(map(fn (row: int64) -> if lt(row, zero_i64()) then nan_f32() else index(to_list(xs), row), rows)))
    | StringCol(xs) => StringCol(map(fn (row: int64) -> if lt(row, zero_i64()) then "" else index(xs, row), rows))
    | BoolCol(xs) => fail("join: bool output columns are not supported yet")
  }
}

def contains_name(names: List[string], target: string) -> bool = fold(fn (acc: bool, value: string) -> or(acc, eq(value, target)), false, names)
