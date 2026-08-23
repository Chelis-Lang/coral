module Coral.Frame
import Coral.Internal.Hamt (Hamt, hamt_entries, hamt_from_pairs, hamt_get, hamt_put, hamt_remove)
import Nautilus.Stats (mean_vec, min_vec, max_vec, quantile_vec, std_vec)
export (ColumnType, Column, KeyValue, Frame, from_columns, from_pairs, empty, get_column, get_float_col, get_int_col, get_string_col, get_bool_col, columns, column_type, nrows, ncols, filter, head, tail, slice, sort_by, with_column, mutate, rename, drop_column, is_nan, fill_nan, drop_nan, any_nan, count_nan, is_nan_col, fill_nan_col, drop_nan_col, any_nan_col, count_nan_col, concat, describe, key_id, key_values, key_values_to_column_like, int_col_of_list)
type ColumnType =
  | IntType
  | FloatType
  | StringType
  | BoolType
type Column[n] =
  | IntCol(tensor[n, int64], tensor[n, bool])
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
def one_i64() -> int64 = cast(1, int64)
def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))
def bool_list_to_tensor[n](values: List[bool]) -> tensor[n, bool] = {
  ints = to_tensor(map(fn (flag: bool) -> if flag then one_i64() else zero_i64(), values))
  zeros = to_tensor(map(fn (flag: bool) -> zero_i64(), values))
  __borrow_migration_out_0 = neq(ints, zeros)
  __borrow_migration_out_0
}
def zeros_bool_n[n](template: tensor[n, int64]) -> tensor[n, bool] = bool_list_to_tensor(map(fn (unused: int64) -> false, to_list(template)))
def int_col_of_list[n](values: List[int64]) -> Column[n] = {
  xs = to_tensor(values)
  zm = zeros_bool_n(xs)
  IntCol(xs, zm)
}
def from_columns[n](cols: Dict[string, Column[n]]) -> Frame[n] = from_pairs(dict_entries(cols))
def from_pairs[n](pairs: List[(string, Column[n])]) -> Frame[n] = if not(names_unique(map(fn (pair: (string, Column[n])) -> pair.0, pairs))) then fail("from_pairs: duplicate column name") else if not(column_lengths_match(pairs)) then fail("from_pairs: mismatched column lengths") else Frame { cols: hamt_from_pairs(pairs), col_order: map(fn (pair: (string, Column[n])) -> pair.0, pairs) }
def empty[n](schema: Dict[string, ColumnType]) -> Frame[n] = {
  entries = map(fn (pair: (string, ColumnType)) -> {
    name = pair.0
    ty = pair.1
    (name, empty_column(ty))
  }, dict_entries(schema))
  Frame { cols: hamt_from_pairs(entries), col_order: map(fn (pair: (string, ColumnType)) -> pair.0, dict_entries(schema)) }
}
def get_column[n](df: Frame[n], name: string) -> Column[n] =
  match df with {
    | Frame { cols, col_order: order } => match hamt_get(cols, name) with {
    | Some(value) => value
    | None => fail(string_concat("missing column: ", name))
  }
  }
def get_float_col[n](df: Frame[n], name: string) -> tensor[n, f32] =
  match get_column(df, name) with {
    | FloatCol(col) => col
    | _ => fail(string_concat("column is not float: ", name))
  }
def get_int_col[n](df: Frame[n], name: string) -> tensor[n, int64] =
  match get_column(df, name) with {
    | IntCol(col, imask) => col
    | _ => fail(string_concat("column is not int: ", name))
  }
def get_int_mask[n](df: Frame[n], name: string) -> tensor[n, bool] =
  match get_column(df, name) with {
    | IntCol(gmvals, mask) => mask
    | _ => fail(string_concat("column is not int: ", name))
  }
def get_string_col[n](df: Frame[n], name: string) -> List[string] =
  match get_column(df, name) with {
    | StringCol(col) => col
    | _ => fail(string_concat("column is not string: ", name))
  }
def get_bool_col[n](df: Frame[n], name: string) -> tensor[n, bool] =
  match get_column(df, name) with {
    | BoolCol(col) => col
    | _ => fail(string_concat("column is not bool: ", name))
  }
def columns[n](df: Frame[n]) -> List[string] =
  match df with {
    | Frame { cols, col_order: order } => order
  }
def column_type[n](df: Frame[n], name: string) -> ColumnType =
  match get_column(df, name) with {
    | IntCol(ival, imask) => IntType
    | FloatCol(_) => FloatType
    | StringCol(_) => StringType
    | BoolCol(_) => BoolType
  }
