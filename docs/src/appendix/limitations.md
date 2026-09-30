# Limitations

These boundaries apply to Coral 0.7.43 with Chelis 0.18.11:

- **Execution.** Dataframe examples run through `chelis eval` and
  `chelis test`. A native `chelis build` program that reads `Frame` columns
  does not lower. GPU execution and differentiation through Coral's
  dataframe operations are not validated. Bare tensor Window operations
  have a narrower generated-C comparison described in
  [Pandas comparison](pandas_comparison.md).
- **Parquet.** `read_parquet_frame` and `write_parquet_frame` are exported
  but fail when called.
- **Concatenation.** Pass frames with the same ordered schema and row
  count. `concat` uses the first frame's columns without checking every
  later schema; extra columns in a later frame are omitted. See
  [Concatenation](../frame/concatenation.md).
- **File output.** CSV and JSON writers do not encode integer
  missing-value masks. The JSON writer does not escape column names or
  string cells and cannot produce valid JSON for non-finite floats. The
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
