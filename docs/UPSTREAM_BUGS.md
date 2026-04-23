# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

- **Upstream blocker (v0.1.21): `Std.IO.Parquet` module is a placeholder** — the module
  resolves at import-check time (score 1.0 on empty import list) but exports no callable
  functions. Probing `read_parquet`, `read_parquet_rows`, `read_parquet_file`, and
  `write_parquet` all return `UnboundVariable`. The stdlib archive (`chelis-std-0.1.0`)
  contains `io/csv.ch`, `io/json.ch`, and `io/safetensors.ch` but no `io/parquet.ch`.
  `read_parquet_frame` / `write_parquet_frame` remain `fail(...)` stubs in `src/io.ch`
  until parquet lands upstream. Track the `Chelis-Lang/chelis` release notes for when
  `Std.IO.Parquet` becomes functional.

- `chelis v0.1.18` still requires the `copy(values)` compatibility fix around
  tensor-to-list conversion that Coral already applies in `describe`.
  This remains a relevant compiler-surface change for downstream shells.
- **Fixed in v0.1.18**: the invalid-C type-collapse that previously caused
  `hamt_put`, `slice`, `empty_column`, and `drop_nan` signatures to collapse
  to `int` is gone. The stripped multi-module bare-build (frame / groupby / join)
  now generates valid C, links cleanly, and the resulting binary executes correctly.
- **Fixed in v0.1.19**: the Phase 0e RISC DAG panic for `if` (introduced as a
  non-fatal silent panic with rc=0 in v0.1.18) is resolved. As of v0.1.19,
  `chelis build` on stripped Frame/GroupBy/Join programs is fully clean: no panic,
  valid C, successful link, and correct binary execution.
  [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py)
  now verifies clean end-to-end operation and exits 0 on success.
