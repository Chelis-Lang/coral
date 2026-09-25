# IO

`Coral.Io` provides CSV and JSON read/write helpers. Read inference covers
int, float, bool, and string columns.

```chelis
module Coral.BookIo
import Coral.Frame (FloatCol, StringCol, BoolCol, from_pairs, ncols, int_col_of_list)
import Coral.Io (write_csv_frame, write_json_frame)
export (main)
def main() -> i64 = {
  frame = from_pairs([("id", int_col_of_list([cast(1, i64), cast(2, i64)])), ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))), ("flag", BoolCol(neq(to_tensor([cast(1, i64), cast(0, i64)]), to_tensor([cast(0, i64), cast(0, i64)])))), ("city", StringCol(["london", "paris"]))])
  csv_unit = write_csv_frame(frame, "book-io.csv")
  json_unit = write_json_frame(frame, "book-io.json")
  ncols(frame)
}
```

## Parquet

`read_parquet_frame` and `write_parquet_frame` are exported by `Coral.Io` but
call `fail(...)` at runtime. The Chelis standard library's `Std.Io.Parquet`
declares its functions but has no runtime implementation yet
([chelis#850](https://github.com/Chelis-Lang/chelis/issues/850)).
