# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

- **Upstream blocker (v0.2.4): `chelis test` evaluator does not support
  tensor-broadcast comparison ops** — the `chelis test` runner uses the
  eval interpreter, which rejects tensor-tensor `eq`/`neq`/`lt`/`gt` and
  tensor-scalar `gt` with `eq/neq expect matching scalar args, got
  (Tensor, Tensor)` or `ordered comparison expects matching numeric args,
  got (Some(Tensor(...)), Some(Float(150.0)))`. `to_tensor([true, ...])`
  is also rejected (`to_tensor expects numeric List elements, got bool`).
  Consequences for Coral's `tests/*.ch` suite:
  - `int_col_of_list`, `IntCol(values, mask)`, `BoolCol(...)`, `filter`
    (needs a bool tensor mask), `is_nan`/`fill_nan`/`drop_nan` (call
    `neq` on float tensors internally), `is_nan_int`/`fill_nan_int`/
    `drop_nan_int` (need an IntCol input), and any aggregation that
    emits IntCol (`agg_count`, `value_counts`, `agg_sum` on ints)
    cannot be invoked from `chelis test` until upstream lifts this gap.
  - `tests/*.ch` works around the gap with element-wise scalar
    reimplementations (`is_nan_local(x: f32) -> bool = neq(x, x)` then
    folded over `to_list(t)`). The actual `Coral.Frame.is_nan` /
    `any_nan` / `count_nan` / `drop_nan` tensor exports remain
    runtime-unverified at the `chelis test` level.
  - The `chelis build`-target lane still supports tensor broadcasts
    correctly, so `parity/run_parity.py` window runtime parity covers
    those code paths end-to-end.
  Probed v0.2.4: BLOCKED. Re-probe each release; the gap is between the
  eval interpreter and the typed runtime, not the C backend.
  Probed v0.2.5: PARTIALLY RESOLVED — tensor-tensor `eq`/`neq`/`lt`/`gt`
  on f32 and int64 tensors now work in `chelis test`, which unblocks
  `IntCol(values, mask)` construction (mask via `neq(int_tensor,
  int_tensor)`), `is_nan` / `count_nan` / `any_nan` on float tensors, and
  IntCol-emitting aggregations. Still blocked under v0.2.5:
  `to_tensor([true, false, ...])` (rejected with `to_tensor expects
  numeric List elements, got bool`) and tensor-scalar `gt(tensor, scalar)`
  (rejected with `type mismatch: tensor[Wildcard, f32] vs f32`). Bool
  CSV/JSON round trips and any code path that calls `bool_list_to_tensor`
  remain blocked at the eval level.


- **Upstream blocker (v0.1.21, still present v0.2.0, still present v0.2.1): `grad` type-checks but fails to build** — `grad(f, wrt=x)`
  and `grad(f)(x)` both type-check with score 1.0, but `chelis build --target c` rejects
  every reachable pattern with: "can't lower these defs — their body applies/binds `grad`
  (or `vmap`) in a position the host lane can't resolve." The error message suggests using pure tensor
  ops (sum, mul, einsum) and a "local wrapper over function param" pattern, but `grad`
  simultaneously requires "scalar floating output", making the combination unreachable for
  Coral's frame-based computations. All `grad` usage remains illustrative in docs until
  upstream resolves C-backend lowering for scalar AD. Probed v0.2.1: STILL BLOCKED (same error).
  Probed v0.2.2: STILL BLOCKED (same error: "can't lower these defs — their body applies/binds `grad` (or `vmap`) in a position the host lane can't resolve", exit 1).
  Probed v0.2.3: STILL BLOCKED (same error, exit 1).
  Probed v0.2.4: STILL BLOCKED (same lowering error; identical workaround guidance, exit 1).
  Probed v0.2.5: STILL BLOCKED — `chelis check` resolves `grad(f)(x)` at score 1.0 (107 typed nodes, no errors), but `chelis build --target c` rejects with the same "can't lower these defs" error and identical workaround guidance, exit 1.