def nrows[n](df: Frame[n]) -> int64 = {
  names = columns(df)
  if eq(len(names), zero_i64()) then zero_i64() else column_len(get_column(df, index(names, zero_i64())))
}
def ncols[n](df: Frame[n]) -> int64 = len(columns(df))
def filter[n, k](df: Frame[n], mask: tensor[n, bool]) -> Frame[k] = {
  mask_list = to_list(mask)
  mask_size = cast(len(mask_list), int64)
  idx_list = mask_to_index_list(enumerate(mask_list), [])
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    if eq(len(idx_list), zero_i64()) then from_pairs(reorder_column_pairs(map(fn (pair: (string, Column[n])) -> (pair.0, empty_column_like(pair.1)), pairs), order, [])) else {
      idx = to_tensor(idx_list)
      reindexed = map(fn (pair: (string, Column[n])) -> (pair.0, reindex_column(pair.1, idx, idx_list)), pairs)
      from_pairs(reorder_column_pairs(reindexed, order, []))
    }
  }
  }
}
def head[n, k](df: Frame[n], count: int64) -> Frame[k] = slice(df, zero_i64(), int_max(count, zero_i64()))
def tail[n, k](df: Frame[n], count: int64) -> Frame[k] =
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    kept = int_max(count, zero_i64())
    tailed = map(fn (pair: (string, Column[n])) -> (pair.0, column_tail(pair.1, kept)), pairs)
    from_pairs(reorder_column_pairs(tailed, order, []))
  }
  }
def reorder_column_pairs[n](pairs: List[(string, Column[n])], order: List[string], acc: List[(string, Column[n])]) -> List[(string, Column[n])] =
  if eq(len(order), zero_i64()) then acc else {
    name = index(order, zero_i64())
    matched = extract_named_column(pairs, name, [])
    reorder_column_pairs(matched.1, drop(order, one_i64()), append(acc, (name, matched.0)))
  }
def extract_named_column[n](pairs: List[(string, Column[n])], target: string, acc: List[(string, Column[n])]) -> (Column[n], List[(string, Column[n])]) =
  if eq(len(pairs), zero_i64()) then fail("extract_named_column: name not found") else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, target) then (head_pair.1, append_pair_list(acc, drop(pairs, one_i64()))) else extract_named_column(drop(pairs, one_i64()), target, append(acc, head_pair))
  }
def append_pair_list[n](lhs: List[(string, Column[n])], rhs: List[(string, Column[n])]) -> List[(string, Column[n])] = if eq(len(rhs), zero_i64()) then lhs else append_pair_list(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def column_tail[n, k](col: Column[n], count: int64) -> Column[k] =
  match col with {
    | IntCol(xs, mask) => {
    total = numel(xs)
    kept = int_min(count, total)
    start = sub(total, kept)
    idx_list = range(start, total)
    idx = to_tensor(idx_list)
    IntCol(gather(xs, idx, cast(0, int32)), gather(mask, idx, cast(0, int32)))
  }
    | FloatCol(xs) => {
    total = numel(xs)
    kept = int_min(count, total)
    start = sub(total, kept)
    idx_list = range(start, total)
    idx = to_tensor(idx_list)
    FloatCol(gather(xs, idx, cast(0, int32)))
  }
    | StringCol(xs) => {
    total = len(xs)
    kept = int_min(count, total)
    start = sub(total, kept)
    idx_list = range(start, total)
    StringCol(list_gather_string(xs, idx_list))
  }
    | BoolCol(xs) => {
    total = numel(xs)
    kept = int_min(count, total)
    start = sub(total, kept)
    idx_list = range(start, total)
    idx = to_tensor(idx_list)
    BoolCol(gather(xs, idx, cast(0, int32)))
  }
  }
def slice[n, k](df: Frame[n], start: int64, finish: int64) -> Frame[k] =
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    sliced = map(fn (pair: (string, Column[n])) -> (pair.0, slice_column_range(pair.1, start, finish)), pairs)
    from_pairs(reorder_column_pairs(sliced, order, []))
  }
  }
def slice_column_range[n, k](col: Column[n], start: int64, finish: int64) -> Column[k] =
  match col with {
    | IntCol(xs, mask) => {
    total = numel(xs)
    lo = int_max(zero_i64(), start)
    hi = int_min(total, finish)
    if lte(hi, lo) then IntCol(to_tensor([]), bool_list_to_tensor([])) else {
      idx_list = range(lo, hi)
      idx = to_tensor(idx_list)
      IntCol(gather(xs, idx, cast(0, int32)), gather(mask, idx, cast(0, int32)))
    }
  }
    | FloatCol(xs) => {
    total = numel(xs)
    lo = int_max(zero_i64(), start)
    hi = int_min(total, finish)
    if lte(hi, lo) then FloatCol(to_tensor([])) else {
      idx_list = range(lo, hi)
      idx = to_tensor(idx_list)
      FloatCol(gather(xs, idx, cast(0, int32)))
    }
  }
    | StringCol(xs) => {
    total = len(xs)
    lo = int_max(zero_i64(), start)
    hi = int_min(total, finish)
    if lte(hi, lo) then StringCol([]) else {
      idx_list = range(lo, hi)
      StringCol(list_gather_string(xs, idx_list))
    }
  }
    | BoolCol(xs) => {
    total = numel(xs)
    lo = int_max(zero_i64(), start)
    hi = int_min(total, finish)
    if lte(hi, lo) then BoolCol(bool_list_to_tensor([])) else {
      idx_list = range(lo, hi)
      idx = to_tensor(idx_list)
      BoolCol(gather(xs, idx, cast(0, int32)))
    }
  }
  }
