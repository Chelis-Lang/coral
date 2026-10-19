module Coral.Tests_Neg.Frame.Describe_Requires_Frame_Neg
import Coral.Frame (describe)
import Std.Test (assert_true)
def test_negative_describe_requires_frame_neg() -> unit ! { Test } = {
  _ = describe(1i64)
  assert_true(true, "incompatible argument must reject")
}
