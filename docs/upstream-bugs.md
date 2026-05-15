# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

Re-probe cadence is per-section: actively-blocking gets re-probed every release;
tracking-but-not-blocking gets re-probed when upstream signals movement; parked
items get re-probed only when their gating phase ships or when Coral has a new
concrete need; archived items are historical.

## Actively blocking Coral

(none — the eval-interpreter gap that gated `chelis test` from `IntCol` /
`BoolCol` / `is_nan` / `filter`-by-mask was the last open blocker, resolved
upstream in v0.3.1; the issue#5 declared-signature follow-up resolved in
v0.3.2.)

## Tracking (filed upstream, not blocking)

- **`numel(to_tensor([]))` returns 1 (chelis v0.7.7).** Probe at
  `/tmp/probe_numel_test.ch` confirms `numel(to_tensor([])) = 1` while
  `len(to_list(to_tensor([]))) = 0`. Affected Coral surface (`column_len`,
  `row_count`, length-checks in `filter` / `from_pairs`) worked around in
  v0.7.8 by routing through `len(to_list(xs))` — O(n) instead of O(1)
  but correct. Restore numel-based fast paths when the upstream bug is
  fixed. Re-probe at chelis v0.7.8.

- **`neq(&tensor, &tensor)` returns `tensor[n, f32]` instead of
  `tensor[n, bool]` (chelis v0.7.7).** Triggered the lint cleanup
  rewrite of `is_nan` from the original `neq(copy(col), col)` to a
  `map(fn x -> neq(x, x))` + `bool_list_to_tensor` form, which is
  correct but O(n) on the host lane and gives up the tensor-fusion
  path the spec promises ("filter→mutate→aggregate compiles to a
  single fused kernel"). Restore the tensor-native `is_nan` when the
  upstream `neq` overload resolution produces `tensor[n, bool]` for
  `(&tensor, &tensor)` arg pairs.

- **HAMT native-evaluator overhead (chelis v0.7.7).** `chelis test`
  on a 100-key HAMT (`/tmp/coral-redteam/03_hamt_collisions.ch`)
  exceeds the 30s default budget. 60 keys clocks at ~57s of
  evaluator time. Dominant cost is per-call evaluator overhead in
  the recursive `entries_h` / `from_pairs_rec` / `popcount_i64`
  paths, not algorithmic. The C-build path is unaffected because it
  emits compiled code. Re-probe when chelis ships a faster
  interpreter or when a Coral consumer hits 100+ columns in
  evaluator mode (50–100 is the documented design range).

- **`not` is scalar-only in chelis v0.7.7.** `not(tensor[n, bool])`
  fails with "bool op expects bool arg". Affected Coral surface
  (`drop_nan` originally did `filter(df, not(is_nan(...)))`) worked
  around in v0.7.8 by reformulating the keep-mask as
  `bool_list_to_tensor(map(fn x -> eq(x, x), ...))`. Restore the
  direct `not(is_nan_mask)` form when chelis ships a bool-tensor
  `not`.

## Parked upstream

- **`grad` C-backend lowering.** `chelis check` accepts `grad(f)(x)` at score 1.0; `chelis build --target c` rejects with "can't lower these defs — their body applies/binds `grad` (or `vmap`) in a position the host lane can't resolve". Upstream recorded this as a Phase 5 deferred item (commit `a3ca2be` in chelis v0.3.1: `docs(spec): record host-lane scalar AD as Phase 5 deferred item`); the design (forward-mode dual numbers) is locked behind a real driver appearing. Coral's `grad` usage stays illustrative in docs. **Re-probe only when chelis ships Phase 5 or when Coral acquires a concrete scalar-AD use case worth pushing for it.** No per-release re-probe.

- **`Std.Io.Parquet` runtime backing.** Missing upstream feature, not a
  regression. `chelis-std`'s `io/parquet.ch` exports signatures only
  (`read_parquet`, `write_parquet`) with no callable function bodies, so
  Coral's workaround (`read_parquet_frame` / `write_parquet_frame` as
  `fail(...)` stubs in `src/io.ch`) holds. Re-probed at chelis v0.4.0
  and v0.5.0: still missing; v0.5.0 check scored 1.0 and the C build
  reached the native-link failure because the runtime symbol was absent.
  Re-probed during the v0.7.6 rollout: `import Std.Io.Parquet
  (read_parquet)` still checks at score 1.0, `libchelis_runtime.a` still
  contains no `Parquet` / `read_parquet` symbol, and the C build now
  stops earlier with `range start index 2 out of range for slice of
  length 1`. The user-visible conclusion is unchanged: Parquet remains
  unavailable. **Re-probe when upstream signals movement** or at the
  next major coral release, not on patches.