def str_char_lt(lch: string, rch: string) -> bool = lt(char_code(lch), char_code(rch))
def str_lt(lhs: string, rhs: string) -> bool = str_lt_pos(lhs, rhs, zero_i64(), string_len(lhs), string_len(rhs))
def str_lt_pos(lhs: string, rhs: string, pos: int64, llen: int64, rlen: int64) -> bool =
  if eq(pos, llen) then neq(llen, rlen) else if eq(pos, rlen) then false else {
    lch = string_slice(lhs, pos, one_i64())
    rch = string_slice(rhs, pos, one_i64())
    if neq(lch, rch) then str_char_lt(lch, rch) else str_lt_pos(lhs, rhs, add(pos, one_i64()), llen, rlen)
  }
def append_all_enum_pairs(lhs: List[(int64, string)], rhs: List[(int64, string)]) -> List[(int64, string)] = if eq(len(rhs), zero_i64()) then lhs else append_all_enum_pairs(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def enum_pair_insert(xs: List[(int64, string)], pair: (int64, string)) -> List[(int64, string)] = if eq(len(xs), zero_i64()) then [pair] else if str_lt(pair.1, index(xs, zero_i64()).1) then append_all_enum_pairs([pair], xs) else append_all_enum_pairs([index(xs, zero_i64())], enum_pair_insert(drop(xs, one_i64()), pair))
def enum_insertion_sort(unsorted: List[(int64, string)], acc: List[(int64, string)]) -> List[(int64, string)] =
  if eq(len(unsorted), zero_i64()) then acc else {
    hd = index(unsorted, zero_i64())
    enum_insertion_sort(drop(unsorted, one_i64()), enum_pair_insert(acc, hd))
  }
def extract_perm_indices(pairs: List[(int64, string)], acc: List[int64]) -> List[int64] =
  if eq(len(pairs), zero_i64()) then acc else {
    hd = index(pairs, zero_i64())
    extract_perm_indices(drop(pairs, one_i64()), append(acc, hd.0))
  }
def sort_by[n](df: Frame[n], name: string, ascending: bool) -> Frame[n] =
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    perm_and_pairs = compute_sort_perm_for(pairs, name, ascending, [])
    perm = perm_and_pairs.0
    rebuilt_pairs = perm_and_pairs.1
    perm_list = to_list(perm)
    reindexed = map(fn (pair: (string, Column[n])) -> (pair.0, reindex_column(pair.1, perm, perm_list)), rebuilt_pairs)
    from_pairs(reorder_column_pairs(reindexed, order, []))
  }
  }
def compute_sort_perm_for[n](pairs: List[(string, Column[n])], name: string, ascending: bool, acc: List[(string, Column[n])]) -> (tensor[n, int64], List[(string, Column[n])]) =
  if eq(len(pairs), zero_i64()) then fail("sort_by: column not found") else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, name) then {
      key_pair = perm_from_key_column(head_pair.1, ascending)
      perm = key_pair.0
      key_col_back = key_pair.1
      next_pairs = append_pair_list(append(acc, (name, key_col_back)), drop(pairs, one_i64()))
      (perm, next_pairs)
    } else compute_sort_perm_for(drop(pairs, one_i64()), name, ascending, append(acc, head_pair))
  }
def perm_from_key_column[n](col: Column[n], ascending: bool) -> (tensor[n, int64], Column[n]) =
  match col with {
    | FloatCol(xs) => {
    xs_list = to_list(xs)
    fresh_tensor = to_tensor(xs_list)
    perm = orient_perm(sort(fresh_tensor, cast(0, int32)).1, ascending)
    (perm, FloatCol(to_tensor(xs_list)))
  }
    | IntCol(xs, mask) => {
    xs_list = to_list(xs)
    mask_list = to_list(mask)
    fresh_tensor = to_tensor(xs_list)
    perm = orient_perm(sort(fresh_tensor, cast(0, int32)).1, ascending)
    (perm, IntCol(to_tensor(xs_list), bool_list_to_tensor(mask_list)))
  }
    | BoolCol(xs) => {
    xs_list = to_list(xs)
    fresh_tensor = to_tensor(map(fn (b: bool) -> if b then one_i64() else zero_i64(), xs_list))
    perm = orient_perm(sort(fresh_tensor, cast(0, int32)).1, ascending)
    (perm, BoolCol(bool_list_to_tensor(xs_list)))
  }
    | StringCol(xs) => {
    sorted_pairs = enum_insertion_sort(enumerate(xs), [])
    perm = to_tensor(extract_perm_indices(sorted_pairs, []))
    (orient_perm(perm, ascending), StringCol(xs))
  }
  }
