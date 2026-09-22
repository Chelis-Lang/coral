module Coral.GroupBy
import Coral.Internal.Hamt (hamt_entries)
import Coral.Frame (Column, IntCol, FloatCol, Frame, KeyValue, key_id, key_values, key_values_to_column_like, get_column, get_float_col, get_int_col, with_column, from_pairs)
export (AggFn, GroupedFrame, group_by, agg_sum, agg_mean, agg_count, agg_min, agg_max, agg, value_counts)
type AggFn =
  | AggSum
  | AggMean
  | AggCount
  | AggMin
  | AggMax
type GroupedFrame[n] =
  | GroupedFrame { frame: Frame[n], key_name: string, key_template: Column[n], keys: List[KeyValue], groups: List[List[i64]] }
def zero_i64() -> i64 = cast(0, i64)
def one_i64() -> i64 = cast(1, i64)
def all_false_mask[n](template_vals: tensor[n, i64]) -> tensor[n, bool] = {
  ints = to_tensor(map(fn (unused: i64) -> zero_i64(), to_list(template_vals)))
  __borrow_migration_out_0 = neq(ints, ints)
  __borrow_migration_out_0
}
def group_by[n](df: Frame[n], key_name: string) -> GroupedFrame[n] = {
  template = get_column(df, key_name)
  grouped = group_keys(key_values(df, key_name), [], [])
  GroupedFrame { frame: df, key_name, key_template: template, keys: grouped.0, groups: grouped.1 }
}
def agg_sum[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => match get_column(df, col) with {
    | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_sum"), FloatCol(to_tensor(map(fn (rows: List[i64]) -> sum_f32(select_float_rows(to_list(xs), rows)), groups))))])
    | IntCol(xs, xmask) => {
    xs_list = to_list(xs)
    mask_list = to_list(xmask)
    sum_vals = to_tensor(map(fn (rows: List[i64]) -> sum_i64(select_int_rows(xs_list, filter_unmasked_rows(mask_list, rows))), groups))
    sum_mask = all_false_mask(sum_vals)
    from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_sum"), IntCol(sum_vals, sum_mask))])
  }
    | _ => fail("agg_sum: only float and int columns are supported")
  }
  }
def agg_mean[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => match get_column(df, col) with {
    | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_mean"), FloatCol(to_tensor(map(fn (rows: List[i64]) -> mean_f32(select_float_rows(to_list(xs), rows)), groups))))])
    | IntCol(xs, xmask) => {
    xs_list = to_list(xs)
    mask_list = to_list(xmask)
    from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_mean"), FloatCol(to_tensor(map(fn (rows: List[i64]) -> mean_i64(select_int_rows(xs_list, filter_unmasked_rows(mask_list, rows))), groups))))])
  }
    | _ => fail("agg_mean: only float and int columns are supported")
  }
  }
def agg_count[n, m](gf: GroupedFrame[n]) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => {
    count_vals = to_tensor(map(fn (rows: List[i64]) -> len(rows), groups))
    count_mask = all_false_mask(count_vals)
    from_pairs([(key_name, key_values_to_column_like(keys, key_template)), ("count", IntCol(count_vals, count_mask))])
  }
  }
def agg_min[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => match get_column(df, col) with {
    | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_min"), FloatCol(to_tensor(map(fn (rows: List[i64]) -> min_f32(select_float_rows(to_list(xs), rows)), groups))))])
    | IntCol(xs, xmask) => {
    xs_list = to_list(xs)
    mask_list = to_list(xmask)
    min_vals = to_tensor(map(fn (rows: List[i64]) -> min_i64(select_int_rows(xs_list, filter_unmasked_rows(mask_list, rows))), groups))
    min_mask = all_false_mask(min_vals)
    from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_min"), IntCol(min_vals, min_mask))])
  }
    | _ => fail("agg_min: only float and int columns are supported")
  }
  }
def agg_max[n, m](gf: GroupedFrame[n], col: string) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => match get_column(df, col) with {
    | FloatCol(xs) => from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_max"), FloatCol(to_tensor(map(fn (rows: List[i64]) -> max_f32(select_float_rows(to_list(xs), rows)), groups))))])
    | IntCol(xs, xmask) => {
    xs_list = to_list(xs)
    mask_list = to_list(xmask)
    max_vals = to_tensor(map(fn (rows: List[i64]) -> max_i64(select_int_rows(xs_list, filter_unmasked_rows(mask_list, rows))), groups))
    max_mask = all_false_mask(max_vals)
    from_pairs([(key_name, key_values_to_column_like(keys, key_template)), (string_concat(col, "_max"), IntCol(max_vals, max_mask))])
  }
    | _ => fail("agg_max: only float and int columns are supported")
  }
  }
