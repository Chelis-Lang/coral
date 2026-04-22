# Limitations

- string `sort_by` is deferred
- Parquet I/O is deferred
- `outer_join` is deferred
- bool-heavy regrouping and join-output paths are still narrower than the numeric and string paths
- `from_columns` / `empty` column order should not be treated as parity-stable until
  Coral stops depending on raw `Dict` entry order for those constructors
- `chelis v0.1.18` fixes the invalid-C type-collapse that previously blocked
  stripped Frame/GroupBy/Join bare builds, but `chelis build` still panics in the
  Phase 0e RISC DAG (non-fatal, rc=0); see `docs/UPSTREAM_BUGS.md`
