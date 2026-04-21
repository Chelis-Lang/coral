# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

- `chelis v0.1.13` front-end bug: a bare zero-arg call used as a standalone
  statement inside a block can trigger an `ArityMismatch` during `chelis check`.
  Coral currently avoids this shape in [`src/apismoke.ch`](/home/jeff/Documents/scratch/coral/src/apismoke.ch)
  by binding `version()` to `_` instead of leaving it as a bare statement.
- `chelis v0.1.13` currently hangs in `chelis build` on a small reef-importing
  Coral probe that exercises HAMT-backed frame operations. `chelis check` passes
  for the same probe, so Coral keeps a compile-level Phase 1 gate and treats
  runtime proof for that path as blocked on the compiler/backend.
- `chelis v0.1.13` currently emits invalid C for a stripped multi-module bare-build
  Coral program that combines `Coral.Frame` with `Coral.GroupBy` / `Coral.Join`
  helpers. The generated signatures collapse polymorphic values to `int` in several
  paths (`hamt_put`, frame slice helpers, groupby merge paths), so the C compile/link
  step fails before execution. Window-only bare builds remain viable, which is why
  `Coral.Window` has an executed runtime parity lane while GroupBy/Join are still
  fixture-locked plus compile-checked. Reproducer:
  [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py)