## Archive (resolved upstream)

- **[chelis#5](https://github.com/Chelis-Lang/chelis/issues/5) — comparison-op return-type override clobbered tensor shape on scalar-first arg (RESOLVED v0.3.2).** Filed against v0.3.1 with the framing "both `gt(tensor, scalar)` and `gt(scalar, tensor)` in the same module break inference" — that framing was a misread. The actual bug was in `infer.rs:4441-4455`: the comparison-op return-type override only inspected `arg_tys.first()` for dim recovery, so when the first arg was `Prim(F32)` (the scalar-first form), the override returned `Prim(Bool)` and discarded the tensor shape that the v0.3.1 broadcast rewrite had already correctly produced via unification. The Coral repro escaped detection because it used an untyped top-level binding; the actual failure surfaces against a *declared* return signature. Fix walks all args with `find_map` preferring tensor over scalar for dim recovery (~10 LOC). New regression tests landed in chelis at `crates/chelis-types/tests/issue5_cmp_broadcast_both_forms.rs` and `coral_prerequisites.rs::coral_comparison_ops_broadcast_scalar_first_with_declared_signature` (the shape Coral's test missed). Coral was never functionally blocked since all our `gt` usages are scalar-scalar inside fold accumulators.

- **Eval-interpreter tensor/bool gaps (RESOLVED v0.3.1).** Bool `to_tensor([true, false, ...])` and tensor-scalar comparison broadcast (including the symmetric `gt(scalar, tensor)` form) both work. Combined with the v0.2.5 tensor-tensor `eq`/`neq`/`lt`/`gt` fix, this closed the entire eval gap that previously kept downstream Coral types `IntCol`, `BoolCol`, `is_nan`/`any_nan`/`count_nan`/`drop_nan` tensor exports, `agg_count`, `value_counts`, and tensor-threshold `filter` operations out of `chelis test` coverage. All of those now run end-to-end. Original blocker: chelis v0.2.4. Partial fix (tensor-tensor): v0.2.5. Final fix (bool `to_tensor` + tensor-scalar broadcast): v0.3.1.

- **`chelis test` per-test recompile of the dependency graph (RESOLVED v0.3.0).** Filed as [chelis#4](https://github.com/Chelis-Lang/chelis/issues/4); fixed by the "Compiled Artifact Caching" release. Wall time on this repo dropped from ~15 min (per-file loop or directory mode) to ~3 min via the new `CompiledContext` + disk cache wired into `cmd_test`. Coral later cut over from per-file matrix sharding to a single node-local parallel job using `chelis test tests/ --jobs auto` in the v0.7.6 rollout.

- **int64 C backend (RESOLVED v0.2.1, stable through v0.4.0).** Original blocker: chelis v0.1.21 / v0.2.0 panicked at `emit.rs:415:26` with "Phase 0f C backend only supports f32/bool tensors, found int64 at node 0" for any program whose dependency graph included the HAMT module. Fix shipped in v0.2.1; HAMT-backed Frame ops have built, linked, and run cleanly through every release since. No further action needed.

- **Multi-module bare-build invalid-C type-collapse (FIXED v0.1.18).** `hamt_put`, `slice`, `empty_column`, and `drop_nan` signatures previously collapsed to `int` in generated C. Stripped multi-module bare-build (frame / groupby / join) generates valid C, links cleanly, executes correctly.

- **Phase 0e RISC DAG panic for `if` (FIXED v0.1.19).** Introduced as a non-fatal silent panic with rc=0 in v0.1.18; resolved in v0.1.19. `chelis build` on stripped Frame/GroupBy/Join programs is fully clean. [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py) verifies end-to-end operation and exits 0 on success.

- **Tensor-to-list `copy(values)` compatibility (chelis v0.1.18).** Coral already applies the workaround in `describe`. Compiler-surface change preserved here as historical context for downstream shells.
