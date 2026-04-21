# Coral Status

Current work focuses on the first pass of:

- persistent HAMT-backed frame column storage
- typed frame representation
- filtering and schema mutation
- host-path string grouping and joining
- rolling window helpers
- CSV/JSON I/O

Hard constraint recorded for alpha:

- `Frame.columns` uses a persistent HAMT from day one
- no plain `Dict` fallback for frame column storage
- reason: AD through multi-op frame pipelines must preserve structural sharing instead of copying the full column map on every frame mutation
- implementation order: land `Coral.Internal.HAMT` with isolated tests first, then wire `Coral.Frame` onto it

Known deferred items:

- string sorting
- Parquet
- outer join
- richer reshape support
