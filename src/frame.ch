module Coral.Frame
import Coral.Internal.HAMT (Hamt, hamt_from_pairs, hamt_get, hamt_put, hamt_remove)
import Nautilus.Stats (mean_vec, min_vec, max_vec, quantile_vec, std_vec)
export (
  ColumnType, Column, KeyValue, Frame,
  from_columns, from_pairs, empty,
  get_column, get_float_col, get_int_col, get_string_col, get_bool_col,
  columns, column_type, nrows, ncols,
  filter, head, tail, slice, sort_by,
  with_column, mutate, rename, drop_column,
  is_nan, fill_nan, drop_nan, any_nan, count_nan,
  concat, describe,
  key_id, key_values, key_values_to_column_like
)

type ColumnType =
  | IntType
  | FloatType
  | StringType
  | BoolType

type Column[n] =
  | IntCol(tensor[n, int64])
  | FloatCol(tensor[n, f32])
  | StringCol(List[string])
  | BoolCol(tensor[n, bool])

type KeyValue =
  | KeyIntValue(int64)
  | KeyFloatValue(f32)
  | KeyStringValue(string)
  | KeyBoolValue(bool)

type Frame[n] =
  | Frame { cols: Hamt[Column[n]], col_order: List[string] }

def zero_i64() -> int64 = cast(0, int64)
def zero_i32() -> int32 = cast(0, int32)
def one_i64() -> int64 = cast(1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def from_columns[n](cols: Dict[string, Column[n]]) -> Frame[n] = from_pairs(dict_entries(cols))

def from_pairs[n](pairs: List[(string, Column[n])]) -> Frame[n] = {
  if not(names_unique(map(fn (pair: (string, Column[n])) -> pair.0, pairs))) then fail("from_pairs: duplicate column name")
  else if not(column_lengths_match(pairs)) then fail("from_pairs: mismatched column lengths")
  else Frame { cols: hamt_from_pairs(pairs), col_order: map(fn (pair: (string, Column[n])) -> pair.0, pairs) }
}

def empty[n](schema: Dict[string, ColumnType]) -> Frame[n] = {
  entries = map(fn (pair: (string, ColumnType)) -> {
    name = pair.0
    ty = pair.1
    (name, empty_column(ty))
  }, dict_entries(schema))
  Frame { cols: hamt_from_pairs(entries), col_order: map(fn (pair: (string, ColumnType)) -> pair.0, dict_entries(schema)) }
}

def get_column[n](df: Frame[n], name: string) -> Column[n] = {
  match df with {
    | Frame { cols: cols, col_order: order } => match hamt_get(cols, name) with {
      | Some(value) => value
      | None => fail(string_concat("missing column: ", name))
    }
  }
}

def get_float_col[n](df: Frame[n], name: string) -> tensor[n, f32] = {
  match get_column(df, name) with {
    | FloatCol(col) => col
    | _ => fail(string_concat("column is not float: ", name))
  }
}

def get_int_col[n](df: Frame[n], name: string) -> tensor[n, int64] = {
  match get_column(df, name) with {
    | IntCol(col) => col
    | _ => fail(string_concat("column is not int: ", name))
  }
}

def get_string_col[n](df: Frame[n], name: string) -> List[string] = {
  match get_column(df, name) with {
    | StringCol(col) => col
    | _ => fail(string_concat("column is not string: ", name))
  }
}

def get_bool_col[n](df: Frame[n], name: string) -> tensor[n, bool] = {
  match get_column(df, name) with {
    | BoolCol(col) => col
    | _ => fail(string_concat("column is not bool: ", name))
  }
}

def columns[n](df: Frame[n]) -> List[string] = {
  match df with {
    | Frame { cols: cols, col_order: order } => order
  }
}

def column_type[n](df: Frame[n], name: string) -> ColumnType = {
  match get_column(df, name) with {
    | IntCol(_) => IntType
    | FloatCol(_) => FloatType
    | StringCol(_) => StringType
    | BoolCol(_) => BoolType
  }
}

def nrows[n](df: Frame[n]) -> int64 = {
  names = columns(df)
  if eq(len(names), zero_i64()) then zero_i64() else column_len(get_column(df, index(names, zero_i64())))
}

def ncols[n](df: Frame[n]) -> int64 = len(columns(df))

def filter[n, k](df: Frame[n], mask: tensor[n, bool]) -> Frame[k] = {
  if neq(numel(copy(mask)), nrows(df)) then fail("filter: mask length mismatch")
  else {
    idx_list = mask_to_index_list(enumerate(to_list(mask)), [])
    idx = to_tensor(idx_list)
    from_pairs(map(fn (name: string) -> (name, reindex_column(get_column(df, name), idx, idx_list)), columns(df)))
  }
}

def head[n, k](df: Frame[n], count: int64) -> Frame[k] = {
  upper = int_min(int_max(count, zero_i64()), nrows(df))
  slice(df, zero_i64(), upper)
}

def tail[n, k](df: Frame[n], count: int64) -> Frame[k] = {
  total = nrows(df)
  kept = int_min(int_max(count, zero_i64()), total)
  slice(df, sub(total, kept), total)
}

def slice[n, k](df: Frame[n], start: int64, finish: int64) -> Frame[k] = {
  total = nrows(df)
  lo = int_max(zero_i64(), start)
  hi = int_min(total, finish)
  idx_list = if gt(lo, hi) then [] else range(lo, hi)
  idx = to_tensor(idx_list)
  from_pairs(map(fn (name: string) -> (name, reindex_column(get_column(df, name), idx, idx_list)), columns(df)))
}

def sort_by[n](df: Frame[n], name: string, ascending: bool) -> Frame[n] = {
  match get_column(df, name) with {
    | FloatCol(col) => reindex_all(df, orient_perm(sort(copy(col), zero_i32()).1, ascending))
    | IntCol(col) => reindex_all(df, orient_perm(sort(copy(col), zero_i32()).1, ascending))
    | BoolCol(col) => reindex_all(df, orient_perm(sort(copy(col), zero_i32()).1, ascending))
    | StringCol(col) => fail("sort_by: string columns are deferred in v0.1.0")
  }
}

def with_column[n](df: Frame[n], name: string, col: Column[n]) -> Frame[n] = {
  total = nrows(df)
  col_n = column_len(col)
  if and(gt(total, zero_i64()), neq(total, col_n)) then fail("with_column: length mismatch")
  else match df with {
    | Frame { cols: cols, col_order: order } => {
      next_cols = hamt_put(cols, name, col)
      next_order = if contains_string(order, name) then order else append(order, name)
      Frame { cols: next_cols, col_order: next_order }
    }
  }
}

def mutate[n](df: Frame[n], name: string, col: Column[n]) -> Frame[n] = with_column(df, name, col)

def rename[n](df: Frame[n], old_name: string, new_name: string) -> Frame[n] = {
  if contains_string(columns(df), new_name) then fail("rename: target column already exists")
  else match df with {
    | Frame { cols: cols, col_order: order } => {
      value = get_column(df, old_name)
      Frame {
        cols: hamt_put(hamt_remove(cols, old_name), new_name, value),
        col_order: replace_name(order, old_name, new_name, [])
      }
    }
  }
}

def drop_column[n](df: Frame[n], name: string) -> Frame[n] = {
  if not(contains_string(columns(df), name)) then fail(string_concat("drop_column: missing column ", name))
  else match df with {
    | Frame { cols: cols, col_order: order } => Frame {
      cols: hamt_remove(cols, name),
      col_order: list_filter_string(fn (entry: string) -> neq(entry, name), order)
    }
  }
}

def is_nan[n](col: tensor[n, f32]) -> tensor[n, bool] = neq(copy(col), col)

def fill_nan[n](col: tensor[n, f32], value: f32) -> tensor[n, f32] = {
  to_tensor(map(fn (x: f32) -> if neq(x, x) then value else x, to_list(col)))
}

def drop_nan[n, k](df: Frame[n], col_name: string) -> Frame[k] = filter(df, not(is_nan(get_float_col(df, col_name))))

def any_nan[n](col: tensor[n, f32]) -> bool = fold(fn (acc: bool, flag: bool) -> or(acc, flag), false, to_list(is_nan(col)))

def count_nan[n](col: tensor[n, f32]) -> int64 = fold(fn (acc: int64, flag: bool) -> if flag then add(acc, one_i64()) else acc, zero_i64(), to_list(is_nan(col)))

def concat[n, k](frames: List[Frame[n]]) -> Frame[k] = {
  if eq(len(frames), zero_i64()) then Frame { cols: hamt_from_pairs([]), col_order: [] }
  else {
    base = index(frames, zero_i64())
    rest = drop(frames, one_i64())
    if not(all_same_schema(rest, base)) then fail("concat: schema mismatch")
    else from_pairs(map(fn (name: string) -> (name, concat_column(name, frames)), columns(base)))
  }
}

def describe[n, m](df: Frame[n]) -> Frame[m] = {
  stats = ["count", "mean", "std", "min", "25%", "50%", "75%", "max"]
  numeric = list_filter_string(fn (name: string) -> is_numeric_type(column_type(df, name)), columns(df))
  stat_col = ("stat", StringCol(stats))
  value_cols = map(fn (name: string) -> (name, describe_column(get_column(df, name))), numeric)
  from_pairs(prepend_pair_column(stat_col, value_cols))
}

def key_id(value: KeyValue) -> string = {
  match value with {
    | KeyIntValue(v) => string_concat("i:", to_string(v))
    | KeyFloatValue(v) => string_concat("f:", to_string(v))
    | KeyStringValue(v) => string_concat("s:", v)
    | KeyBoolValue(v) => string_concat("b:", to_string(v))
  }
}

def key_values[n](df: Frame[n], name: string) -> List[KeyValue] = column_key_values(get_column(df, name))

def key_values_to_column_like[m, n](keys: List[KeyValue], template: Column[n]) -> Column[m] = {
  match template with {
    | IntCol(col) => IntCol(to_tensor(map(fn (key: KeyValue) -> match key with { | KeyIntValue(v) => v | _ => fail("key type mismatch") }, keys)))
    | FloatCol(col) => FloatCol(to_tensor(map(fn (key: KeyValue) -> match key with { | KeyFloatValue(v) => v | _ => fail("key type mismatch") }, keys)))
    | StringCol(col) => StringCol(map(fn (key: KeyValue) -> match key with { | KeyStringValue(v) => v | _ => fail("key type mismatch") }, keys))
    | BoolCol(col) => fail("bool regrouping is not supported yet")
  }
}

def empty_column[n](ty: ColumnType) -> Column[n] = {
  match ty with {
    | IntType => IntCol(to_tensor([]))
    | FloatType => FloatCol(to_tensor([]))
    | StringType => StringCol([])
    | BoolType => BoolCol(to_tensor([]))
  }
}

def column_len[n](col: Column[n]) -> int64 = {
  match col with {
    | IntCol(xs) => numel(copy(xs))
    | FloatCol(xs) => numel(copy(xs))
    | StringCol(xs) => len(xs)
    | BoolCol(xs) => numel(copy(xs))
  }
}

def contains_string(values: List[string], target: string) -> bool = {
  fold(fn (acc: bool, value: string) -> or(acc, eq(value, target)), false, values)
}

def names_unique(values: List[string]) -> bool = {
  unique_rec(values, [])
}

def unique_rec(values: List[string], seen: List[string]) -> bool = {
  if eq(len(values), zero_i64()) then true else {
    current = index(values, zero_i64())
    if contains_string(seen, current) then false else unique_rec(drop(values, one_i64()), append(seen, current))
  }
}

def column_lengths_match[n](pairs: List[(string, Column[n])]) -> bool = {
  if eq(len(pairs), zero_i64()) then true else {
    first_len = column_len(index(pairs, zero_i64()).1)
    all_eq_len(drop(pairs, one_i64()), first_len)
  }
}

def all_eq_len[n](pairs: List[(string, Column[n])], expected: int64) -> bool = {
  if eq(len(pairs), zero_i64()) then true else {
    entry = index(pairs, zero_i64())
    if neq(column_len(entry.1), expected) then false else all_eq_len(drop(pairs, one_i64()), expected)
  }
}

def mask_to_index_list(items: List[(int64, bool)], acc: List[int64]) -> List[int64] = {
  if eq(len(items), zero_i64()) then acc else {
    entry = index(items, zero_i64())
    next = if entry.1 then append(acc, entry.0) else acc
    mask_to_index_list(drop(items, one_i64()), next)
  }
}

def reindex_column[n, k](col: Column[n], idx_tensor: tensor[k, int64], idx_list: List[int64]) -> Column[k] = {
  match col with {
    | IntCol(xs) => IntCol(gather(copy(xs), idx_tensor, zero_i32()))
    | FloatCol(xs) => FloatCol(gather(copy(xs), idx_tensor, zero_i32()))
    | StringCol(xs) => StringCol(list_gather_string(xs, idx_list))
    | BoolCol(xs) => BoolCol(gather(copy(xs), idx_tensor, zero_i32()))
  }
}

def list_gather_string(xs: List[string], idxs: List[int64]) -> List[string] = {
  map(fn (i: int64) -> index(xs, i), idxs)
}

def reindex_all[n](df: Frame[n], perm: tensor[n, int64]) -> Frame[n] = {
  perm_list = to_list(copy(perm))
  from_pairs(map(fn (name: string) -> (name, reindex_column(get_column(df, name), perm, perm_list)), columns(df)))
}

def orient_perm[n](perm: tensor[n, int64], ascending: bool) -> tensor[n, int64] = {
  if ascending then perm else to_tensor(reverse_ints(to_list(perm), []))
}

def reverse_ints(values: List[int64], acc: List[int64]) -> List[int64] = {
  if eq(len(values), zero_i64()) then acc else append(reverse_ints(drop(values, one_i64()), acc), index(values, zero_i64()))
}

def all_same_schema[n](frames: List[Frame[n]], base: Frame[n]) -> bool = {
  if eq(len(frames), zero_i64()) then true else {
    current = index(frames, zero_i64())
    if not(schema_eq(base, current)) then false else all_same_schema(drop(frames, one_i64()), base)
  }
}

def schema_eq[n](lhs: Frame[n], rhs: Frame[n]) -> bool = {
  if not(string_list_eq(columns(lhs), columns(rhs))) then false else schema_eq_names(columns(lhs), lhs, rhs)
}

def schema_eq_names[n](names: List[string], lhs: Frame[n], rhs: Frame[n]) -> bool = {
  if eq(len(names), zero_i64()) then true else {
    name = index(names, zero_i64())
    if not(column_type_eq(column_type(lhs, name), column_type(rhs, name))) then false else schema_eq_names(drop(names, one_i64()), lhs, rhs)
  }
}

def concat_column[n, k](name: string, frames: List[Frame[n]]) -> Column[k] = {
  sample = get_column(index(frames, zero_i64()), name)
  match sample with {
    | IntCol(col) => IntCol(to_tensor(concat_int_lists(map(fn (frame: Frame[n]) -> to_list(get_int_col(frame, name)), frames), [])))
    | FloatCol(col) => FloatCol(to_tensor(concat_float_lists(map(fn (frame: Frame[n]) -> to_list(get_float_col(frame, name)), frames), [])))
    | StringCol(col) => StringCol(concat_strings(map(fn (frame: Frame[n]) -> get_string_col(frame, name), frames), []))
    | BoolCol(col) => {
        int_list = concat_int_lists(map(fn (frame: Frame[n]) -> bools_to_ints(to_list(get_bool_col(frame, name))), frames), [])
        ints = to_tensor(int_list)
        zeros = to_tensor(map(fn (value: int64) -> zero_i64(), int_list))
        BoolCol(neq(copy(ints), zeros))
      }
  }
}

def concat_strings(parts: List[List[string]], acc: List[string]) -> List[string] = {
  if eq(len(parts), zero_i64()) then acc else concat_strings(drop(parts, one_i64()), append_all_strings(acc, index(parts, zero_i64())))
}

def is_numeric_type(ty: ColumnType) -> bool = {
  match ty with {
    | IntType => true
    | FloatType => true
    | _ => false
  }
}

def describe_column[m, n](col: Column[n]) -> Column[m] = {
  match col with {
    | FloatCol(xs) => FloatCol(to_tensor(float_stats_skip_nan(xs)))
    | IntCol(xs) => FloatCol(to_tensor(float_stats(ints_to_floats(xs))))
    | _ => fail("describe: only numeric columns are supported")
  }
}

def float_stats[n](values: tensor[n, f32]) -> List[f32] = {
  count_i = len(to_list(copy(values)))
  count = cast(count_i, f32)
  [
    count,
    mean_vec(copy(values)),
    std_vec(copy(values), one_i64()),
    min_vec(copy(values)),
    quantile_vec(copy(values), cast(0.25, f32)),
    quantile_vec(copy(values), cast(0.50, f32)),
    quantile_vec(copy(values), cast(0.75, f32)),
    max_vec(values)
  ]
}

def float_stats_skip_nan[n](values: tensor[n, f32]) -> List[f32] = {
  valid = non_nan_values(to_list(copy(values)), [])
  count_i = len(valid)
  if eq(count_i, zero_i64()) then {
    missing = nan_f32()
    [cast(0.0, f32), missing, missing, missing, missing, missing, missing, missing]
  } else {
    valid_tensor = to_tensor(valid)
    count = cast(count_i, f32)
    [
      count,
      mean_vec(copy(valid_tensor)),
      std_vec(copy(valid_tensor), one_i64()),
      min_vec(copy(valid_tensor)),
      quantile_vec(copy(valid_tensor), cast(0.25, f32)),
      quantile_vec(copy(valid_tensor), cast(0.50, f32)),
      quantile_vec(copy(valid_tensor), cast(0.75, f32)),
      max_vec(valid_tensor)
    ]
  }
}

def non_nan_values(values: List[f32], acc: List[f32]) -> List[f32] = {
  if eq(len(values), zero_i64()) then acc else {
    current = index(values, zero_i64())
    next = if neq(current, current) then acc else append(acc, current)
    non_nan_values(drop(values, one_i64()), next)
  }
}

def ints_to_floats[n](values: tensor[n, int64]) -> tensor[n, f32] = to_tensor(map(fn (x: int64) -> cast(x, f32), to_list(values)))

def bools_to_ints(values: List[bool]) -> List[int64] = {
  map(fn (flag: bool) -> if flag then one_i64() else zero_i64(), values)
}

def column_key_values[n](col: Column[n]) -> List[KeyValue] = {
  match col with {
    | IntCol(xs) => map(fn (x: int64) -> KeyIntValue(x), to_list(xs))
    | FloatCol(xs) => map(fn (x: f32) -> KeyFloatValue(x), to_list(xs))
    | StringCol(xs) => map(fn (x: string) -> KeyStringValue(x), xs)
    | BoolCol(xs) => map(fn (x: bool) -> KeyBoolValue(x), to_list(xs))
  }
}

def int_min(lhs: int64, rhs: int64) -> int64 = if lt(lhs, rhs) then lhs else rhs
def int_max(lhs: int64, rhs: int64) -> int64 = if gt(lhs, rhs) then lhs else rhs

def prepend_pair_column[n](value: (string, Column[n]), items: List[(string, Column[n])]) -> List[(string, Column[n])] = prepend_pair_column_acc(items, [value])

def list_filter_string(pred: string -> bool, items: List[string]) -> List[string] = {
  list_filter_string_acc(pred, items, [])
}

def list_filter_string_acc(pred: string -> bool, items: List[string], acc: List[string]) -> List[string] = {
  if eq(len(items), zero_i64()) then acc else {
    current = index(items, zero_i64())
    next = if pred(current) then append(acc, current) else acc
    list_filter_string_acc(pred, drop(items, one_i64()), next)
  }
}

def string_list_eq(lhs: List[string], rhs: List[string]) -> bool = {
  if neq(len(lhs), len(rhs)) then false else string_list_eq_rec(lhs, rhs)
}

def string_list_eq_rec(lhs: List[string], rhs: List[string]) -> bool = {
  if eq(len(lhs), zero_i64()) then true else if neq(index(lhs, zero_i64()), index(rhs, zero_i64())) then false else string_list_eq_rec(drop(lhs, one_i64()), drop(rhs, one_i64()))
}

def replace_name(values: List[string], old_name: string, new_name: string, acc: List[string]) -> List[string] = {
  if eq(len(values), zero_i64()) then acc else {
    head = index(values, zero_i64())
    next = if eq(head, old_name) then append(acc, new_name) else append(acc, head)
    replace_name(drop(values, one_i64()), old_name, new_name, next)
  }
}

def column_type_eq(lhs: ColumnType, rhs: ColumnType) -> bool = {
  match lhs with {
    | IntType => match rhs with { | IntType => true | _ => false }
    | FloatType => match rhs with { | FloatType => true | _ => false }
    | StringType => match rhs with { | StringType => true | _ => false }
    | BoolType => match rhs with { | BoolType => true | _ => false }
  }
}

def append_all_strings(lhs: List[string], rhs: List[string]) -> List[string] = {
  if eq(len(rhs), zero_i64()) then lhs else append_all_strings(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
}

def prepend_pair_column_acc[n](items: List[(string, Column[n])], acc: List[(string, Column[n])]) -> List[(string, Column[n])] = {
  if eq(len(items), zero_i64()) then acc else prepend_pair_column_acc(drop(items, one_i64()), append(acc, index(items, zero_i64())))
}

def concat_int_lists(parts: List[List[int64]], acc: List[int64]) -> List[int64] = {
  if eq(len(parts), zero_i64()) then acc else concat_int_lists(drop(parts, one_i64()), append_all_ints(acc, index(parts, zero_i64())))
}

def append_all_ints(lhs: List[int64], rhs: List[int64]) -> List[int64] = {
  if eq(len(rhs), zero_i64()) then lhs else append_all_ints(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
}


def concat_float_lists(parts: List[List[f32]], acc: List[f32]) -> List[f32] = {
  if eq(len(parts), zero_i64()) then acc else concat_float_lists(drop(parts, one_i64()), append_all_floats(acc, index(parts, zero_i64())))
}

def append_all_floats(lhs: List[f32], rhs: List[f32]) -> List[f32] = {
  if eq(len(rhs), zero_i64()) then lhs else append_all_floats(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
}