def agg[n, m](gf: GroupedFrame[n], specs: List[(string, AggFn)]) -> Frame[m] =
  match gf with {
    | GroupedFrame { frame: df, key_name, key_template, keys, groups } => {
    df_pairs = match df with {
      | Frame { cols, col_order: order } => hamt_entries(cols)
    }
    key_col = key_values_to_column_like(keys, key_template)
    result_pairs = build_spec_pairs(df_pairs, groups, specs, [])
    from_pairs(prepend_pair_local((key_name, key_col), result_pairs, []))
  }
  }
def prepend_pair_local[n](first: (string, Column[n]), rest: List[(string, Column[n])], acc: List[(string, Column[n])]) -> List[(string, Column[n])] = prepend_pair_local_acc(rest, append(acc, first))
def prepend_pair_local_acc[n](items: List[(string, Column[n])], acc: List[(string, Column[n])]) -> List[(string, Column[n])] =
  if eq(len(items), zero_i64()) then acc else {
    hd = index(items, zero_i64())
    prepend_pair_local_acc(skip(items, one_i64()), append(acc, hd))
  }
def build_spec_pairs[n, m](df_pairs: List[(string, Column[n])], groups: List[List[i64]], specs: List[(string, AggFn)], acc: List[(string, Column[m])]) -> List[(string, Column[m])] =
  if eq(len(specs), zero_i64()) then acc else {
    spec = index(specs, zero_i64())
    col_name = spec.0
    fn0 = spec.1
    extraction = extract_pair_by_name(df_pairs, col_name, [])
    next_pair = match fn0 with {
      | AggSum => (string_concat(col_name, "_sum"), apply_op_to_col(extraction.0, groups, AggSum))
      | AggMean => (string_concat(col_name, "_mean"), apply_op_to_col(extraction.0, groups, AggMean))
      | AggCount => ("count", apply_op_to_col(extraction.0, groups, AggCount))
      | AggMin => (string_concat(col_name, "_min"), apply_op_to_col(extraction.0, groups, AggMin))
      | AggMax => (string_concat(col_name, "_max"), apply_op_to_col(extraction.0, groups, AggMax))
    }
    build_spec_pairs(extraction.1, groups, skip(specs, one_i64()), append(acc, next_pair))
  }
def extract_pair_by_name[n](pairs: List[(string, Column[n])], target: string, acc: List[(string, Column[n])]) -> (Column[n], List[(string, Column[n])]) =
  if eq(len(pairs), zero_i64()) then fail("agg: column not found") else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, target) then (head_pair.1, prepend_pair_local_acc(skip(pairs, one_i64()), acc)) else extract_pair_by_name(skip(pairs, one_i64()), target, append(acc, head_pair))
  }
def apply_op_to_col[n, m](col: Column[n], groups: List[List[i64]], op: AggFn) -> Column[m] =
  match col with {
    | FloatCol(xs) => apply_op_float(to_list(xs), groups, op)
    | IntCol(xs, mask) => apply_op_int(to_list(xs), to_list(mask), groups, op)
    | _ => fail("agg: only float and int columns are supported")
  }
def apply_op_float[n](xs: List[f32], groups: List[List[i64]], op: AggFn) -> Column[n] =
  match op with {
    | AggCount => {
    counts = to_tensor(map(fn (rows: List[i64]) -> len(rows), groups))
    IntCol(counts, all_false_mask(counts))
  }
    | _ => FloatCol(to_tensor(map(fn (rows: List[i64]) -> float_op_on_rows(xs, rows, op), groups)))
  }
def float_op_on_rows(xs: List[f32], rows: List[i64], op: AggFn) -> f32 = {
  selected = select_float_rows(xs, rows)
  match op with {
    | AggSum => sum_f32(selected)
    | AggMean => mean_f32(selected)
    | AggMin => min_f32(selected)
    | AggMax => max_f32(selected)
    | AggCount => cast(len(rows), f32)
  }
}
def apply_op_int[n](xs: List[i64], mask: List[bool], groups: List[List[i64]], op: AggFn) -> Column[n] =
  match op with {
    | AggCount => {
    counts = to_tensor(map(fn (rows: List[i64]) -> len(rows), groups))
    IntCol(counts, all_false_mask(counts))
  }
    | AggMean => FloatCol(to_tensor(map(fn (rows: List[i64]) -> mean_i64(select_int_rows(xs, filter_unmasked_rows(mask, rows))), groups)))
    | _ => {
    vals = to_tensor(map(fn (rows: List[i64]) -> int_op_on_rows(xs, mask, rows, op), groups))
    IntCol(vals, all_false_mask(vals))
  }
  }
