# Limitations

These constraints apply to Coral 0.7.47 with Chelis 0.19.1:

- **Concatenation.** Pass frames with the same ordered schema and row
  count. `concat` uses the first frame's columns without checking every
  later schema; extra columns in a later frame are omitted. See
  [Concatenation](../frame/concatenation.md).
- **File output.** The CSV and JSON writers ignore an integer column's
  missing-value mask, so a masked zero writes as `0` and a read does not
  restore the mask. The CSV writer does not quote column names. The JSON
  writer escapes column names and string cells, and writes `NaN`, `inf`, and
  `-inf` as `null`. A JSON value such as `1e39` reads as an `f32` infinity,
  so it writes back as `null`. The [I/O chapter](../io.md) gives
  supported inputs.
- **Column types.** GroupBy cannot return bool group keys. Bool non-key
  columns cannot pass through joins; inner and left joins also reject
  bool keys. `pivot` and `melt` take float value columns and string
  id/index columns. String and bool columns have no missing marker.
- **Output conventions.** `outer_join` returns its key as a string column,
  whatever the input key type. `from_columns` and `empty` use dictionary
  entry order for columns; use `from_pairs` for explicit order. In a
  multi-aggregation, each value column can appear only once, and an
  `AggCount` spec needs a numeric value column.
- **Wide frames.** Evaluation of a frame with 100 or more columns can need a
  longer test timeout.
