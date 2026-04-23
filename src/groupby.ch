module Coral.GroupBy
import Coral.Frame (Column, Frame, KeyValue, key_id, key_values, key_values_to_column_like, get_column, get_float_col, get_int_col, with_column, from_pairs)
export (AggFn, GroupedFrame, group_by, agg_sum, agg_mean, agg_count, agg_min, agg_max, agg, value_counts)

type AggFn =
  | AggSum
  | AggMean
  | AggCount
  | AggMin
  | AggMax

type GroupedFrame[n] =
  | GroupedFrame { frame: Frame[n], key_name: string, key_template: Column[n], keys: List[KeyValue], groups: List[List[int64]] }

def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)

def group_by[n](df: Frame[n], key_name: string) -> GroupedFrame[n] = {
  template = get_column(df, key_name)
  grouped = group_keys(key_values(df, key_name), [], [])
  GroupedFrame { frame: df, key_name: key_name, key_template: template, keys: grouped.0, groups: grouped.1 }
}

def agg_sum[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } => match get_column(df, col) with {
      | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_sum"), FloatCol(to_tensor(map(fn (rows: List[int64]) -> sum_f32(select_float_rows(to_list(xs), rows)), groups))) )])
      | IntCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_sum"), IntCol(to_tensor(map(fn (rows: List[int64]) -> sum_i64(select_int_rows(to_list(xs), rows)), groups))) )])
      | _ => fail("agg_sum: only float and int columns are supported")
    }
  }
}

def agg_mean[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } => match get_column(df, col) with {
      | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_mean"), FloatCol(to_tensor(map(fn (rows: List[int64]) -> mean_f32(select_float_rows(to_list(xs), rows)), groups))) )])
      | IntCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_mean"), FloatCol(to_tensor(map(fn (rows: List[int64]) -> mean_i64(select_int_rows(to_list(xs), rows)), groups))) )])
      | _ => fail("agg_mean: only float and int columns are supported")
    }
  }
}

def agg_count[n, m](gf: GroupedFrame[n]) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } =>
      from_pairs([(key_name, key_values_to_column_like(keys, key_template)), ("count", IntCol(to_tensor(map(fn (rows: List[int64]) -> len(rows), groups))))])
  }
}

def agg_min[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } => match get_column(df, col) with {
      | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_min"), FloatCol(to_tensor(map(fn (rows: List[int64]) -> min_f32(select_float_rows(to_list(xs), rows)), groups))) )])
      | IntCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_min"), IntCol(to_tensor(map(fn (rows: List[int64]) -> min_i64(select_int_rows(to_list(xs), rows)), groups))) )])
      | _ => fail("agg_min: only float and int columns are supported")
    }
  }
}

def agg_max[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } => match get_column(df, col) with {
      | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_max"), FloatCol(to_tensor(map(fn (rows: List[int64]) -> max_f32(select_float_rows(to_list(xs), rows)), groups))) )])
      | IntCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_max"), IntCol(to_tensor(map(fn (rows: List[int64]) -> max_i64(select_int_rows(to_list(xs), rows)), groups))) )])
      | _ => fail("agg_max: only float and int columns are supported")
    }
  }
}

def agg[n, m](gf: GroupedFrame[n], specs: List[(string, AggFn)]) -> Frame[m] = {
  match gf with {
    | GroupedFrame { frame: df, key_name: key_name, key_template: key_template, keys: keys, groups: groups } =>
        apply_specs(from_pairs([(key_name, key_values_to_column_like(keys, key_template))]), gf, specs)
  }
}

