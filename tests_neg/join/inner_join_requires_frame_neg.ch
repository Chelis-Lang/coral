module Coral.Tests_Neg.Join.Inner_Join_Requires_Frame_Neg
import Coral.Join (inner_join)
import Std.Test (assert_true)
def test_negative_inner_join_requires_frame_neg() -> unit ! { Test } = {
  _ = inner_join(1i64, 1i64, "key")
  assert_true(true, "incompatible argument must reject")
}
