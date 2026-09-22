# IO

`Coral.Io` provides CSV, JSON, and Parquet read/write helpers. Read inference
covers int, float, bool, and string columns.

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
currently call `fail(...)` at runtime. Parquet support remains gated on upstream
`Chelis-Lang/chelis` shipping the runtime backing for `Std.Io.Parquet`; the
v0.7.6 probe still resolves the import at check time but does not provide a
usable runtime path. See `docs/UPSTREAM_BUGS.md` for the full probe log.
