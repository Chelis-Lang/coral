module Coral.Tests_Neg.Io.Read_Json_Frame_Requires_Path_Neg
import Coral.Io (read_json_frame)
import Std.Test (assert_true)
def test_negative_read_json_frame_requires_path_neg() -> unit ! { Test } = {
  _ = read_json_frame(1i64)
  assert_true(true, "incompatible argument must reject")
}
