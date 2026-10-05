# CSV and JSON

`Coral.Io` reads and writes frames with CSV or JSON files. Its readers infer
integer (`i64`), float (`f32`), bool, or string columns from the values in
each column. A CSV file uses a header row. A JSON file must contain an array
of objects with scalar values. File operations use Chelis's `IO` effect.

| Format | Read | Write |
|---|---|---|
| CSV | `read_csv_frame(path)` | `write_csv_frame(frame, path)` |
| JSON | `read_json_frame(path)` | `write_json_frame(frame, path)` |

The following test uses simple column names, plain text, finite floats,
and no missing integers. In your Reef project, replace `Coral` in the
module declaration with your project's module prefix. Save the program
as `src/bookio.ch`, then run `chelis test src/bookio.ch`. It writes
`book-io.csv` and `book-io.json` in the working directory and checks
that each file reads back as a four-column frame:

```chelis
module Coral.BookIo
import Std.Test (assert_eq)
import Coral.Frame (FloatCol, StringCol, BoolCol, from_pairs, ncols, int_col_of_list)
import Coral.Io (write_csv_frame, read_csv_frame, write_json_frame, read_json_frame)
def test_files() -> unit ! { Test, IO } = {
  frame = from_pairs([("id", int_col_of_list([1i64, 2i64])), ("price", FloatCol(to_tensor([10.0f32, 20.5f32]))), ("flag", BoolCol(to_tensor([true, false]))), ("city", StringCol(["london", "paris"]))])
  _ = write_csv_frame(frame, "book-io.csv")
  _ = write_json_frame(frame, "book-io.json")
  csv_frame = read_csv_frame("book-io.csv")
  json_frame = read_json_frame("book-io.json")
  _ = assert_eq(ncols(csv_frame), 4i64, "CSV has four columns")
  assert_eq(ncols(json_frame), 4i64, "JSON has four columns")
}
```

The CSV file contains:

```text
id,price,flag,city
1,10.0,true,london
2,20.5,false,paris
```

The JSON file contains:

```json
[{"id":1,"price":10.0,"flag":true,"city":"london"},{"id":2,"price":20.5,"flag":false,"city":"paris"}]
```

The writer boundaries matter when exchanging data:

- The CSV writer quotes commas and double quotes in cell values, but does
  not quote headers. Use simple column names. Its line-based reader cannot
  round-trip embedded CR or LF in a field.
- The JSON writer inserts column names and string values without JSON
  escaping. Avoid quotes, backslashes, and control characters in those
  strings. JSON has no `NaN` or `Infinity` literal, so the writer renders
  a non-finite float as `null`, the same encoding pandas `to_json` uses.
  That keeps a non-finite float inside the grammar, but it does not
  distinguish `NaN` from `inf` or `-inf`. Reading the document back gives
  a missing float cell as long as the column holds at least one finite
  value; a column whose every cell is non-finite reads back as a string
  column, because inference then sees only empty cells. This also applies
  to a number the reader could not represent: float cells are `f32`, so a
  JSON value outside the `f32` range, such as `1e39`, becomes an infinity
  on the way in and is therefore written back as `null`.
- Both writers output the underlying number for an `IntCol` and ignore its
  missing-value mask. A missing integer stored as `0` is written as `0`,
  and reading the file back does not restore the mask.
- CSV and JSON readers infer each column from its cell text. A
  `StringCol` containing only digit strings reads back as an `IntCol`,
  which can discard leading zeroes. An integer outside `i64` may read
  back as `FloatCol` with rounding. Do not rely on these readers to
  preserve digit-only identifiers.

`read_parquet_frame` and `write_parquet_frame` are exported names but fail
when called. Parquet frame I/O is unavailable.
