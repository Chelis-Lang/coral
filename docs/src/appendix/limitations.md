# Limitations

These boundaries apply to the Coral package and compiler versions in
[`reef.toml`](../../../reef.toml):

- **Execution.** Dataframe examples use `chelis eval` and `chelis test`.
  Generated-C package probes cover construction, `nrows`, column matching,
  `drop_nan`, `filter`, `head`, `slice`, `sort_by`, and `with_column`; they do
  not establish generated-C support for the full Frame API. Native
  `describe` and `drop_column` have open compiler issues
  ([chelis#3169](https://github.com/Chelis-Lang/chelis/issues/3169),
  [chelis#879](https://github.com/Chelis-Lang/chelis/issues/879)). GPU
  execution and differentiation through Coral's dataframe operations are
  not validated. Bare tensor Window operations have a narrower generated-C
  comparison described in
  [Pandas comparison](pandas_comparison.md).
- **Parquet.** `read_parquet_frame` and `write_parquet_frame` are exported
  but fail when called.
- **Concatenation.** Pass frames with the same ordered schema and row
  count. `concat` uses the first frame's columns without checking every
  later schema; extra columns in a later frame are omitted. See
  [Concatenation](../frame/concatenation.md).
- **File output.** CSV and JSON writers emit an integer column's stored
  numbers without its missing-value mask. A masked zero writes as `0`, and
  reading it back does not restore the mask. CSV column names are joined
  without quoting. The JSON writer escapes column names and string cells
  through `Std.Io.Json.to_json`, so quotes, backslashes and control
  characters round-trip unchanged, and object keys follow the frame's column
  order. It writes
  `NaN`, `inf`, and `-inf` as `null`, losing the distinction. Reading those
  cells back produces missing `f32` values when a column also has finite
  numbers; an all-null column instead becomes a string column of empty cells.
  JSON numeric text is converted to `f32` on ingestion, so `1e39` becomes
  infinity and writes back as `null`
  ([coral#40](https://github.com/Chelis-Lang/coral/issues/40)). The
  [I/O chapter](../io.md) gives supported inputs.
- **Column types.** GroupBy cannot return bool group keys. Bool non-key
  columns cannot pass through joins; inner and left joins also reject
  bool keys. `pivot` and `melt` take float value columns and string
  id/index columns. String and bool columns have no missing marker.
- **Output conventions.** `outer_join` returns its key as a string column,
  whatever the input key type. `from_columns` and `empty` use dictionary
  entry order for columns; use `from_pairs` for explicit order. In a
  multi-aggregation, each value column can appear only once
  ([coral#37](https://github.com/Chelis-Lang/coral/issues/37)), and an
  `AggCount` spec needs a numeric value column
  ([coral#38](https://github.com/Chelis-Lang/coral/issues/38)).
- **Wide frames.** Evaluating a frame with 100 or more columns may require a
  longer test timeout ([coral#16](https://github.com/Chelis-Lang/coral/issues/16)).

The public API is treated as alpha. [Coral's scope](https://github.com/Chelis-Lang/coral/blob/main/spec/scope.md)
records the longer-term boundaries.
