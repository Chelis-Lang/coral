module Coral.Tests_Neg.Join.Outer_Join_Requires_Frame_Neg
import Coral.Join (outer_join)
import Std.Test (assert_true)
def test_negative_outer_join_requires_frame_neg() -> unit ! { Test } = {
  _ = outer_join(1i64, 1i64, "key")
  assert_true(true, "incompatible argument must reject")
}
