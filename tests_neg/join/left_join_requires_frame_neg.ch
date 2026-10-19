module Coral.Tests_Neg.Join.Left_Join_Requires_Frame_Neg
import Coral.Join (left_join)
import Std.Test (assert_true)
def test_negative_left_join_requires_frame_neg() -> unit ! { Test } = {
  _ = left_join(1i64, 1i64, "key")
  assert_true(true, "incompatible argument must reject")
}
