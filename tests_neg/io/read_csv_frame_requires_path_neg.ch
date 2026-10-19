module Coral.Tests_Neg.Io.Read_Csv_Frame_Requires_Path_Neg
import Coral.Io (read_csv_frame)
import Std.Test (assert_true)
def test_negative_read_csv_frame_requires_path_neg() -> unit ! { Test } = {
  _ = read_csv_frame(1i64)
  assert_true(true, "incompatible argument must reject")
}
