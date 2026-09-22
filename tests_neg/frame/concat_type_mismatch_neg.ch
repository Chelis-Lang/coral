module Coral.Tests_Neg.Frame.Concat_Type_Mismatch_Neg
import Coral.Frame (concat)
import Std.Test (assert_close)
def test_negative_concat_type_mismatch() -> unit ! { Test } = {
  _ = concat(cast(1, i64))
  assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
}
