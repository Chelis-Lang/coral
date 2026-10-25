# Limitations

Coral has the following constraints:

- **Native builds.** `drop_column` rejects under `chelis build`; run code
  that needs it with `chelis eval` or `chelis test`. Native `describe`
  examples cover float and integer columns. Multi-aggregation examples cover
  string and integer group keys; join examples cover string keys with partial
  and complete matches. CSV and JSON reader examples cover two- and three-row
  frames with string and float columns. These examples do not establish native
  support for every combination of column types and shapes.
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
- **Large files.** Reading or writing large, wide frames can take substantial
  time.
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
