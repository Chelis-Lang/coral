module Coral.Tests_Neg.Io.Csv_Ragged_Frame_Neg
import Coral.Frame (StringCol, from_pairs, with_column, int_col_of_list)
import Coral.Io (write_csv_frame)
import Std.Test (assert_true)
def test_negative_csv_ragged_frame() -> unit ! { Test, IO } = {
  base = from_pairs([("a", int_col_of_list([cast(1, i64), cast(2, i64), cast(3, i64)]))])
  _ = write_csv_frame(with_column(base, "short", StringCol(["p", "q"])), "test_io_ragged.csv")
  assert_true(false, "should not reach here")
}
