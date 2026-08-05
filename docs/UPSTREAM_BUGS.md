# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

Re-probe cadence is per-section: actively-blocking gets re-probed every release;
tracking-but-not-blocking gets re-probed when upstream signals movement; parked
items get re-probed only when their gating phase ships or when Coral has a new
concrete need; archived items are historical.

> **0.18.3 validation status (2026-08-04):** the annotated Chelis v0.18.3
> tag resolves to commit `29700dd73c0e35b672bdd384493054b3107ce308`; its
> publisher-checksummed Darwin arm64 archive and extracted binary have SHA-256
> `cc8737adf8c21040432d94b96635ef48895bd7ac8cdf94bd7696046c44bc7371`
> and `3a14b0d7e0a46a49c9b25f3dc61573d5972a91b411021672e09b8e3e0e9e1eba`,
> respectively; the glibc-2.31 archive and binary for the same tag are
> `36789e3a260c61b5082bc8842ba7b975899796ddf17c7b971815a2ed112904a3` and
> `ea0ba326b190366f905445b4996c3993fe6c5cc7214f14cf5d862a615b78badf`, verified
> against their sidecars but exercised by CI rather than this gate run.
>
> **This bump skips 0.18.2 entirely: 0.18.1 → 0.18.3.** The 0.7.36 / 0.18.2
> candidate was never published — it failed `scripts/repro_native_nan.py` with
> `unsupported: builtin 'floor' on 'chelis build' host emission (codegen:c)`,
> because Nautilus 0.7.39 worked the chelis#759 float-to-integer trap around
> with `floor(...)` and `floor` has no compiled-lane expression identity.
> Chelis 0.18.3 ships `cast_trunc` ([05-OP-6]) on the Surf, eval, and
> compiled-C surfaces; Nautilus 0.7.40 moves those five sites onto it, and the
> native NaN regression is green again at this pin.
>
> Nautilus 0.7.40 is published from commit
> `c8466b29ffbe4ebc4126363db8c62a06a5b10e7f`; its sidecar verifies CHB
> `2ba0d478f55d5b270801ada1b51d8dbc75a4d721a24bb8aa42f6f663b0e19bad`
> and archive
> `a881f0b96a908a8356b720bfe21e6bde724bea204310e51957b452ad3740a47c`. Those
> are byte-identical to the pre-release build this change set was first
> validated against, so the reef build is confirmed reproducible across the
> branch and the release tag.
>
> **Re-probe results at this pin:** no §Tracking entry moved. chelis#849
> (block `if`/`else` newline) and the borrowed/borrowed float tensor `neq`
> residue both stay blocked under `chelis test tests_blocked/ --expect blocked`
> (2 ok); chelis#941 stays blocked under
> `scripts/repro_native_drop_nan_blocked.py`. The empty-tensor `numel` and
> tensor-bool `not` de-narrowings from 0.18.1 remain archived below.

## Actively blocking

**Re-probe cadence:** at every compiler pin bump and before every Coral
release.