def extract_perm_strings(pairs: List[(int64, string)], acc: List[string]) -> List[string] =
  if eq(len(pairs), zero_i64()) then acc else {
    hd = index(pairs, zero_i64())
    extract_perm_strings(drop(pairs, one_i64()), append(acc, hd.1))
  }
def with_column[n](df: Frame[n], name: string, col: Column[n]) -> Frame[n] =
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    next_pairs = if contains_string(order, name) then replace_named_column(pairs, name, col, []) else append(pairs, (name, col))
    next_order = if contains_string(order, name) then order else append(order, name)
    Frame { cols: hamt_from_pairs(next_pairs), col_order: next_order }
  }
  }
def replace_named_column[n](pairs: List[(string, Column[n])], name: string, col: Column[n], acc: List[(string, Column[n])]) -> List[(string, Column[n])] =
  if eq(len(pairs), zero_i64()) then acc else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, name) then append_pair_list(append(acc, (name, col)), drop(pairs, one_i64())) else replace_named_column(drop(pairs, one_i64()), name, col, append(acc, head_pair))
  }
def mutate[n](df: Frame[n], name: string, col: Column[n]) -> Frame[n] = with_column(df, name, col)
def rename[n](df: Frame[n], old_name: string, new_name: string) -> Frame[n] =
  if contains_string(columns(df), new_name) then fail("rename: target column already exists") else match df with {
    | Frame { cols, col_order: order } => {
    value = get_column(df, old_name)
    Frame { cols: hamt_put(hamt_remove(cols, old_name), new_name, value), col_order: replace_name(order, old_name, new_name, []) }
  }
  }
def drop_column[n](df: Frame[n], name: string) -> Frame[n] =
  if not(contains_string(columns(df), name)) then fail(string_concat("drop_column: missing column ", name)) else match df with {
    | Frame { cols, col_order: order } => Frame { cols: hamt_remove(cols, name), col_order: list_filter_string(fn (entry: string) -> neq(entry, name), order) }
  }
-- chelis#630: tensor neq's native C lowering is not IEEE-correct for NaN; keep
-- the scalar host-map path until evaluator and compiled backends agree.
def is_nan[n](col: &tensor[n, f32]) -> tensor[n, bool] = to_tensor(map(fn (x: f32) -> neq(x, x), to_list(col)))
def fill_nan[n](col: &tensor[n, f32], value: f32) -> tensor[n, f32] = to_tensor(map(fn (x: f32) -> if neq(x, x) then value else x, to_list(col)))
def drop_nan[n, k](df: Frame[n], col_name: string) -> Frame[k] = {
  col = get_float_col(df, col_name)
  keep = not(is_nan(col))
  filter(df, keep)
}
def any_nan[n](col: &tensor[n, f32]) -> bool = fold(fn (acc: bool, flag: bool) -> or(acc, flag), false, to_list(is_nan(col)))
def count_nan[n](col: &tensor[n, f32]) -> int64 = fold(fn (acc: int64, flag: bool) -> if flag then add(acc, one_i64()) else acc, zero_i64(), to_list(is_nan(col)))
def is_nan_col[n](df: Frame[n], col_name: string) -> tensor[n, bool] =
  match get_column(df, col_name) with {
    | IntCol(ivals, mask) => mask
    | _ => fail(string_concat("is_nan_col: column is not int: ", col_name))
  }
def any_nan_col[n](df: Frame[n], col_name: string) -> bool = fold(fn (acc: bool, v: bool) -> or(acc, v), false, to_list(is_nan_col(df, col_name)))
def count_nan_col[n](df: Frame[n], col_name: string) -> int64 = fold(fn (acc: int64, v: bool) -> if v then add(acc, one_i64()) else acc, zero_i64(), to_list(is_nan_col(df, col_name)))
def fill_nan_col[n](df: Frame[n], col_name: string, fill_val: int64) -> Frame[n] =
  match get_column(df, col_name) with {
    | IntCol(xs, mask) => {
    filled = to_tensor(fill_int_list(to_list(xs), to_list(mask), fill_val, []))
    fm = zeros_bool_n(filled)
    with_column(df, col_name, IntCol(filled, fm))
  }
    | _ => fail(string_concat("fill_nan_col: column is not int: ", col_name))
  }
def fill_int_list(values: List[int64], masks: List[bool], fill_val: int64, acc: List[int64]) -> List[int64] =
  if eq(len(values), zero_i64()) then acc else {
    v = index(values, zero_i64())
    m = index(masks, zero_i64())
    next = if m then fill_val else v
    fill_int_list(drop(values, one_i64()), drop(masks, one_i64()), fill_val, append(acc, next))
  }
def drop_nan_col[n, k](df: Frame[n], col_name: string) -> Frame[k] =
  match get_column(df, col_name) with {
    | IntCol(dnvals, mask) => {
    keep = not(mask)
    filter(df, keep)
  }
    | _ => fail(string_concat("drop_nan_col: column is not int: ", col_name))
  }