def apply_specs[n, m](base: Frame[m], gf: GroupedFrame[n], specs: List[(string, AggFn)]) -> Frame[m] = {
  if eq(len(specs), zero_i64()) then base else {
    spec = index(specs, zero_i64())
    col = spec.0
    fn0 = spec.1
    next = match fn0 with {
      | AggSum => merge_agg(base, agg_sum(gf, col), string_concat(col, "_sum"))
      | AggMean => merge_agg(base, agg_mean(gf, col), string_concat(col, "_mean"))
      | AggCount => merge_agg(base, agg_count(gf), "count")
      | AggMin => merge_agg(base, agg_min(gf, col), string_concat(col, "_min"))
      | AggMax => merge_agg(base, agg_max(gf, col), string_concat(col, "_max"))
    }
    apply_specs(next, gf, drop(specs, one_i64()))
  }
}

def value_counts[n, m](df: Frame[n], col_name: string) -> Frame[m] = {
  gf = group_by(df, col_name)
  agg_count(gf)
}

def merge_agg[m](base: Frame[m], extra: Frame[m], name: string) -> Frame[m] = with_column(base, name, get_column(extra, name))

def group_keys(keys: List[KeyValue], seen_keys: List[KeyValue], groups: List[List[int64]]) -> (List[KeyValue], List[List[int64]]) = {
  group_keys_from(keys, seen_keys, groups, zero_i64())
}

def group_keys_from(keys: List[KeyValue], seen_keys: List[KeyValue], groups: List[List[int64]], idx: int64) -> (List[KeyValue], List[List[int64]]) = {
  if gte(idx, len(keys)) then (seen_keys, groups) else {
    key = index(keys, idx)
    match find_key_index(seen_keys, key, zero_i64()) with {
      | Some(group_idx) => group_keys_from(keys, seen_keys, append_row(groups, group_idx, idx), add(idx, one_i64()))
      | None => group_keys_from(keys, append(seen_keys, key), append(groups, [idx]), add(idx, one_i64()))
    }
  }
}

def find_key_index(keys: List[KeyValue], key: KeyValue, idx: int64) -> Option[int64] = {
  if gte(idx, len(keys)) then None else if eq(key_id(index(keys, idx)), key_id(key)) then Some(idx) else find_key_index(keys, key, add(idx, one_i64()))
}

def append_row(groups: List[List[int64]], target: int64, row: int64) -> List[List[int64]] = append_row_from(groups, target, row, zero_i64(), [])

def append_row_from(groups: List[List[int64]], target: int64, row: int64, idx: int64, acc: List[List[int64]]) -> List[List[int64]] = {
  if eq(len(groups), zero_i64()) then acc else {
    current = index(groups, zero_i64())
    next = if eq(idx, target) then append(acc, append(current, row)) else append(acc, current)
    append_row_from(drop(groups, one_i64()), target, row, add(idx, one_i64()), next)
  }
}

def select_float_rows(values: List[f32], rows: List[int64]) -> List[f32] = map(fn (row: int64) -> index(values, row), rows)
def select_int_rows(values: List[int64], rows: List[int64]) -> List[int64] = map(fn (row: int64) -> index(values, row), rows)

def sum_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> add(acc, value), cast(0.0, f32), values)
def sum_i64(values: List[int64]) -> int64 = fold(fn (acc: int64, value: int64) -> add(acc, value), cast(0, int64), values)
def mean_f32(values: List[f32]) -> f32 = div(sum_f32(values), cast(len(values), f32))
def mean_i64(values: List[int64]) -> f32 = div(cast(sum_i64(values), f32), cast(len(values), f32))

def min_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> if lt(value, acc) then value else acc, index(values, zero_i64()), drop(values, one_i64()))
def max_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> if gt(value, acc) then value else acc, index(values, zero_i64()), drop(values, one_i64()))
def min_i64(values: List[int64]) -> int64 = fold(fn (acc: int64, value: int64) -> if lt(value, acc) then value else acc, index(values, zero_i64()), drop(values, one_i64()))
def max_i64(values: List[int64]) -> int64 = fold(fn (acc: int64, value: int64) -> if gt(value, acc) then value else acc, index(values, zero_i64()), drop(values, one_i64()))
