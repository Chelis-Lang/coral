# Limitations

- Parquet I/O is deferred
- bool-heavy regrouping and join-output paths are still narrower than the numeric and string paths
- `from_columns` / `empty` column order should not be treated as parity-stable until
  Coral stops depending on raw `Dict` entry order for those constructors
- the invalid-C type-collapse and Phase 0e RISC DAG panic that previously blocked
  stripped Frame/GroupBy/Join bare builds are both fixed as of `chelis v0.1.19`;
  build, link, and run are fully clean
