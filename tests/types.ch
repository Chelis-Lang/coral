module Coral.Tests.Types
import Std.Test (assert_true, assert_false)
def borrowed_neq[n](lhs: &tensor[n, f32], rhs: &tensor[n, f32]) -> tensor[n, bool] = neq(lhs, rhs)
def test_borrowed_float_tensor_neq_infers_bool() -> unit ! { Test } = {
  lhs = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])
  rhs = to_tensor([cast(1.0, f32), cast(9.0, f32), cast(3.0, f32)])
  mask = to_list(borrowed_neq(lhs, rhs))
  _ = assert_false(index(mask, cast(0, int64)), "borrowed/borrowed neq: equal lane is false")
  _ = assert_true(index(mask, cast(1, int64)), "borrowed/borrowed neq: differing lane is true")
  assert_false(index(mask, cast(2, int64)), "borrowed/borrowed neq: second equal lane is false")
}
