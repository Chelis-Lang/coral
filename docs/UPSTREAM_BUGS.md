# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

- `chelis v0.1.18` still requires the `copy(values)` compatibility fix around
  tensor-to-list conversion that Coral already applies in `describe`.
  This remains a relevant compiler-surface change for downstream shells.
- **Fixed in v0.1.18**: the invalid-C type-collapse that previously caused
  `hamt_put`, `slice`, `empty_column`, and `drop_nan` signatures to collapse
  to `int` is gone. The stripped multi-module bare-build (frame / groupby / join)
  now generates valid C, links cleanly, and the resulting binary executes correctly.
- **New in v0.1.18**: `chelis build` panics inside `crates/chelis-ir/src/lower.rs`
  with `` `if` is not representable in the Phase 0e RISC DAG `` during a stripped
  multi-module bare build, but exits **rc=0**. The panic is non-fatal: valid C is
  written and compiled before the panic fires. This silent-panic / incorrect-exit-code
  behaviour should be fixed upstream so callers can reliably detect build failures.
  Reproducer:
  [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py)