def concat[n, k](frames: List[Frame[n]]) -> Frame[k] = concat_with_order_decision(frames)
def concat_with_order_decision[n, k](frames: List[Frame[n]]) -> Frame[k] = {
  base_order_result = first_frame_columns_or_empty(frames)
  base_order = base_order_result.0
  frames_back = base_order_result.1
  if eq(len(base_order), zero_i64()) then Frame { cols: hamt_from_pairs([]), col_order: [] } else from_pairs(map(fn (name: string) -> (name, concat_column(name, frames_back)), base_order))
}
def first_frame_columns_or_empty[n](frames: List[Frame[n]]) -> (List[string], List[Frame[n]]) =
  if eq(len(frames), zero_i64()) then ([], []) else {
    head_frame = index(frames, zero_i64())
    rest = drop(frames, one_i64())
    match head_frame with {
      | Frame { cols, col_order: order } => (order, prepend_frame_to_list(Frame { cols, col_order: order }, rest))
    }
  }
def prepend_frame_to_list[n](first: Frame[n], rest: List[Frame[n]]) -> List[Frame[n]] = prepend_frame_acc(rest, [first])
def prepend_frame_acc[n](src: List[Frame[n]], acc: List[Frame[n]]) -> List[Frame[n]] =
  if eq(len(src), zero_i64()) then acc else {
    hd = index(src, zero_i64())
    prepend_frame_acc(drop(src, one_i64()), append(acc, hd))
  }
def describe[n, m](df: Frame[n]) -> Frame[m] =
  match df with {
    | Frame { cols, col_order: order } => {
    stats = ["count", "mean", "std", "min", "25%", "50%", "75%", "max"]
    pairs = hamt_entries(cols)
    stat_col = ("stat", StringCol(stats))
    value_cols = build_describe_pairs(pairs, order, [])
    from_pairs(prepend_pair_column(stat_col, value_cols))
  }
  }
def build_describe_pairs[n, m](pairs: List[(string, Column[n])], order: List[string], acc: List[(string, Column[m])]) -> List[(string, Column[m])] =
  if eq(len(order), zero_i64()) then drain_pairs_to_acc(pairs, acc) else {
    name = index(order, zero_i64())
    extracted = extract_pair_for_describe(pairs, name, [])
    next_acc = if is_numeric_column(extracted.0) then append(acc, (name, describe_column(extracted.0))) else discard_describe_column(extracted.0, acc)
    build_describe_pairs(extracted.1, drop(order, one_i64()), next_acc)
  }
def drain_pairs_to_acc[n, m](pairs: List[(string, Column[n])], acc: List[(string, Column[m])]) -> List[(string, Column[m])] = if eq(len(pairs), zero_i64()) then acc else drain_pairs_to_acc(drop(pairs, one_i64()), acc)
def extract_pair_for_describe[n](pairs: List[(string, Column[n])], target: string, acc: List[(string, Column[n])]) -> (Column[n], List[(string, Column[n])]) =
  if eq(len(pairs), zero_i64()) then fail("describe: column not found") else {
    head_pair = index(pairs, zero_i64())
    if eq(head_pair.0, target) then (head_pair.1, append_pair_list(acc, drop(pairs, one_i64()))) else extract_pair_for_describe(drop(pairs, one_i64()), target, append(acc, head_pair))
  }
def is_numeric_column[n](col: Column[n]) -> bool =
  match col with {
    | IntCol(_, _) => true
    | FloatCol(_) => true
    | _ => false
  }
def discard_describe_column[n, m](col: Column[n], acc: List[(string, Column[m])]) -> List[(string, Column[m])] =
  match col with {
    | IntCol(_, _) => acc
    | FloatCol(_) => acc
    | StringCol(_) => acc
    | BoolCol(_) => acc
  }
def key_id(value: KeyValue) -> string =
  match value with {
    | KeyIntValue(v) => string_concat("i:", to_string(v))
    | KeyFloatValue(v) => string_concat("f:", to_string(v))
    | KeyStringValue(v) => string_concat("s:", v)
    | KeyBoolValue(v) => string_concat("b:", to_string(v))
  }
def key_values[n](df: Frame[n], name: string) -> List[KeyValue] = column_key_values(get_column(df, name))
def key_values_to_column_like[m, n](keys: List[KeyValue], template: Column[n]) -> Column[m] =
  match template with {
    | IntCol(col, ktmpl) => keys_to_int_col(keys, [], [])
    | FloatCol(col) => FloatCol(to_tensor(map(fn (key: KeyValue) -> match key with {
    | KeyFloatValue(v) => v
    | _ => fail("key type mismatch")
  }, keys)))
    | StringCol(col) => StringCol(map(fn (key: KeyValue) -> match key with {
    | KeyStringValue(v) => v
    | _ => fail("key type mismatch")
  }, keys))
    | BoolCol(col) => fail("bool regrouping is not supported yet")
  }
