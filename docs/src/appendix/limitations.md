# Limitations

- **Parquet.** `read_parquet_frame` and `write_parquet_frame` fail at runtime
  until the Chelis standard library implements `Std.Io.Parquet`
  ([chelis#850](https://github.com/Chelis-Lang/chelis/issues/850)).
- **Bool columns.** Bool columns cannot be group keys, and a join fails if
  either input frame has a bool column.
- **Multi-aggregation.** `agg` takes each value column at most once
  ([coral#37](https://github.com/Chelis-Lang/coral/issues/37)), and an
  `AggCount` spec needs a float or int column
  ([coral#38](https://github.com/Chelis-Lang/coral/issues/38)).
- **`outer_join` keys** come back as strings whatever the key type.
- **Reshape.** `pivot` and `melt` take float value columns and string
  id/index columns only.
- **Column order from `from_columns` and `empty`** follows the dictionary's
  entry order; use `from_pairs` when column order matters.
- **Native builds.** Coral runs as a Reef package and in the evaluator.
  Compiling a program that reads `Frame` columns with `chelis build` does not
  lower yet ([chelis#1226](https://github.com/Chelis-Lang/chelis/issues/1226)).
- **Wide frames.** Frames with 100 or more columns are slow in the evaluator
  ([chelis#828](https://github.com/Chelis-Lang/chelis/issues/828)).
- **Gradients and GPU.** Coral makes no claim that `grad` differentiates
  through its operations, and no operation is validated on a GPU backend.

The repository's `spec/scope.md` lists every deliberate deferral, and
`docs/UPSTREAM_BUGS.md` tracks every compiler issue that affects Coral.
