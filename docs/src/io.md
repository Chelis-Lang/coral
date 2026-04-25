# IO

`Coral.IO` provides CSV, JSON, and Parquet read/write helpers. Read inference
covers int, float, bool, and string columns.

```chelis
module Coral.BookIO
import Coral.Frame (from_pairs, ncols, int_col_of_list)
import Coral.IO (write_csv_frame, write_json_frame)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("id", int_col_of_list([cast(1, int64), cast(2, int64)])),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)])))),
    ("city", StringCol(["london", "paris"]))
  ])
  csv_unit = write_csv_frame(frame, "book-io.csv")
  json_unit = write_json_frame(frame, "book-io.json")
  ncols(frame)
}
```

## Parquet

`read_parquet_frame` and `write_parquet_frame` are exported by `Coral.IO` but
currently call `fail(...)` at runtime. `Std.IO.Parquet` resolves at import time
In chelis v0.2.4, `import Std.IO.Parquet (read_parquet)` resolves at check time (score 1.0)
but `chelis build --target c` panics at `lower.rs` (exit 101); functions remain uncallable.
The stdlib archive contains no `io/parquet.ch`. Parquet support is gated on upstream
`Chelis-Lang/chelis`. See `docs/UPSTREAM_BUGS.md` for the full probe log.