def keys_to_int_col[m](keys: List[KeyValue], vals_acc: List[int64], mask_acc: List[bool]) -> Column[m] =
  if eq(len(keys), zero_i64()) then IntCol(to_tensor(vals_acc), bool_list_to_tensor(mask_acc)) else {
    key = index(keys, zero_i64())
    pair = match key with {
      | KeyIntValue(v) => (v, false)
      | KeyStringValue(s) => (zero_i64(), true)
      | _ => fail("key type mismatch")
    }
    keys_to_int_col(drop(keys, one_i64()), append(vals_acc, pair.0), append(mask_acc, pair.1))
  }
def empty_column[n](ty: ColumnType) -> Column[n] =
  match ty with {
    | IntType => IntCol(to_tensor([]), bool_list_to_tensor([]))
    | FloatType => FloatCol(to_tensor([]))
    | StringType => StringCol([])
    | BoolType => BoolCol(to_tensor([]))
  }
def column_len[n](col: Column[n]) -> int64 =
  match col with {
    | IntCol(xs, lmask) => numel(xs)
    | FloatCol(xs) => numel(xs)
    | StringCol(xs) => len(xs)
    | BoolCol(xs) => numel(xs)
  }
def empty_column_like[n, k](col: Column[n]) -> Column[k] =
  match col with {
    | IntCol(_, _) => IntCol(to_tensor([]), bool_list_to_tensor([]))
    | FloatCol(_) => FloatCol(to_tensor([]))
    | StringCol(_) => StringCol([])
    | BoolCol(_) => BoolCol(to_tensor([]))
  }
def contains_string(values: List[string], target: string) -> bool = fold(fn (acc: bool, value: string) -> or(acc, eq(value, target)), false, values)
def names_unique(values: List[string]) -> bool = unique_rec(values, [])
def unique_rec(values: List[string], seen: List[string]) -> bool =
  if eq(len(values), zero_i64()) then true else {
    current = index(values, zero_i64())
    if contains_string(seen, current) then false else unique_rec(drop(values, one_i64()), append(seen, current))
  }
def column_lengths_match[n](pairs: List[(string, Column[n])]) -> bool =
  if eq(len(pairs), zero_i64()) then true else {
    first_len = column_len(index(pairs, zero_i64()).1)
    all_eq_len(drop(pairs, one_i64()), first_len)
  }
def all_eq_len[n](pairs: List[(string, Column[n])], expected: int64) -> bool =
  if eq(len(pairs), zero_i64()) then true else {
    entry = index(pairs, zero_i64())
    if neq(column_len(entry.1), expected) then false else all_eq_len(drop(pairs, one_i64()), expected)
  }
def mask_to_index_list(items: List[(int64, bool)], acc: List[int64]) -> List[int64] =
  if eq(len(items), zero_i64()) then acc else {
    entry = index(items, zero_i64())
    next = if entry.1 then append(acc, entry.0) else acc
    mask_to_index_list(drop(items, one_i64()), next)
  }
def reindex_column[n, k](col: Column[n], idx_tensor: tensor[k, int64], idx_list: List[int64]) -> Column[k] =
  match col with {
    | IntCol(xs, mask) => IntCol(gather(xs, idx_tensor, cast(0, int32)), gather(mask, idx_tensor, cast(0, int32)))
    | FloatCol(xs) => FloatCol(gather(xs, idx_tensor, cast(0, int32)))
    | StringCol(xs) => StringCol(list_gather_string(xs, idx_list))
    | BoolCol(xs) => BoolCol(gather(xs, idx_tensor, cast(0, int32)))
  }
def list_gather_string(xs: List[string], idxs: List[int64]) -> List[string] = map(fn (i: int64) -> index(xs, i), idxs)
def reindex_all[n](df: Frame[n], perm: tensor[n, int64]) -> Frame[n] = {
  perm_list = to_list(perm)
  match df with {
    | Frame { cols, col_order: order } => {
    pairs = hamt_entries(cols)
    reindexed = map(fn (pair: (string, Column[n])) -> (pair.0, reindex_column(pair.1, perm, perm_list)), pairs)
    from_pairs(reorder_column_pairs(reindexed, order, []))
  }
  }
}
def orient_perm[n](perm: tensor[n, int64], ascending: bool) -> tensor[n, int64] = if ascending then perm else to_tensor(reverse_ints(to_list(perm), []))
def reverse_ints(values: List[int64], acc: List[int64]) -> List[int64] =
  if eq(len(values), zero_i64()) then acc else {
    hd = index(values, zero_i64())
    append(reverse_ints(drop(values, one_i64()), acc), hd)
  }
def all_same_schema[n](frames: List[Frame[n]], base: Frame[n]) -> bool =
  if eq(len(frames), zero_i64()) then true else {
    current = index(frames, zero_i64())
    if not(schema_eq(base, current)) then false else all_same_schema(drop(frames, one_i64()), base)
  }
