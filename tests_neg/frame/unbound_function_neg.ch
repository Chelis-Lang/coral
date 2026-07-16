module Coral.Tests_Neg.Frame.Unbound_Function_Neg
import Std.Test (assert_close)
def test_negative_unbound_function() -> unit ! { Test } = {
  _ = coral_function_that_does_not_exist(cast(1.0, f32))
  assert_close(cast(0.0, f32), cast(0.0, f32), cast(0.0, f32), "should not reach here")
}