def int_op_on_rows(xs: List[i64], mask: List[bool], rows: List[i64], op: AggFn) -> i64 = {
  selected = select_int_rows(xs, filter_unmasked_rows(mask, rows))
  match op with {
    | AggSum => sum_i64(selected)
    | AggMin => min_i64(selected)
    | AggMax => max_i64(selected)
    | _ => fail("int_op_on_rows: unsupported")
  }
}
def value_counts[n, m](df: Frame[n], col_name: string) -> Frame[m] = {
  gf = group_by(df, col_name)
  agg_count(gf)
}
def merge_agg[m](base: Frame[m], extra: Frame[m], name: string) -> Frame[m] = with_column(base, name, get_column(extra, name))
def group_keys(keys: List[KeyValue], seen_keys: List[KeyValue], groups: List[List[i64]]) -> (List[KeyValue], List[List[i64]]) = group_keys_from(keys, seen_keys, groups, zero_i64())
def group_keys_from(keys: List[KeyValue], seen_keys: List[KeyValue], groups: List[List[i64]], idx: i64) -> (List[KeyValue], List[List[i64]]) =
  if gte(idx, len(keys)) then (seen_keys, groups) else {
    key = index(keys, idx)
    match find_key_index(seen_keys, key, zero_i64()) with {
      | Some(group_idx) => group_keys_from(keys, seen_keys, append_row(groups, group_idx, idx), add(idx, one_i64()))
      | None => group_keys_from(keys, append(seen_keys, key), append(groups, [idx]), add(idx, one_i64()))
    }
  }
def find_key_index(keys: List[KeyValue], key: KeyValue, idx: i64) -> Option[i64] = if gte(idx, len(keys)) then None else if eq(key_id(index(keys, idx)), key_id(key)) then Some(idx) else find_key_index(keys, key, add(idx, one_i64()))
def append_row(groups: List[List[i64]], target: i64, row: i64) -> List[List[i64]] = append_row_from(groups, target, row, zero_i64(), [])
def append_row_from(groups: List[List[i64]], target: i64, row: i64, idx: i64, acc: List[List[i64]]) -> List[List[i64]] =
  if eq(len(groups), zero_i64()) then acc else {
    current = index(groups, zero_i64())
    next = if eq(idx, target) then append(acc, append(current, row)) else append(acc, current)
    append_row_from(skip(groups, one_i64()), target, row, add(idx, one_i64()), next)
  }
def select_float_rows(values: List[f32], rows: List[i64]) -> List[f32] = map(fn (row: i64) -> index(values, row), rows)
def select_int_rows(values: List[i64], rows: List[i64]) -> List[i64] = map(fn (row: i64) -> index(values, row), rows)
def filter_unmasked_rows(masks: List[bool], rows: List[i64]) -> List[i64] = fold(fn (acc: List[i64], row: i64) -> if index(masks, row) then acc else append(acc, row), [], rows)
def sum_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> add(acc, value), cast(0.0, f32), values)
def sum_i64(values: List[i64]) -> i64 = fold(fn (acc: i64, value: i64) -> add(acc, value), cast(0, i64), values)
def mean_f32(values: List[f32]) -> f32 = div(sum_f32(values), cast(len(values), f32))
def mean_i64(values: List[i64]) -> f32 = div(cast(sum_i64(values), f32), cast(len(values), f32))
def min_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> if lt(value, acc) then value else acc, index(values, zero_i64()), skip(values, one_i64()))
def max_f32(values: List[f32]) -> f32 = fold(fn (acc: f32, value: f32) -> if gt(value, acc) then value else acc, index(values, zero_i64()), skip(values, one_i64()))
def min_i64(values: List[i64]) -> i64 = fold(fn (acc: i64, value: i64) -> if lt(value, acc) then value else acc, index(values, zero_i64()), skip(values, one_i64()))
def max_i64(values: List[i64]) -> i64 = fold(fn (acc: i64, value: i64) -> if gt(value, acc) then value else acc, index(values, zero_i64()), skip(values, one_i64()))
