# CSV And JSON

`Coral.IO` currently provides CSV and JSON read/write helpers for the first
compile-checked slice. Read inference now covers int, float, bool, and string
columns. Write formatting covers those same types for Coral-generated CSV and
JSON output.

```chelis
module Coral.BookIO
import Coral.Frame (from_pairs, ncols)
import Coral.IO (write_csv_frame, write_json_frame)
export (main)

def main() -> int64 = {
  frame = from_pairs([
    ("id", IntCol(to_tensor([cast(1, int64), cast(2, int64)]))),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)])))),
    ("city", StringCol(["london", "paris"]))
  ])
  csv_unit = write_csv_frame(frame, "book-io.csv")
  json_unit = write_json_frame(frame, "book-io.json")
  ncols(frame)
}
```

Current proof level:

- checked-in fixtures for CSV/JSON expectations
- compile-checked import/use coverage in the main harness
- no executed runtime parity lane yet

This split is intentional and documented: Window is the only module family with
executed runtime parity in the current repo state.
