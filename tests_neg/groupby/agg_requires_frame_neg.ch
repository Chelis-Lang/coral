module Coral.Tests_Neg.GroupBy.Agg_Requires_Frame_Neg
import Coral.GroupBy (agg)
import Std.Test (assert_true)
def test_negative_agg_requires_frame_neg() -> unit ! { Test } = {
  _ = agg(1i64, [])
  assert_true(true, "incompatible argument must reject")
}
