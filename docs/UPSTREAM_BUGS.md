# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

- `chelis v0.1.15` tightens ownership around tensor-to-list conversion enough that
  Coral's `describe` path needed explicit `copy(values)` before `to_list(values)`.
  That compatibility fix is now applied in [`src/frame.ch`](/home/jeff/Documents/scratch/coral/src/frame.ch),
  but it is still a relevant compiler-surface change for downstream shells.
- `chelis v0.1.15` currently emits invalid C for a stripped multi-module bare-build
  Coral program that combines `Coral.Internal.HAMT` with `Coral.Frame`
  (and optionally `Coral.GroupBy` / `Coral.Join`). The generated signatures
  collapse polymorphic values to `int` in several Frame/HAMT paths
  (`hamt_put`, `slice`, `empty_column`, `drop_nan`), so the C compile/link step
  fails before execution. Under `v0.1.15` the same repros also surface a lowering
  panic about `if` not being representable in the Phase 0e RISC DAG. GroupBy widens
  the same failure with additional bad lowering in `merge_agg`, but it is not
  required to trigger the bug. Window-only
  bare builds remain viable, which is why `Coral.Window` has an executed runtime
  parity lane while Frame/GroupBy/Join are still fixture-locked plus compile-checked.
  Reproducer:
  [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py)
