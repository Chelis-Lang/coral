# Limitations

These boundaries apply to the Coral package and compiler versions in
[`reef.toml`](../../../reef.toml):

- **Execution.** Dataframe examples run through `chelis eval` and
  `chelis test`. Native construction, `nrows`, and a direct match on a
  retrieved column build, link, run, and agree with the evaluator.
  Native package probes also cover `drop_nan`, `filter`, `head`, `slice`,
  `sort_by`, and `with_column`. `describe` and `drop_column` reject under
  native build; full native Frame support is not claimed.
  GPU execution and differentiation through
  Coral's dataframe operations are not validated. Bare tensor Window
  operations have a narrower generated-C comparison described in
  [Pandas comparison](pandas_comparison.md).
- **Parquet.** `read_parquet_frame` and `write_parquet_frame` are exported
  but fail when called.
- **Concatenation.** Pass frames with the same ordered schema and row
  count. `concat` uses the first frame's columns without checking every
  later schema; extra columns in a later frame are omitted. See
  [Concatenation](../frame/concatenation.md).
- **File output.** CSV and JSON writers do not encode integer
  missing-value masks. The JSON writer does not escape column names or
  string cells. It writes a non-finite float as `null`, so `NaN`, `inf`
  and `-inf` are not distinguishable in the output; they read back as
  missing floats unless every cell in the column is non-finite, in which
  case the column reads back as a string column. Because float cells are
  `f32`, a JSON number outside the `f32` range becomes an infinity when
  read and is written back as `null`. The
  [I/O chapter](../io.md) gives supported inputs.
- **Column types.** Bool columns cannot be group keys. Bool non-key
  columns cannot pass through joins; inner and left joins also reject
  bool keys. `pivot` and `melt` take float value columns and string
  id/index columns. String and bool columns have no missing marker.
- **Output conventions.** `outer_join` returns its key as a string column,
  whatever the input key type. `from_columns` and `empty` use dictionary
  entry order for columns; use `from_pairs` for explicit order. In a
  multi-aggregation, each value column can appear only once, and an
  `AggCount` spec needs a numeric value column.
- **Wide frames.** Frames with 100 or more columns can be slow in the
  evaluator.

The public API is treated as alpha. [Coral's scope](https://github.com/Chelis-Lang/coral/blob/main/spec/scope.md)
records the longer-term boundaries.
