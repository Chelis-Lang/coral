module Coral.Tests_Neg.Window.Extent_Mismatch_Neg
import Coral.Window (rolling_mean)
import Std.Test (assert_close)
def require_extent_3(col: tensor[3, f32]) -> tensor[3, f32] = col
def test_negative_window_extent_mismatch() -> unit ! { Test } = {
  input = to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32), cast(4.0, f32)])
  _ = require_extent_3(rolling_mean(input, cast(2, i64)))
  assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
}
