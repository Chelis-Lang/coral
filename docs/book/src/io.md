# CSV and JSON

`Coral.Io` reads and writes frames with CSV or JSON files. File
operations use Chelis's `IO` effect, so call them from a function declared
with `! { IO }`, such as a `chelis test` case.

| Format | Read | Write |
|---|---|---|
| CSV | `read_csv_frame(path: string) -> Frame[n]` | `write_csv_frame(df: Frame[n], path: string) -> unit` |
| JSON | `read_json_frame(path: string) -> Frame[n]` | `write_json_frame(df: Frame[n], path: string) -> unit` |

`path` is a file path; a relative path resolves against the working
directory. Writers create or overwrite the file.

## Input format and failures

A CSV file has a header row; its names, in header order, become the
columns. A JSON file is an array of objects. The first object's keys, in
document order, become the columns: a key missing from a later object
reads as an empty cell, and a key that only later objects have is
dropped. A JSON `null`, array, or object value reads as an empty cell.

| Input | Result |
|---|---|
| File not found | Fails: `read_csv failed for PATH` or `load_json failed for PATH` |
| CSV row with fewer or more fields than the header | Fails: `read_csv failed for PATH` |
| JSON that does not parse | Fails: `load_json failed for PATH` |
| JSON whose top level is not an array | Fails: `read_json_frame: expected top-level array` |
| JSON array element that is not an object | Fails: `read_json_frame: expected object entries` |
| Header only, or an empty array | A frame with no columns and no rows; the header names are not kept |

## Column type inference

Each column's type comes from its cell text, tested in this order. The
first rule that matches wins:

1. Every cell is an integer: `IntCol` (`i64`) with no missing entries.
2. At least one cell is an integer and the rest are empty: `IntCol`, with
   the empty cells masked as missing.
3. Every cell is a number: `FloatCol` (`f32`). A column mixing `1` and
   `2.5` is float. `NaN` and `inf` parse as floats.
4. At least one cell is a number and the rest are empty: `FloatCol`, with
   NaN in the empty cells.
5. Every cell is exactly `true` or `false`: `BoolCol`. `True` and `FALSE`
   do not count.
6. Anything else: `StringCol`, with each cell's text unchanged. A column
   whose cells are all empty is a string column.

A cell is an integer when it is an optional `+` or `-` followed by
decimal digits; surrounding spaces are ignored. A number is an integer or
a decimal such as `.5`, `5.`, `1e3`, or `1E3`; `NaN`, `nan`, `-NaN`,
`inf`, and `Infinity` also count. Hexadecimal (`0x10`), digit separators
(`1_000`), and decimal commas (`1,5`) do not, so those cells are strings.

One non-matching cell turns a whole column into strings: a bool column
with one empty cell, or a numeric column with one `n/a`, reads as
`StringCol`.

## Round trip

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

## Writer behavior

Before writing data, check these constraints:

- The CSV writer quotes commas and double quotes in cell values, but does
  not quote headers. Use simple column names. Its line-based reader cannot
  round-trip embedded CR or LF in a field.
- The JSON writer serializes every column name and every cell with
  `Std.Io.Json.to_json`. Quotes, backslashes, and control characters are
  escaped and read back unchanged. Object keys follow the frame's column
  order, which `read_json_frame` keeps. JSON has no `NaN` or `Infinity`
  literal, so the writer writes a non-finite float as `null`, as pandas
  `to_json` does. The output is valid JSON, but `NaN`, `inf`, and `-inf`
  all become `null`.
- When you read the document back, a `null` cell becomes a missing float
  cell if the column has at least one finite value. A column with only
  non-finite cells reads back as a string column, because inference sees
  only empty cells. Float cells are `f32`, so a JSON number outside the
  `f32` range, such as `1e39`, becomes an infinity on input. The writer then
  writes it back as `null`.
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

`chelis build` rejects programs that call `read_csv_frame` or
`read_json_frame`; run readers under `chelis test` or `chelis eval`. See
[limitations](appendix/limitations.md).
