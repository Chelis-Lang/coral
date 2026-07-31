# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

Re-probe cadence is per-section: actively-blocking gets re-probed every release;
tracking-but-not-blocking gets re-probed when upstream signals movement; parked
items get re-probed only when their gating phase ships or when Coral has a new
concrete need; archived items are historical.

## Actively blocking

## Tracking

- **Block `if` with `else` on a later line rejected at parse time (chelis 0.17.1 regression, [chelis#849](https://github.com/Chelis-Lang/chelis/issues/849)).**
  An `if ... then X` inside a `{ }` block whose `else` begins on a subsequent
  line now fails with `expected Else, found Eof` on 0.17.1; the identical source
  parsed cleanly on 0.16.1, and the `else` is present (this is not the intended
  mandatory-`else`/totality behavior — it is newline-sensitivity in block
  parsing). Surfaced in `parity/run_parity.py`'s `window_program`, whose
  generated runtime program put `else` on new lines inside `{ }`-wrapped
  helpers, breaking `chelis fmt --inplace` in the pandas-parity window-runtime
  lane. Worked around by keeping every `else` on the same line as its preceding
  branch (also the canonical form `chelis fmt` emits); the site carries a
  `chelis#849` comment forbidding reintroduction of the newline. Restore the
  multi-line-in-block layout when 0.17.x parses it again. Re-probe:
  `uv run --project parity --frozen python parity/run_parity.py --strict`
  (window-runtime lane); minimal A/B repro in the issue body.

- **`numel(to_tensor([]))` returns 1 (chelis v0.7.7, [chelis#646](https://github.com/Chelis-Lang/chelis/issues/646)).** Probe at
  `/tmp/probe_numel_test.ch` confirms `numel(to_tensor([])) = 1` while
  `len(to_list(to_tensor([]))) = 0`. Affected Coral surface (`column_len`,
  `row_count`, length-checks in `filter` / `from_pairs`) worked around in
  v0.7.8 by routing through `len(to_list(xs))` — O(n) instead of O(1)
  but correct. Restore numel-based fast paths when the upstream bug is
  fixed. Re-probe at chelis v0.7.8.

- **`neq(&tensor, &tensor)` returns `tensor[n, f32]` instead of
  `tensor[n, bool]` (chelis v0.7.7, [chelis#630](https://github.com/Chelis-Lang/chelis/issues/630)).** The
  return dtype is the type-level symptom of that issue: `neq` lowers
  from `cmplt` / `max_elem` float arithmetic with no native
  bool-returning `CmpNe`, so the result carries `f32`. Triggered the lint cleanup
  rewrite of `is_nan` from the original `neq(copy(col), col)` to a
  `map(fn x -> neq(x, x))` + `bool_list_to_tensor` form, which is
  correct but O(n) on the host lane and gives up the tensor-fusion
  path the spec promises ("filter→mutate→aggregate compiles to a
  single fused kernel"). Restore the tensor-native `is_nan` when the
  upstream `neq` overload resolution produces `tensor[n, bool]` for
  `(&tensor, &tensor)` arg pairs.

- **HAMT native-evaluator overhead (chelis v0.7.7, [chelis#828](https://github.com/Chelis-Lang/chelis/issues/828)).** `chelis test`
  on a 100-key HAMT (`/tmp/coral-redteam/03_hamt_collisions.ch`)
  exceeds the 30s default budget. 60 keys clocks at ~57s of
  evaluator time. Dominant cost is per-call evaluator overhead in
  the recursive `entries_h` / `from_pairs_rec` / `popcount_i64`
  paths, not algorithmic. The C-build path is unaffected because it
  emits compiled code. Re-probe when chelis ships a faster
  interpreter or when a Coral consumer hits 100+ columns in
  evaluator mode (50–100 is the documented design range).

- **`not` is scalar-only in chelis v0.7.7 ([chelis#647](https://github.com/Chelis-Lang/chelis/issues/647)).** `not(tensor[n, bool])`
  fails with "bool op expects bool arg". Affected Coral surface
  (`drop_nan` originally did `filter(df, not(is_nan(...)))`) worked
  around in v0.7.8 by reformulating the keep-mask as
  `bool_list_to_tensor(map(fn x -> eq(x, x), ...))`. Restore the
  direct `not(is_nan_mask)` form when chelis ships a bool-tensor
  `not`.

- **[chelis#741](https://github.com/Chelis-Lang/chelis/issues/741) —
  bare-lane tensor-op axis must be syntactic (chelis ≤ 0.16.1).**
  `chelis build` (bare, single-file) rejects `gather` / `sort` axis
  arguments passed through a zero-arg helper (`zero_i32()` defined as
  `cast(0, int32)`) with "`gather` axis is not a compile-time integer
  constant: rank monomorphization cannot resolve it to a fixed axis"; the
  diagnostic's admitted forms are a literal or an inline
  `cast(<int>, int32)`. Verified identical on 0.12.1, 0.14.0, and 0.16.1
  — pre-existing, surfaced when `scripts/repro_multimodule_bare_build.py`
  regained coverage at the 0.16.1 pin bump (it had been dark; see the
  probe's History note). The package lane (`chelis reef build`) and the
  `chelis test` lane are unaffected. Worked around in `src/frame.ch` by
  inlining `cast(0, int32)` at all 15 axis sites (12 `gather` + 3
  `sort`) and dropping the
  `zero_i32` helper. Restore a named helper when chelis#741 resolves
  helper-call axes in rank monomorphization. Re-probe:
  `python3 scripts/repro_multimodule_bare_build.py` (all three targets);
  minimal A/B repro in the issue body.

- **Unbound `|>` pipe targets accepted in large bare builds (chelis 0.16.1, unnarrowed; parked draft [`docs/issue_drafts/bare_build_unbound_pipe_targets.md`](issue_drafts/bare_build_unbound_pipe_targets.md)).**
  While the probe's
  prefixer still missed pipe-position references, `chelis build` accepted
  a multi-thousand-line concat containing ~13 unbound function references
  in `x |> name` position and emitted C that calls them as undeclared
  functions (native compile then failed with implicit-declaration
  errors). Minimal repros — a single unbound pipe target in `main` or in
  a nested `if` branch — are correctly rejected with `UnboundVariable`,
  so the admission is scale- or context-dependent. Repro: check out
  `scripts/repro_multimodule_bare_build.py` from before the whole-word
  `apply_name_map` fix in the 0.16.1 bump change set and run
  `--target groupby`. The parked draft carries the full body and the
  narrow-first filing condition; the single-reference rejection it
  depends on is pinned by `tests_neg/frame/unbound_function_neg.ch`.
  Re-probed at the 0.17.1 pin bump: unbound `|>` pipe targets are now
  correctly rejected with `UnboundVariable` in every constructible case —
  single reference in `main`, inside a nested `if` branch, and at scale (40
  defs each with a distinct unbound pipe target, all 40 diagnosed). The
  anomalous acceptance is not reproducible on 0.17.1, so the draft stays
  unfiled per its own narrow-first condition (an unreproducible report would
  not be actionable). Keep the draft cite until either a minimal reproducer is
  isolated on a supported pin or the entry is retired.

## Parked

- **`grad` C-backend lowering ([chelis#405](https://github.com/Chelis-Lang/chelis/issues/405)).** `chelis check` accepts `grad(f)(x)` at score 1.0; `chelis build --target c` rejects with "can't lower these defs — their body applies/binds `grad` (or `vmap`) in a position the host lane can't resolve". Upstream recorded this as a Phase 5 deferred item (commit `a3ca2be` in chelis v0.3.1: `docs(spec): record host-lane scalar AD as Phase 5 deferred item`); the design (forward-mode dual numbers) is locked behind a real driver appearing. Coral's `grad` usage stays illustrative in docs. **Re-probe only when chelis ships Phase 5 or when Coral acquires a concrete scalar-AD use case worth pushing for it.** No per-release re-probe.

- **`Std.Io.Parquet` runtime backing ([chelis#850](https://github.com/Chelis-Lang/chelis/issues/850)).** Missing upstream feature, not a
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
  unavailable. Re-probed at the chelis 0.16.1 pin bump: `import
  Std.Io.Parquet (read_parquet)` still checks clean and
  `libchelis_runtime.a` still contains no parquet symbol. Re-probed at the
  0.17.1 pin bump and filed as chelis#850: a call to the sig-only
  `read_parquet` (with the exact chelis-std 0.4.0 module) checks at score 1.0
  with an empty error list, and `chelis build` lowers it to an undeclared C
  `read_parquet(...)` call that fails the native compile — the issue is filed
  around that loud-checking gap (a score-1.0 check must not lower to a missing
  runtime symbol), not just the missing feature. **Re-probe when upstream
  signals movement** or at the next major coral release, not on patches.

## Archived

- **Nullary generic ADT constructors lose concrete result type arguments in
  C host lowering ([chelis#935](https://github.com/Chelis-Lang/chelis/issues/935);
  RESOLVED in the 0.17.4 candidate).** The exact release-candidate binary from
  source commit `9a58c5781105bbe07d37afbb6ecfc7b3a879e0de` (SHA-256
  `7562c464ab68e8878fd20d24e0194deb204e092aebdff4e7c8c094e535fc4a39`)
  passed the stripped bare-C Frame (11/11), GroupBy (8/8), and Join (6/6)
  targets: each built, linked, ran, and exited zero. This is the downstream
  acceptance oracle that had been required before archiving, not an inference
  from the upstream unit reproducer.

- **[chelis#5](https://github.com/Chelis-Lang/chelis/issues/5) — comparison-op return-type override clobbered tensor shape on scalar-first arg (RESOLVED v0.3.2).** Filed against v0.3.1 with the framing "both `gt(tensor, scalar)` and `gt(scalar, tensor)` in the same module break inference" — that framing was a misread. The actual bug was in `infer.rs:4441-4455`: the comparison-op return-type override only inspected `arg_tys.first()` for dim recovery, so when the first arg was `Prim(F32)` (the scalar-first form), the override returned `Prim(Bool)` and discarded the tensor shape that the v0.3.1 broadcast rewrite had already correctly produced via unification. The Coral repro escaped detection because it used an untyped top-level binding; the actual failure surfaces against a *declared* return signature. Fix walks all args with `find_map` preferring tensor over scalar for dim recovery (~10 LOC). New regression tests landed in chelis at `crates/chelis-types/tests/issue5_cmp_broadcast_both_forms.rs` and `coral_prerequisites.rs::coral_comparison_ops_broadcast_scalar_first_with_declared_signature` (the shape Coral's test missed). Coral was never functionally blocked since all our `gt` usages are scalar-scalar inside fold accumulators.

- **Eval-interpreter tensor/bool gaps (RESOLVED v0.3.1).** Bool `to_tensor([true, false, ...])` and tensor-scalar comparison broadcast (including the symmetric `gt(scalar, tensor)` form) both work. Combined with the v0.2.5 tensor-tensor `eq`/`neq`/`lt`/`gt` fix, this closed the entire eval gap that previously kept downstream Coral types `IntCol`, `BoolCol`, `is_nan`/`any_nan`/`count_nan`/`drop_nan` tensor exports, `agg_count`, `value_counts`, and tensor-threshold `filter` operations out of `chelis test` coverage. All of those now run end-to-end. Original blocker: chelis v0.2.4. Partial fix (tensor-tensor): v0.2.5. Final fix (bool `to_tensor` + tensor-scalar broadcast): v0.3.1.

- **`chelis test` per-test recompile of the dependency graph (RESOLVED v0.3.0).** Filed as [chelis#4](https://github.com/Chelis-Lang/chelis/issues/4); fixed by the "Compiled Artifact Caching" release. Wall time on this repo dropped from ~15 min (per-file loop or directory mode) to ~3 min via the new `CompiledContext` + disk cache wired into `cmd_test`. Coral later cut over from per-file matrix sharding to a single node-local parallel job using `chelis test tests/ --jobs auto` in the v0.7.6 rollout.

- **int64 C backend (RESOLVED v0.2.1, stable through v0.4.0).** Original blocker: chelis v0.1.21 / v0.2.0 panicked at `emit.rs:415:26` with "Phase 0f C backend only supports f32/bool tensors, found int64 at node 0" for any program whose dependency graph included the HAMT module. Fix shipped in v0.2.1; HAMT-backed Frame ops have built, linked, and run cleanly through every release since. No further action needed.

- **Multi-module bare-build invalid-C type-collapse (FIXED v0.1.18).** `hamt_put`, `slice`, `empty_column`, and `drop_nan` signatures previously collapsed to `int` in generated C. Stripped multi-module bare-build (frame / groupby / join) generates valid C, links cleanly, executes correctly.

- **Phase 0e RISC DAG panic for `if` (FIXED v0.1.19).** Introduced as a non-fatal silent panic with rc=0 in v0.1.18; resolved in v0.1.19. `chelis build` on stripped Frame/GroupBy/Join programs is fully clean. [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py) verifies end-to-end operation and exits 0 on success.

- **Tensor-to-list `copy(values)` compatibility (chelis v0.1.18).** Coral already applies the workaround in `describe`. Compiler-surface change preserved here as historical context for downstream shells.
