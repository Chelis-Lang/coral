module Coral.TestsBlocked.Io.ReadJsonFrameRowDepth
import Std.Test (assert_eq)
import Std.Text (join)
import Std.Io (write_text)
import Coral.Frame (Frame, nrows)
import Coral.Io (read_json_frame)
def zero_i64() -> i64 = cast(0, i64)
def row_count_probe() -> i64 = cast(2000, i64)
def document() -> string = {
  rows = map(fn (i: i64) -> string_concat("{\"a\":", string_concat(to_string(i), "}")), range(zero_i64(), row_count_probe()))
  string_concat("[", string_concat(join(rows, ","), "]"))
}
def test_read_json_frame_survives_two_thousand_rows() -> unit ! { Test, IO } = {
  _ = write_text("test_io_blocked_rows.json", document())
  back = read_json_frame("test_io_blocked_rows.json")
  assert_eq(nrows(back), row_count_probe(), "read_json_frame reads a 2000-row document")
}
