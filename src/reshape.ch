module Coral.Reshape
import Coral.Internal.Hamt (hamt_entries)
import Coral.Frame (Column, FloatCol, StringCol, Frame, columns, from_pairs, get_column, key_id, key_values, nrows, with_column, get_float_col, get_string_col, drop_column)
export (pivot, melt, stack, unstack)
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def contains_string_local(values: List[string], target: string) -> bool = fold(fn (acc: bool, v: string) -> or(acc, eq(v, target)), false, values)
def unique_strings(values: List[string], seen: List[string]) -> List[string] =
  if eq(len(values), zero_i64()) then seen else {
    v = index(values, zero_i64())
    next = if contains_string_local(seen, v) then seen else append(seen, v)
    unique_strings(drop(values, one_i64()), next)
  }
def find_matching_row(col_a: List[string], key_a: string, col_b: List[string], key_b: string, row: int64, total: int64) -> int64 = if gte(row, total) then neg(one_i64()) else if and(eq(index(col_a, row), key_a), eq(index(col_b, row), key_b)) then row else find_matching_row(col_a, key_a, col_b, key_b, add(row, one_i64()), total)
def pivot_col_for_key(index_keys: List[string], col_vals: List[string], value_vals: List[f32], index_vals: List[string], col_key: string, row_count: int64, acc: List[f32]) -> List[f32] =
  if eq(len(index_keys), zero_i64()) then acc else {
    ik = index(index_keys, zero_i64())
    r = find_matching_row(index_vals, ik, col_vals, col_key, zero_i64(), row_count)
    v = if lt(r, zero_i64()) then nan_f32() else index(value_vals, r)
    pivot_col_for_key(drop(index_keys, one_i64()), col_vals, value_vals, index_vals, col_key, row_count, append(acc, v))
  }
def pivot_add_columns[m](out: Frame[m], col_keys: List[string], index_keys: List[string], col_vals: List[string], value_vals: List[f32], index_vals: List[string], row_count: int64) -> Frame[m] =
  if eq(len(col_keys), zero_i64()) then out else {
    ck = index(col_keys, zero_i64())
    new_col = FloatCol(to_tensor(pivot_col_for_key(index_keys, col_vals, value_vals, index_vals, ck, row_count, [])))
    next = with_column(out, ck, new_col)
    pivot_add_columns(next, drop(col_keys, one_i64()), index_keys, col_vals, value_vals, index_vals, row_count)
  }
def pivot[n, m](df: Frame[n], index_col: string, columns_col: string, values_col: string) -> Frame[m] =
  match df with {
    | Frame { cols, col_order: order } => {
    df_pairs = hamt_entries(cols)
    extracted_values = extract_named_pair_local(df_pairs, values_col, [])
    extracted_index = extract_named_pair_local(extracted_values.1, index_col, [])
    extracted_columns = extract_named_pair_local(extracted_index.1, columns_col, [])
    pivot_columns_inner(extracted_values.0, extracted_index.0, extracted_columns.0, index_col, columns_col)
  }
  }
def extract_named_pair_local[n](pairs: List[(string, Column[n])], target: string, acc: List[(string, Column[n])]) -> (Column[n], List[(string, Column[n])]) =
  if eq(len(pairs), zero_i64()) then fail(string_concat("pivot/melt: missing column ", target)) else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, target) then (head_pair.1, drain_pair_list(drop(pairs, one_i64()), acc)) else extract_named_pair_local(drop(pairs, one_i64()), target, append(acc, head_pair))
  }
def drain_pair_list[n](src: List[(string, Column[n])], dst: List[(string, Column[n])]) -> List[(string, Column[n])] =
  if eq(len(src), zero_i64()) then dst else {
    hd = index(src, zero_i64())
    drain_pair_list(drop(src, one_i64()), append(dst, hd))
  }
def pivot_columns_inner[n, m](values_col_data: Column[n], index_col_data: Column[n], columns_col_data: Column[n], index_col_name: string, columns_col_name: string) -> Frame[m] =
  match values_col_data with {
    | FloatCol(value_tensor) => {
    index_vals = match index_col_data with {
      | StringCol(xs) => xs
      | _ => fail("pivot: index_col must be string")
    }
    col_vals = match columns_col_data with {
      | StringCol(xs) => xs
      | _ => fail("pivot: columns_col must be string")
    }
    value_vals = to_list(value_tensor)
    row_count = cast(len(value_vals), int64)
    index_keys = unique_strings(index_vals, [])
    col_keys = unique_strings(col_vals, [])
    index_out = from_pairs([(index_col_name, StringCol(index_keys))])
    pivot_add_columns(index_out, col_keys, index_keys, col_vals, value_vals, index_vals, row_count)
  }
    | _ => fail("pivot: values_col must be float")
  }
