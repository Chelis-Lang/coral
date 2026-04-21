# Limitations

- string `sort_by` is deferred
- Parquet I/O is deferred
- `outer_join` is deferred
- bool-heavy regrouping and join-output paths are still narrower than the numeric and string paths