def schema_eq[n](lhs: Frame[n], rhs: Frame[n]) -> bool = if not(string_list_eq(columns(lhs), columns(rhs))) then false else schema_eq_names(columns(lhs), lhs, rhs)
def schema_eq_names[n](names: List[string], lhs: Frame[n], rhs: Frame[n]) -> bool =
  if eq(len(names), zero_i64()) then true else {
    name = index(names, zero_i64())
    if not(column_type_eq(column_type(lhs, name), column_type(rhs, name))) then false else schema_eq_names(drop(names, one_i64()), lhs, rhs)
  }
def concat_column[n, k](name: string, frames: List[Frame[n]]) -> Column[k] = {
  sample = get_column(index(frames, zero_i64()), name)
  match sample with {
    | IntCol(col, cmask) => {
    all_vals = concat_int_lists(map(fn (frame: Frame[n]) -> to_list(get_int_col(frame, name)), frames), [])
    all_masks = concat_bool_lists(map(fn (frame: Frame[n]) -> to_list(get_int_mask(frame, name)), frames), [])
    IntCol(to_tensor(all_vals), bool_list_to_tensor(all_masks))
  }
    | FloatCol(col) => FloatCol(to_tensor(concat_float_lists(map(fn (frame: Frame[n]) -> to_list(get_float_col(frame, name)), frames), [])))
    | StringCol(col) => StringCol(concat_strings(map(fn (frame: Frame[n]) -> get_string_col(frame, name), frames), []))
    | BoolCol(col) => {
    int_list = concat_int_lists(map(fn (frame: Frame[n]) -> bools_to_ints(to_list(get_bool_col(frame, name))), frames), [])
    zeros = to_tensor(map(fn (value: int64) -> zero_i64(), int_list))
    ints = to_tensor(int_list)
    __borrow_migration_out_1 = BoolCol(neq(ints, zeros))
    __borrow_migration_out_1
  }
  }
}
def concat_bool_lists(parts: List[List[bool]], acc: List[bool]) -> List[bool] =
  if eq(len(parts), zero_i64()) then acc else {
    hd = index(parts, zero_i64())
    concat_bool_lists(drop(parts, one_i64()), append_all_bools(acc, hd))
  }