def melt_append_col_pass(id_vals: List[string], num_rows: int64, row: int64, acc: List[string]) -> List[string] = if gte(row, num_rows) then acc else melt_append_col_pass(id_vals, num_rows, add(row, one_i64()), append(acc, index(id_vals, row)))
def melt_repeat_col(id_vals: List[string], num_rows: int64, reps: int64, acc: List[string]) -> List[string] = if lte(reps, zero_i64()) then acc else melt_repeat_col(id_vals, num_rows, sub(reps, one_i64()), melt_append_col_pass(id_vals, num_rows, zero_i64(), acc))
def melt[n, m](df: Frame[n], id_cols: List[string], value_cols: List[string]) -> Frame[m] =
  match df with {
    | Frame { cols, col_order: order } => {
    df_pairs = hamt_entries(cols)
    id_extract = extract_named_pairs_local(df_pairs, id_cols, [], [])
    id_pairs_owned = id_extract.0
    remaining_after_ids = id_extract.1
    val_extract = extract_named_pairs_local(remaining_after_ids, value_cols, [], [])
    val_pairs_owned = val_extract.0
    num_rows = if eq(len(val_pairs_owned), zero_i64()) then zero_i64() else first_pair_column_length(val_pairs_owned)
    var_val = build_melt_var_val(val_pairs_owned, value_cols, num_rows, [], [])
    var_col = StringCol(var_val.0)
    val_col = FloatCol(to_tensor(var_val.1))
    base = from_pairs([("variable", var_col), ("value", val_col)])
    melt_build_id_cols_from_pairs(id_pairs_owned, len(value_cols), num_rows, base)
  }
  }
def first_pair_column_length[n](pairs: List[(string, Column[n])]) -> int64 = {
  head_pair = index(pairs, zero_i64())
  column_len(head_pair.1)
}
def extract_named_pairs_local[n](pairs: List[(string, Column[n])], names: List[string], extracted: List[(string, Column[n])], remaining: List[(string, Column[n])]) -> (List[(string, Column[n])], List[(string, Column[n])]) =
  if eq(len(names), zero_i64()) then (extracted, drain_pair_list(pairs, remaining)) else {
    name = index(names, zero_i64())
    extraction = extract_named_pair_local(pairs, name, [])
    extract_named_pairs_local(extraction.1, drop(names, one_i64()), append(extracted, (name, extraction.0)), remaining)
  }
def build_melt_var_val[n](pairs: List[(string, Column[n])], value_cols: List[string], num_rows: int64, var_acc: List[string], val_acc: List[f32]) -> (List[string], List[f32]) =
  if eq(len(pairs), zero_i64()) then (var_acc, val_acc) else {
    head_pair = index(pairs, zero_i64())
    name = head_pair.0
    cell_list = match head_pair.1 with {
      | FloatCol(xs) => to_list(xs)
      | _ => fail("melt: value_cols must be float")
    }
    next_var = append_names(var_acc, name, num_rows, zero_i64())
    next_val = append_floats(val_acc, cell_list)
    build_melt_var_val(drop(pairs, one_i64()), drop(value_cols, one_i64()), num_rows, next_var, next_val)
  }
def append_names(acc: List[string], name: string, n: int64, i: int64) -> List[string] = if gte(i, n) then acc else append_names(append(acc, name), name, n, add(i, one_i64()))
def append_floats(lhs: List[f32], rhs: List[f32]) -> List[f32] = if eq(len(rhs), zero_i64()) then lhs else append_floats(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def melt_build_id_cols_from_pairs[n, m](id_pairs: List[(string, Column[n])], value_cols_count: int64, num_rows: int64, base: Frame[m]) -> Frame[m] =
  if eq(len(id_pairs), zero_i64()) then base else {
    head_pair = index(id_pairs, zero_i64())
    name = head_pair.0
    id_strs = match head_pair.1 with {
      | StringCol(xs) => xs
      | _ => fail("melt: id_cols must be string")
    }
    col_data = melt_repeat_col(id_strs, num_rows, value_cols_count, [])
    next = with_column(base, name, StringCol(col_data))
    melt_build_id_cols_from_pairs(drop(id_pairs, one_i64()), value_cols_count, num_rows, next)
  }
def stack[n, m](df: Frame[n]) -> Frame[m] = melt(df, [], columns(df))
def unstack[n, m](df: Frame[n], index_col: string) -> Frame[m] = pivot(df, index_col, "variable", "value")