- **Upstream limitation (v0.1.21, still present v0.2.0): C backend ("Phase 0f") rejects int64 tensors** — `chelis
  build --target c` panics with "Phase 0f C backend only supports f32/bool tensors, found
  int64 at node 0" for any program whose dependency graph includes the HAMT module (which
  uses `tensor[n, int64]` internally for key/value arrays). This means Frame-level runtime
  tests (build + link + run) cannot execute for any Coral module that uses `from_pairs`.
  Window tests are unaffected (window.ch operates on f32 tensors only). The negative test
  suite uses `chelis check` (semantic analysis) instead of build+run, which avoids the
  backend limitation while still testing type-safety properties of the public API.
  Probed v0.2.0: STILL BLOCKED (same panic: `emit.rs:415:26`, exit 101).
  Probed v0.2.1: RESOLVED — standalone int64 tensor programs and the HAMT-backed
  stripped Frame/GroupBy/Join bare builds all pass `chelis build --target c` cleanly
  (exit 0, no panic, valid C, link succeeds, binary executes correctly).
  Probed v0.2.2: STILL RESOLVED — all three repro bare-builds (frame, groupby, join) pass cleanly (exit 0, valid C, link and run OK).
  Probed v0.2.3: STILL RESOLVED — all three repro bare-builds pass cleanly (exit 0, valid C, link and run OK).
  Probed v0.2.4: STILL RESOLVED — int64 tensor programs build, link, and run cleanly; HAMT-dependent ops also runtime-tested via `chelis test` end-to-end (from_pairs, with_column, describe, value_counts).
  Probed v0.2.5: STILL RESOLVED — int64 tensor `chelis build --target c` exits 0, valid C generated.

- **Upstream blocker (v0.1.21, still present v0.2.0): `Std.IO.Parquet` module is absent** — in v0.1.21
  the module resolved at import-check time (score 1.0 on empty import list) but exported no callable
  functions. In v0.2.0 the behavior regressed further: `import Std.IO.Parquet (read_parquet)` now
  returns `error: unresolved import 'Std.IO.Parquet'` (exit 1) — the module no longer resolves at
  all. The stdlib archive (`chelis-std-0.1.0`) contains `io/csv.ch`, `io/json.ch`, and
  `io/safetensors.ch` but no `io/parquet.ch`. `read_parquet_frame` / `write_parquet_frame` remain
  `fail(...)` stubs in `src/io.ch` until parquet lands upstream. Track the `Chelis-Lang/chelis`
  release notes for when `Std.IO.Parquet` becomes functional. Probed v0.2.0: STILL BLOCKED
  (import fails hard; `error: unresolved import 'Std.IO.Parquet'`).
  Probed v0.2.1: PARTIALLY RESTORED — `chelis check` now resolves the import at score 1.0
  (regression from v0.2.0 fixed; back to v0.1.21 behavior), but `chelis build --target c`
  panics at `lower.rs:1631` (exit 101). The module still exports no callable functions; stubs remain.
  Probed v0.2.2: STILL PARTIALLY RESTORED — `chelis check` resolves the import at score 1.0 (unchanged); build behavior not re-probed (stubs remain; same status as v0.2.1).
  Probed v0.2.3: STILL PARTIALLY RESTORED — `chelis check` resolves the import at score 1.0 (unchanged); stubs remain.
  Probed v0.2.4: STILL PARTIALLY RESTORED — `chelis check` resolves the import at score 1.0 (unchanged); stubs remain.
  Probed v0.2.5: BUILD-CLEAN, LINK FAILS — `chelis check` resolves at score 1.0 and `chelis build --target c` now exits 0 (the lower.rs panic from v0.2.1+ is gone), but native `gcc` link fails with "implicit declaration of function `pkg__chelis__std__Std__IO__Parquet__read_parquet`" because the runtime library does not implement the symbol. `read_parquet_frame` / `write_parquet_frame` stubs remain in `src/io.ch` until upstream ships the runtime backing.

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