- **`_ = f(x)` marks `x` consumed when `f` destructures a record parameter
  (0.18.4 regression)** -- `chelis#1200`
  ([Chelis-Lang/chelis#1200](https://github.com/Chelis-Lang/chelis/issues/1200)).
  A `_ =` wildcard discard desugars with the `destructure: true` marker,
  opening the Linearity-F2 destructure-consume scope over the rest of the
  enclosing body; any later reuse of a variable that a record-destructuring
  callee consumed is a hard `UseAfterConsume` instead of receiving the
  implicit Copy a named binding gets. Surfaced at the 0.18.4 bump as
  74 -> 17 passing (7 test files failed to compile).
    - **Minimal reproducer:** `tests_blocked/linearity/wildcard_discard_consume.ch`.
    - **Affected Coral surface:** every test that discarded an assertion or
      IO-setup result with `_ =` and then touched a Frame again -- the
      consuming callees observed were `Frame.nrows`/`ncols`,
      `Frame.get_float_col`/`get_bool_col`/`get_int_col`, and `Reshape.melt`.
    - **Workaround:** bind, do not discard. 84 sites across seven test files
      rewritten to `asserted_N`/`bound_N` bindings, each carrying a
      `-- chelis#1200:` citation. `src/` needed no change.
    - **Re-probe trigger:** every pin bump and the release resolving
      chelis#1200. On pass, revert the cited bindings to `_ =` where the
      name is unused and archive this entry.


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
  (window-runtime lane); minimal A/B repro in the issue body. Re-probed on the
  exact 0.18.1 binary: `fmt`, `check`, and `build` still reject the minimal
  block/newline form with `expected Else, found Eof`; the workaround remains.
  `tests_blocked/parser/if_else_newline.ch` is the mechanical bump probe.

- **Float tensor `neq` has two remaining residues
  ([chelis#630](https://github.com/Chelis-Lang/chelis/issues/630)).** The exact
  0.18.1 evaluator gives IEEE-correct scalar NaN equality and owned or
  copied-left tensor `neq` now infers `tensor[n, bool]`. Native C is still
  semantically wrong: for `[NaN, -0.0, 3.5]`,
  `neq(copy(values), values)` evaluates to `[true, false, false]`, while the
  compiled program reports false for the NaN lane because generated C derives
  `neq` from the two ordered `<` comparisons. Independently, the
  borrowed/borrowed form `neq(lhs: &tensor, rhs: &tensor)` still checks at
  `tensor[n, f32]`. Under `chelis#630`, `src/frame.ch` therefore retains the
  O(n), IEEE-safe scalar host-map for float masks;
  `scripts/repro_native_nan.py` compile-links-runs
  the production mask/drop-core/count/any path. Retire that host-map only when
  native tensor `neq` agrees with the evaluator and the borrowed/borrowed probe
  infers `tensor[n, bool]`; `tests_blocked/types/tensor_neq_borrowed.ch`
  enforces the typing trigger.

- **Invoked native Frame operations still hit the recursive generic HAMT
  boundary ([chelis#941](https://github.com/Chelis-Lang/chelis/issues/941)).**
  The issue intentionally permits a branded unsupported boundary until bounded
  monomorphized symbols exist. On the exact 0.18.1 binary, a program that
  constructs a real `Frame` and calls production `drop_nan` fails `chelis
  build` at `hamt__from_pairs_rec` with `recursive generic host call ...
  requires bounded monomorphized symbols (chelis#941; [05-UNS-1])`. The
  trivial-entry Frame/GroupBy/Join harness proves stripped modules generate,
  link, and start; it does not prove invoked recursive generic Frame APIs.
  `scripts/repro_native_drop_nan_blocked.py` is the mechanical expected-failure
  probe. Re-probe on the next compiler release or any chelis#941 follow-up;
  promote the actual full-drop compile-link-run only when that probe reports
  `FIX-DETECTED`.

- **HAMT native-evaluator overhead (chelis v0.7.7, [chelis#828](https://github.com/Chelis-Lang/chelis/issues/828)).** `chelis test`
  on a 100-key HAMT (`/tmp/coral-redteam/03_hamt_collisions.ch`)
  exceeds the 30s default budget. 60 keys clocks at ~57s of
  evaluator time. Dominant cost is per-call evaluator overhead in
  the recursive `entries_h` / `from_pairs_rec` / `popcount_i64`
  paths, not algorithmic. The C-build path is unaffected because it
  emits compiled code. Re-probe when chelis ships a faster
  interpreter or when a Coral consumer hits 100+ columns in
  evaluator mode (50–100 is the documented design range).

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
  minimal A/B repro in the issue body. Re-probed on 0.18.1: the helper form
  checks at score 1.0 but fails bare build with the same lowering diagnostic;
  the inline `cast(0, int32)` control builds, and all three Coral targets
  build/link/run. The narrowing remains.

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

- **Empty tensor `numel` ([chelis#646](https://github.com/Chelis-Lang/chelis/issues/646); RESOLVED on 0.18.1).**
  Live eval on the publisher-checksummed 0.18.1 binary returns `0` for both
  `numel(to_tensor([]))` and `len(to_list(to_tensor([])))`. Coral restored
  O(1) `numel` in Frame and IO tensor row-count paths; new empty
  float/int/bool/string column tests pass end to end.

- **Tensor-bool `not` ([chelis#647](https://github.com/Chelis-Lang/chelis/issues/647); RESOLVED on 0.18.1).**
  Owned and borrowed `tensor[n, bool]` probes both infer
  `tensor[n, bool]`, eval returns the elementwise complement, and the C build
  succeeds. Coral restored direct `not(is_nan(col))` and `not(mask)` paths;
  new executed float- and integer-NaN drop tests pin both surfaces.

- **Nullary generic ADT constructors lose concrete result type arguments in
  C host lowering ([chelis#935](https://github.com/Chelis-Lang/chelis/issues/935);
  RESOLVED in the 0.17.4 release).** The official release binary from tag
  commit `0b0c92f9916163b05a483fba70473496923730e6` (SHA-256
  `d08ebfe67fed11f4458251d47e732de3249d93a3d700c87991a39e219887cc7e`)
  passed the stripped bare-C Frame (11/11), GroupBy (8/8), and Join (6/6)
  trivial-entry targets: each built, linked, ran, and exited zero. This closes
  the nullary-constructor regression without claiming that invoked recursive
  generic Frame APIs work; that separate boundary is tracked by chelis#941.

- **[chelis#5](https://github.com/Chelis-Lang/chelis/issues/5) — comparison-op return-type override clobbered tensor shape on scalar-first arg (RESOLVED v0.3.2).** Filed against v0.3.1 with the framing "both `gt(tensor, scalar)` and `gt(scalar, tensor)` in the same module break inference" — that framing was a misread. The actual bug was in `infer.rs:4441-4455`: the comparison-op return-type override only inspected `arg_tys.first()` for dim recovery, so when the first arg was `Prim(F32)` (the scalar-first form), the override returned `Prim(Bool)` and discarded the tensor shape that the v0.3.1 broadcast rewrite had already correctly produced via unification. The Coral repro escaped detection because it used an untyped top-level binding; the actual failure surfaces against a *declared* return signature. Fix walks all args with `find_map` preferring tensor over scalar for dim recovery (~10 LOC). New regression tests landed in chelis at `crates/chelis-types/tests/issue5_cmp_broadcast_both_forms.rs` and `coral_prerequisites.rs::coral_comparison_ops_broadcast_scalar_first_with_declared_signature` (the shape Coral's test missed). Coral was never functionally blocked since all our `gt` usages are scalar-scalar inside fold accumulators.

- **Eval-interpreter tensor/bool gaps (RESOLVED v0.3.1).** Bool `to_tensor([true, false, ...])` and tensor-scalar comparison broadcast (including the symmetric `gt(scalar, tensor)` form) both work. Combined with the v0.2.5 tensor-tensor `eq`/`neq`/`lt`/`gt` fix, this closed the entire eval gap that previously kept downstream Coral types `IntCol`, `BoolCol`, `is_nan`/`any_nan`/`count_nan`/`drop_nan` tensor exports, `agg_count`, `value_counts`, and tensor-threshold `filter` operations out of `chelis test` coverage. All of those now run end-to-end. Original blocker: chelis v0.2.4. Partial fix (tensor-tensor): v0.2.5. Final fix (bool `to_tensor` + tensor-scalar broadcast): v0.3.1.

- **`chelis test` per-test recompile of the dependency graph (RESOLVED v0.3.0).** Filed as [chelis#4](https://github.com/Chelis-Lang/chelis/issues/4); fixed by the "Compiled Artifact Caching" release. Wall time on this repo dropped from ~15 min (per-file loop or directory mode) to ~3 min via the new `CompiledContext` + disk cache wired into `cmd_test`. Coral later cut over from per-file matrix sharding to a single node-local parallel job using `chelis test tests/ --jobs auto` in the v0.7.6 rollout.

- **int64 C backend (RESOLVED v0.2.1, stable through v0.4.0).** Original blocker: chelis v0.1.21 / v0.2.0 panicked at `emit.rs:415:26` with "Phase 0f C backend only supports f32/bool tensors, found int64 at node 0" for any program whose dependency graph included the HAMT module. Fix shipped in v0.2.1; HAMT-backed Frame ops have built, linked, and run cleanly through every release since. No further action needed.

- **Multi-module bare-build invalid-C type-collapse (FIXED v0.1.18).** `hamt_put`, `slice`, `empty_column`, and `drop_nan` signatures previously collapsed to `int` in generated C. The stripped trivial-entry multi-module smoke (frame / groupby / join) generates valid C, links cleanly, and executes correctly; invoked recursive generic Frame operations remain narrowed under chelis#941.

- **Phase 0e RISC DAG panic for `if` (FIXED v0.1.19).** Introduced as a non-fatal silent panic with rc=0 in v0.1.18; resolved in v0.1.19. `chelis build` on stripped Frame/GroupBy/Join trivial-entry programs is clean. [`scripts/repro_multimodule_bare_build.py`](/home/jeff/Documents/scratch/coral/scripts/repro_multimodule_bare_build.py) verifies that smoke lane; chelis#941 separately narrows invoked recursive generic Frame APIs.

- **Tensor-to-list `copy(values)` compatibility (chelis v0.1.18).** Coral already applies the workaround in `describe`. Compiler-surface change preserved here as historical context for downstream shells.
