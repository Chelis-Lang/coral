# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

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
