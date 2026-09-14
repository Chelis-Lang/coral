module Coral.Tests.ColumnLength
import Std.Test (assert_eq)
import Coral.Frame (FloatCol, StringCol, BoolCol, column_len, int_col_of_list)
def test_column_length_populated_variants() -> unit ! { Test } = {
  _ = assert_eq(column_len(FloatCol(to_tensor([1.0f32, 2.0f32]))), 2i64, "float length")
  _ = assert_eq(column_len(int_col_of_list([1i64, 2i64])), 2i64, "integer length")
  _ = assert_eq(column_len(StringCol(["a", "b"])), 2i64, "string length")
  assert_eq(column_len(BoolCol(to_tensor([true, false]))), 2i64, "boolean length")
}
def test_column_length_empty_variants() -> unit ! { Test } = {
  _ = assert_eq(column_len(FloatCol(to_tensor([]))), 0i64, "empty float length")
  _ = assert_eq(column_len(int_col_of_list([])), 0i64, "empty integer length")
  _ = assert_eq(column_len(StringCol([])), 0i64, "empty string length")
  assert_eq(column_len(BoolCol(to_tensor([]))), 0i64, "empty boolean length")
}
