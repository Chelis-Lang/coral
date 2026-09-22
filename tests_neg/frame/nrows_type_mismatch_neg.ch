module Coral.Tests_Neg.Frame.Nrows_Type_Mismatch_Neg
import Coral.Frame (nrows)
import Std.Test (assert_close)
def test_negative_nrows_type_mismatch() -> unit ! { Test } = {
  _ = nrows(cast(1, i64))
  assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
}