def append_all_bools(lhs: List[bool], rhs: List[bool]) -> List[bool] = if eq(len(rhs), zero_i64()) then lhs else append_all_bools(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def concat_strings(parts: List[List[string]], acc: List[string]) -> List[string] =
  if eq(len(parts), zero_i64()) then acc else {
    hd = index(parts, zero_i64())
    concat_strings(drop(parts, one_i64()), append_all_strings(acc, hd))
  }
def is_numeric_type(ty: ColumnType) -> bool =
  match ty with {
    | IntType => true
    | FloatType => true
    | _ => false
  }
def describe_column[m, n](col: Column[n]) -> Column[m] =
  match col with {
    | FloatCol(xs) => FloatCol(to_tensor(float_stats_skip_nan(xs)))
    | IntCol(xs, dmask) => FloatCol(to_tensor(float_stats_skip_nan(ints_masked_to_floats(xs, dmask))))
    | _ => fail("describe: only numeric columns are supported")
  }
def float_stats[n](values: tensor[n, f32]) -> List[f32] = {
  count_i = len(to_list(values))
  count = cast(count_i, f32)
  __borrow_migration_out_16 = [count, mean_vec(values), std_vec(values, one_i64()), min_vec(values), quantile_vec(values, cast(0.25, f32)), quantile_vec(values, cast(0.5, f32)), quantile_vec(values, cast(0.75, f32)), max_vec(values)]
  __borrow_migration_out_16
}
def float_stats_skip_nan[n](values: tensor[n, f32]) -> List[f32] = {
  valid = non_nan_values(to_list(values), [])
  count_i = len(valid)
  if eq(count_i, zero_i64()) then {
    missing = nan_f32()
    [cast(0.0, f32), missing, missing, missing, missing, missing, missing, missing]
  } else {
    valid_tensor = to_tensor(valid)
    count = cast(count_i, f32)
    __borrow_migration_out_17 = [count, mean_vec(valid_tensor), std_vec(valid_tensor, one_i64()), min_vec(valid_tensor), quantile_vec(valid_tensor, cast(0.25, f32)), quantile_vec(valid_tensor, cast(0.5, f32)), quantile_vec(valid_tensor, cast(0.75, f32)), max_vec(valid_tensor)]
    __borrow_migration_out_17
  }
}
def non_nan_values(values: List[f32], acc: List[f32]) -> List[f32] =
  if eq(len(values), zero_i64()) then acc else {
    current = index(values, zero_i64())
    next = if neq(current, current) then acc else append(acc, current)
    non_nan_values(drop(values, one_i64()), next)
  }
def ints_to_floats[n](values: tensor[n, int64]) -> tensor[n, f32] = to_tensor(map(fn (x: int64) -> cast(x, f32), to_list(values)))
def ints_masked_to_floats[n](values: tensor[n, int64], mask: tensor[n, bool]) -> tensor[n, f32] = to_tensor(int_mask_to_float_list(to_list(values), to_list(mask), []))
def int_mask_to_float_list(values: List[int64], masks: List[bool], acc: List[f32]) -> List[f32] =
  if eq(len(values), zero_i64()) then acc else {
    v = index(values, zero_i64())
    m = index(masks, zero_i64())
    fv = if m then nan_f32() else cast(v, f32)
    int_mask_to_float_list(drop(values, one_i64()), drop(masks, one_i64()), append(acc, fv))
  }
def bools_to_ints(values: List[bool]) -> List[int64] = map(fn (flag: bool) -> if flag then one_i64() else zero_i64(), values)
def column_key_values[n](col: Column[n]) -> List[KeyValue] =
  match col with {
    | IntCol(xs, mask) => map2_int_key(to_list(xs), to_list(mask), [])
    | FloatCol(xs) => map(fn (x: f32) -> KeyFloatValue(x), to_list(xs))
    | StringCol(xs) => map(fn (x: string) -> KeyStringValue(x), xs)
    | BoolCol(xs) => map(fn (x: bool) -> KeyBoolValue(x), to_list(xs))
  }
def map2_int_key(values: List[int64], masks: List[bool], acc: List[KeyValue]) -> List[KeyValue] =
  if eq(len(values), zero_i64()) then acc else {
    v = index(values, zero_i64())
    m = index(masks, zero_i64())
    key = if m then KeyStringValue("NULL") else KeyIntValue(v)
    map2_int_key(drop(values, one_i64()), drop(masks, one_i64()), append(acc, key))
  }
def int_min(lhs: int64, rhs: int64) -> int64 = if lt(lhs, rhs) then lhs else rhs
def int_max(lhs: int64, rhs: int64) -> int64 = if gt(lhs, rhs) then lhs else rhs
def prepend_pair_column[n](value: (string, Column[n]), items: List[(string, Column[n])]) -> List[(string, Column[n])] = prepend_pair_column_acc(items, [value])
def list_filter_string(pred: string -> bool, items: List[string]) -> List[string] = list_filter_string_acc(pred, items, [])
def list_filter_string_acc(pred: string -> bool, items: List[string], acc: List[string]) -> List[string] =
  if eq(len(items), zero_i64()) then acc else {
    current = index(items, zero_i64())
    next = if pred(current) then append(acc, current) else acc
    list_filter_string_acc(pred, drop(items, one_i64()), next)
  }
def string_list_eq(lhs: List[string], rhs: List[string]) -> bool = if neq(len(lhs), len(rhs)) then false else string_list_eq_rec(lhs, rhs)
def string_list_eq_rec(lhs: List[string], rhs: List[string]) -> bool = if eq(len(lhs), zero_i64()) then true else if neq(index(lhs, zero_i64()), index(rhs, zero_i64())) then false else string_list_eq_rec(drop(lhs, one_i64()), drop(rhs, one_i64()))
def replace_name(values: List[string], old_name: string, new_name: string, acc: List[string]) -> List[string] =
  if eq(len(values), zero_i64()) then acc else {
    head = index(values, zero_i64())
    next = if eq(head, old_name) then append(acc, new_name) else append(acc, head)
    replace_name(drop(values, one_i64()), old_name, new_name, next)
  }
def column_type_eq(lhs: ColumnType, rhs: ColumnType) -> bool =
  match lhs with {
    | IntType => match rhs with {
    | IntType => true
    | _ => false
  }
    | FloatType => match rhs with {
    | FloatType => true
    | _ => false
  }
    | StringType => match rhs with {
    | StringType => true
    | _ => false
  }
    | BoolType => match rhs with {
    | BoolType => true
    | _ => false
  }
  }
def append_all_strings(lhs: List[string], rhs: List[string]) -> List[string] = if eq(len(rhs), zero_i64()) then lhs else append_all_strings(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def prepend_pair_column_acc[n](items: List[(string, Column[n])], acc: List[(string, Column[n])]) -> List[(string, Column[n])] =
  if eq(len(items), zero_i64()) then acc else {
    hd = index(items, zero_i64())
    prepend_pair_column_acc(drop(items, one_i64()), append(acc, hd))
  }
def concat_int_lists(parts: List[List[int64]], acc: List[int64]) -> List[int64] =
  if eq(len(parts), zero_i64()) then acc else {
    hd = index(parts, zero_i64())
    concat_int_lists(drop(parts, one_i64()), append_all_ints(acc, hd))
  }
def append_all_ints(lhs: List[int64], rhs: List[int64]) -> List[int64] = if eq(len(rhs), zero_i64()) then lhs else append_all_ints(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
def concat_float_lists(parts: List[List[f32]], acc: List[f32]) -> List[f32] =
  if eq(len(parts), zero_i64()) then acc else {
    hd = index(parts, zero_i64())
    concat_float_lists(drop(parts, one_i64()), append_all_floats(acc, hd))
  }
def append_all_floats(lhs: List[f32], rhs: List[f32]) -> List[f32] = if eq(len(rhs), zero_i64()) then lhs else append_all_floats(append(lhs, index(rhs, zero_i64())), drop(rhs, one_i64()))
