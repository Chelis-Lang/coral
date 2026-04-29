module Coral.Tests.Reshape
import Std.Test (assert_eq_int, assert_close)
import Coral.Frame (Column, Frame, from_pairs, nrows, ncols, get_float_col, get_string_col)
import Coral.Reshape (pivot, melt, stack, unstack)

-- NOTE: chelis v0.4.0 unblocks tensor-tensor eq/neq in `chelis test`. The
-- FloatCol-based assertions below remain valid; they cover melt/pivot/stack/
-- unstack independently of the eval gap. Coral.Reshape.melt and pivot only
-- accept FloatCol value columns (per src/reshape.ch); id/index/columns args
-- must be StringCol. Hand-computed expected values are derived directly from
-- the inputs, not from any pandas golden.

def zero_i64() -> int64 = cast(0, int64)

def tensor_sum_f32[n](t: tensor[n, f32]) -> f32 = {
  fold(fn (acc: f32, v: f32) -> add(acc, v), cast(0.0, f32), to_list(t))
}

def tensor_sum_skip_nan[n](t: tensor[n, f32]) -> f32 = {
  fold(fn (acc: f32, v: f32) -> if neq(v, v) then acc else add(acc, v), cast(0.0, f32), to_list(t))
}

def test_melt_doubles_rows() -> unit ! { Test } = {
  -- 3 rows, 2 value columns (qty, price) -> melt produces 3 * 2 = 6 rows.
  -- Resulting frame has id_col + variable + value = 3 columns.
  -- Sum of value column = sum(qty) + sum(price) = (1+2+3) + (10+20+30) = 6 + 60 = 66.
  df = from_pairs([
    ("city", StringCol(["a", "b", "c"])),
    ("qty", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))
  ])
  result = melt(df, ["city"], ["qty", "price"])
  value_total = tensor_sum_f32(get_float_col(result, "value"))
  _ = assert_eq_int(nrows(result), cast(6, int64), "melt: 3 rows * 2 value cols == 6");
  _ = assert_eq_int(ncols(result), cast(3, int64), "melt: city + variable + value == 3 cols");
  assert_close(value_total, cast(66.0, f32), cast(1e-3, f32), "melt preserves sum of values")
}

def test_pivot_basic_shape() -> unit ! { Test } = {
  -- city: a, a, b ; product: x, y, x ; price: 1, 2, 3.
  -- Pivot on city -> 2 unique cities (a, b). Columns: city + every distinct product
  -- (x, y) = 3 columns total. (b, y) is missing -> NaN-filled.
  -- Sum of x column (skip NaN) = 1 + 3 = 4. Sum of y column (skip NaN) = 2.
  df = from_pairs([
    ("city", StringCol(["a", "a", "b"])),
    ("product", StringCol(["x", "y", "x"])),
    ("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))
  ])
  result = pivot(df, "city", "product", "price")
  x_sum = tensor_sum_skip_nan(get_float_col(result, "x"))
  y_sum = tensor_sum_skip_nan(get_float_col(result, "y"))
  _ = assert_eq_int(nrows(result), cast(2, int64), "pivot: 2 distinct cities");
  _ = assert_eq_int(ncols(result), cast(3, int64), "pivot: city + product 'x' + product 'y'");
  _ = assert_close(x_sum, cast(4.0, f32), cast(1e-5, f32), "x column sum: 1 + 3 == 4");
  assert_close(y_sum, cast(2.0, f32), cast(1e-5, f32), "y column sum: just 2")
}

def test_pivot_then_melt_roundtrips_shape() -> unit ! { Test } = {
  -- Build a frame fully covered by (city x product), so pivot has no NaN holes.
  -- city: a, a, b, b ; product: x, y, x, y ; price: 1, 2, 3, 4.
  -- Total of price across all 4 rows = 10.
  -- pivot -> 2 rows x (city + x + y) = 2 rows, 3 cols.
  -- melt those two value cols back -> 2 * 2 = 4 rows; sum of values still 10.
  df = from_pairs([
    ("city", StringCol(["a", "a", "b", "b"])),
    ("product", StringCol(["x", "y", "x", "y"])),
    ("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])))
  ])
  pivoted = pivot(df, "city", "product", "price")
  remelted = melt(pivoted, ["city"], ["x", "y"])
  total = tensor_sum_f32(get_float_col(remelted, "value"))
  _ = assert_eq_int(nrows(pivoted), cast(2, int64), "pivot -> 2 rows");
  _ = assert_eq_int(ncols(pivoted), cast(3, int64), "pivot -> city + x + y");
  _ = assert_eq_int(nrows(remelted), cast(4, int64), "remelt -> 2 cities * 2 products");
  assert_close(total, cast(10.0, f32), cast(1e-5, f32), "pivot+melt preserves total = 10")
}

def test_stack_increases_rows() -> unit ! { Test } = {
  -- Two-column FloatCol frame, 3 rows -> stack should produce 3 * 2 = 6 rows.
  -- Sum of value column = sum(a) + sum(b) = (1+2+3) + (4+5+6) = 6 + 15 = 21.
  df = from_pairs([
    ("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)]))),
    ("b", FloatCol(to_tensor([cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])))
  ])
  result = stack(df)
  value_total = tensor_sum_f32(get_float_col(result, "value"))
  _ = assert_eq_int(nrows(result), cast(6, int64), "stack: 3 rows * 2 cols == 6");
  assert_close(value_total, cast(21.0, f32), cast(1e-5, f32), "stack preserves total = 21")
}

def test_unstack_recovers_shape() -> unit ! { Test } = {
  -- Build a frame where stack -> unstack(..., index_col) recovers the row count.
  -- Coral.Reshape.unstack signature is unstack(df, index_col), and stack drops
  -- id_cols, so we need a frame whose post-stack rows still carry the id needed
  -- by unstack via the 'variable' column. Simpler: build a long-format frame
  -- directly and verify unstack pivots it correctly.
  -- city: a, a, b, b ; variable: x, y, x, y ; value: 1, 2, 3, 4.
  -- unstack on city -> 2 rows (a, b), 3 cols (city + x + y). Sum stays 10.
  long_df = from_pairs([
    ("city", StringCol(["a", "a", "b", "b"])),
    ("variable", StringCol(["x", "y", "x", "y"])),
    ("value", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])))
  ])
  result = unstack(long_df, "city")
  x_sum = tensor_sum_skip_nan(get_float_col(result, "x"))
  y_sum = tensor_sum_skip_nan(get_float_col(result, "y"))
  _ = assert_eq_int(nrows(result), cast(2, int64), "unstack: 2 distinct cities");
  _ = assert_eq_int(ncols(result), cast(3, int64), "unstack: city + x + y");
  _ = assert_close(x_sum, cast(4.0, f32), cast(1e-5, f32), "x column sum: 1 + 3 == 4");
  assert_close(y_sum, cast(6.0, f32), cast(1e-5, f32), "y column sum: 2 + 4 == 6")
}
