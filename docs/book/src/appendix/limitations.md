# Limitations

These constraints apply to Coral 0.7.47 with Chelis 0.19.1:

- **Native builds.** `chelis eval` and `chelis test` run the whole API.
  `chelis build` rejects a program that calls any of these functions:
  `describe`, `drop_column`, `agg`, `inner_join`, `left_join`,
  `outer_join`, `read_csv_frame`, and `read_json_frame`. These build
  natively and return the same values as under `chelis eval`: the rest of
  `Coral.Frame` (construction, accessors, `filter`, `head`, `tail`,
  `slice`, `sort_by`, `with_column`, `mutate`, `rename`, the
  missing-value helpers, and `concat`), `group_by` with `agg_sum`,
  `agg_mean`, `agg_min`, `agg_max`, `agg_count`, and `value_counts`, and
  all of `Coral.Window`, `Coral.Reshape`, and `Coral.AsOf`. The CSV and
  JSON writers also build. In a native program, replace `agg` with one
  single-aggregation call per column and combine the results with
  `with_column`. Run code that needs the other rejected functions with
  `chelis eval` or `chelis test`.
- **Concatenation.** Pass frames with the same column names, types, and
  row count. `concat` matches columns by name using the first frame's
  columns: an extra column in a later frame is omitted without an error,
  while a missing column or a different type fails. See
  [Concatenation](../frame/concatenation.md).
- **File output.** The CSV and JSON writers ignore an integer column's
  missing-value mask, so a masked zero writes as `0` and a read does not
  restore the mask. The CSV writer does not quote column names. The JSON
  writer escapes column names and string cells, and writes `NaN`, `inf`, and
  `-inf` as `null`. A JSON value such as `1e39` reads as an `f32` infinity,
  so it writes back as `null`. The [I/O chapter](../io.md) gives
  supported inputs.
- **JSON document size.** `read_json_frame` reads documents of roughly 950
  rows or fewer. A longer document, or one holding a single string cell longer
  than about 2,400 characters, stops the interpreter by exhausting its stack
  instead of returning an error, and a document of a few hundred kilobytes can
  exceed a test's time limit first. The bound belongs to the JSON parser Coral
  calls, not to Coral, and it is a property of the document as written rather
  than of the frame. `read_csv_frame`, `write_csv_frame`, and
  `write_json_frame` have no comparable bound: each handles 20,000 rows. Read
  large tabular data as CSV.
- **Column types.** GroupBy cannot return bool group keys. Bool non-key
  columns cannot pass through joins; inner and left joins also reject
  bool keys. `pivot` and `melt` take float value columns and string
  id/index columns, so `stack` needs every column to be float. String and
  bool columns have no missing marker.
- **Missing values.** Float NaNs are not skipped by GroupBy aggregations
  or by the rolling functions; masked integers are skipped by GroupBy.
  Missing keys group together and match each other in joins. See
  [Missing values](../frame/nan-handling.md).
- **Unchecked inputs.** Coral does not check that `Coral.AsOf` right-hand
  keys are sorted, that an `ewm` `alpha` lies in `(0, 1]`, or that a
  `with_column` column has the frame's row count. A wrong input gives a
  wrong result, not an error. The file writers are the exception:
  `write_csv_frame` and `write_json_frame` refuse a frame whose columns have
  different lengths instead of writing a file truncated to the shortest one.
- **Output conventions.** `outer_join` returns its key as a string column,
  whatever the input key type. `from_columns` and `empty` use dictionary
  entry order for columns; use `from_pairs` for explicit order. In a
  multi-aggregation, each value column can appear only once, and an
  `AggCount` spec needs a numeric value column. String sorting uses
  Coral's own character ranking; see
  [Filtering](../frame/filtering.md).
