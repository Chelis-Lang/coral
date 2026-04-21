# Limitations

- string `sort_by` is deferred
- Parquet I/O is deferred
- `outer_join` is deferred
- bool-heavy regrouping and join-output paths are still narrower than the numeric and string paths
- `from_columns` / `empty` column order should not be treated as parity-stable until
  Coral stops depending on raw `Dict` entry order for those constructors
- `chelis v0.1.13` still hangs in the reef-import runtime path for a HAMT-backed
  Coral probe, so compile-level probes remain part of the honest gate
