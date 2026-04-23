module Coral.Reshape
import Coral.Frame (Column, Frame, columns, from_pairs, get_column, key_id, key_values, nrows, with_column, get_float_col, get_string_col, drop_column)
export (pivot, melt, stack, unstack)

def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))

def contains_string_local(values: List[string], target: string) -> bool = {
  fold(fn (acc: bool, v: string) -> or(acc, eq(v, target)), false, values)
}

def unique_strings(values: List[string], seen: List[string]) -> List[string] = {
  if eq(len(values), zero_i64()) then seen
  else {
    v = index(values, zero_i64())
    next = if contains_string_local(seen, v) then seen else append(seen, v)
    unique_strings(drop(values, one_i64()), next)
  }
}

def find_matching_row(col_a: List[string], key_a: string, col_b: List[string], key_b: string, row: int64, total: int64) -> int64 = {
  if gte(row, total) then neg(one_i64())
  else if and(eq(index(col_a, row), key_a), eq(index(col_b, row), key_b))
    then row
    else find_matching_row(col_a, key_a, col_b, key_b, add(row, one_i64()), total)
}

def pivot_col_for_key(index_keys: List[string], col_vals: List[string], value_vals: List[f32], index_vals: List[string], col_key: string, row_count: int64, acc: List[f32]) -> List[f32] = {
  if eq(len(index_keys), zero_i64()) then acc
  else {
    ik = index(index_keys, zero_i64())
    r = find_matching_row(index_vals, ik, col_vals, col_key, zero_i64(), row_count)
    v = if lt(r, zero_i64()) then nan_f32() else index(value_vals, r)
    pivot_col_for_key(drop(index_keys, one_i64()), col_vals, value_vals, index_vals, col_key, row_count, append(acc, v))
  }
}

def pivot_add_columns[m](out: Frame[m], col_keys: List[string], index_keys: List[string], col_vals: List[string], value_vals: List[f32], index_vals: List[string], row_count: int64) -> Frame[m] = {
  if eq(len(col_keys), zero_i64()) then out
  else {
    ck = index(col_keys, zero_i64())
    new_col = FloatCol(to_tensor(pivot_col_for_key(index_keys, col_vals, value_vals, index_vals, ck, row_count, [])))
    next = with_column(out, ck, new_col)
    pivot_add_columns(next, drop(col_keys, one_i64()), index_keys, col_vals, value_vals, index_vals, row_count)
  }
}

def pivot[n, m](df: Frame[n], index_col: string, columns_col: string, values_col: string) -> Frame[m] = {
  match get_column(df, values_col) with {
    | FloatCol(value_tensor) => {
      row_count = nrows(df)
      index_vals = get_string_col(df, index_col)
      col_vals = get_string_col(df, columns_col)
      value_vals = to_list(value_tensor)
      index_keys = unique_strings(index_vals, [])
      col_keys = unique_strings(col_vals, [])
      index_out = from_pairs([(index_col, StringCol(index_keys))])
      pivot_add_columns(index_out, col_keys, index_keys, col_vals, value_vals, index_vals, row_count)
    }
    | _ => fail("pivot: values_col must be float")
  }
}

def melt_one_row[n](df: Frame[n], value_cols: List[string], row: int64, var_acc: List[string], val_acc: List[f32]) -> (List[string], List[f32]) = {
  if eq(len(value_cols), zero_i64()) then (var_acc, val_acc)
  else {
    col_name = index(value_cols, zero_i64())
    cell = match get_column(df, col_name) with {
      | FloatCol(xs) => index(to_list(xs), row)
      | _ => fail("melt: value_cols must be float")
    }
    melt_one_row(df, drop(value_cols, one_i64()), row, append(var_acc, col_name), append(val_acc, cell))
  }
}

def melt_var_val_rows[n](df: Frame[n], value_cols: List[string], num_rows: int64, row: int64, var_acc: List[string], val_acc: List[f32]) -> (List[string], List[f32]) = {
  if gte(row, num_rows) then (var_acc, val_acc)
  else {
    pair = melt_one_row(df, value_cols, row, var_acc, val_acc)
    melt_var_val_rows(df, value_cols, num_rows, add(row, one_i64()), pair.0, pair.1)
  }
}

def replicate_string(value: string, count: int64, acc: List[string]) -> List[string] = {
  if lte(count, zero_i64()) then acc else replicate_string(value, sub(count, one_i64()), append(acc, value))
}

def melt_id_col[n](df: Frame[n], id_col: string, value_cols_count: int64, num_rows: int64, row: int64, acc: List[string]) -> List[string] = {
  if gte(row, num_rows) then acc
  else {
    cell = index(get_string_col(df, id_col), row)
    next = replicate_string(cell, value_cols_count, acc)
    melt_id_col(df, id_col, value_cols_count, num_rows, add(row, one_i64()), next)
  }
}

def melt_build_id_cols[n, m](id_cols: List[string], df: Frame[n], value_cols_count: int64, num_rows: int64, base: Frame[m]) -> Frame[m] = {
  if eq(len(id_cols), zero_i64()) then base
  else {
    name = index(id_cols, zero_i64())
    col_data = melt_id_col(df, name, value_cols_count, num_rows, zero_i64(), [])
    next = with_column(base, name, StringCol(col_data))
    melt_build_id_cols(drop(id_cols, one_i64()), df, value_cols_count, num_rows, next)
  }
}

def melt[n, m](df: Frame[n], id_cols: List[string], value_cols: List[string]) -> Frame[m] = {
  num_rows = nrows(df)
  value_cols_count = len(value_cols)
  var_val = melt_var_val_rows(df, value_cols, num_rows, zero_i64(), [], [])
  var_col = StringCol(var_val.0)
  val_col = FloatCol(to_tensor(var_val.1))
  base = from_pairs([("variable", var_col), ("value", val_col)])
  melt_build_id_cols(id_cols, df, value_cols_count, num_rows, base)
}

def stack[n, m](df: Frame[n]) -> Frame[m] = melt(df, [], columns(df))

def unstack[n, m](df: Frame[n], index_col: string) -> Frame[m] = pivot(df, index_col, "variable", "value")
