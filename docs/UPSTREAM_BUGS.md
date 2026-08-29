# Coral Upstream Bugs

Tracked upstream/toolchain issues that affect Coral development.

Re-probe cadence is per-section: actively-blocking gets re-probed at every
compiler pin bump and every release; tracking-but-not-blocking gets re-probed
when upstream signals movement; parked items get re-probed only when their
gating phase ships or when Coral has a new concrete need; archived items are
historical.

§Actively blocking is currently empty and is kept rather than deleted:
chelis#1200 vacated it at the 0.18.5 bump (see §Archived), and an
actively-blocking entry is the shape a future compiler regression takes. The
section holds only entries, so `chelis reef conform audit` can machine-check
every citation in it.

> **0.18.6 validation status (2026-08-29):** the annotated Chelis v0.18.6
> tag resolves to commit `cf49f85bf0d1bca2c87c88a3e459c446912189c0`; its
> publisher-checksummed Darwin arm64 archive and extracted binary have SHA-256
> `08580435570c6fd44716f4d5c64117e973e379808cefeaaa97c8faefa2588f6c`
> and `1c88c737d7d3740eb4adbe7b50ea31d29ee64498b9d74b35664255ca16aea8d4`,
> respectively; the glibc-2.31 archive and binary for the same tag are
> `fb9ef6701fbf0ef2532bcbafb213ca80c21d7b13da0b341b55c64ba89aa8e8fa` and
> `289cd344849bf902f993ec38dfd4473cd1e06bfa4e6fb139db9977eb2ff2b06e`, verified
> against their sidecars but exercised by CI rather than this gate run. Every
> command in this gate run ran on the Darwin arm64 binary at that exact hash.
>
> **This bump carries a cross-repo ordering debt.** Reef enforces exact
> compiler-pin equality on dependencies, so `chelis reef build` refuses the
> last published Nautilus (0.7.42, declaring `=0.18.5`) at coral's new
> `=0.18.6` pin:
>
> ```
> error: package.compiler must be `=0.18.6` in `nautilus`
> ```
>
> No Nautilus release declaring `=0.18.6` exists yet. The dependency is pinned
> to **0.7.43**, the version the Nautilus 0.18.6 bump stages: that change
> moves the package version and the compiler pin in one manifest, so 0.7.43
> is what the eventual release will declare. Pinning a staged version is
> deliberate, and it is the same call the 0.18.5 bump made. Both 0.7.42 and
> 0.7.43 are red today, but only 0.7.43 is correct as written when the
> cascade tags; 0.7.42 would need a second edit.
>
> Every gate result below was produced against a Nautilus artifact built from
> the `chore/chelis-0.18.6` working tree at base commit
> `f209413cba4b10e43014ae61f402b69ee84c04b2` and published into a private
> registry (`CHELIS_REEF_HOME`), so the shared registry other shells resolve
> against was never touched. CHB SHA-256
> `99cfc7e0700cdf7f884a71a2752e8916fe3255836b92c698eb9fe26513e27cb3`,
> archive SHA-256
> `884f582328667a1617ad7b7aa371d96b6f99279e7e4c20700591dfde4d9fa306`; local
> build hashes, no publisher checksum. Nautilus needed no source change for
> 0.18.6, so what is outstanding is a release, not a fix.
>
> **Re-probe results at this pin:**
>
> - chelis#630's **typing** residue is **fixed**: `neq(&tensor[n, f32],
>   &tensor[n, f32])` now checks at `tensor[n, bool]`, so
>   `tests_blocked/types/tensor_neq_borrowed.ch` reported CONFIG-ERROR
>   (nothing compile-failed) and is promoted to the executed regression
>   `tests/types.ch`. The **native IEEE** residue is unchanged and keeps
>   `Coral.Frame.is_nan`'s scalar host-map alive; it now has its own
>   expected-to-fail probe, `scripts/repro_native_neq_blocked.py`.
> - chelis#849 (block `if`/`else` newline) still blocks under
>   `chelis test tests_blocked/ --expect blocked` (1 ok).
> - chelis#741 stays narrowed. Re-probed A/B on the exact binary: a
>   `zero_i32()` helper axis is still rejected with ``gather` axis is not a
>   compile-time integer constant`, the inline `cast(0, int32)` control
>   builds, and all three `scripts/repro_multimodule_bare_build.py` targets
>   build, link, and run.
> - The chelis#1226 Frame-read boundary is unchanged: `--target construct`
>   builds/links/runs and agrees with eval, `--target nrows` still stops at
>   `column_len`, and the bare `drop_nan` probe still stops at the
>   unresolved dim-generic `Column` match.
> - **0.18.6 changed the shape of the native lane's entrypoint**, which broke
>   four probe harnesses at once rather than any Coral source. `chelis build`
>   now emits its own `int main(void)` that evaluates every effect-free
>   nullary definition and prints one `<name> = <value>` observation line
>   (chelis#1079/#1082/#1083). The old technique -- rename the entry, supply
>   a driver `main`, read the exit code -- collides with that emitted `main`
>   and leaves a call to the renamed symbol undeclared. All four probes now
>   run the compile command `chelis build` itself prints and read the entry's
>   observation line, which is the same line shape `chelis eval` prints. See
>   §Tracking's harness note.

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
  (window-runtime lane); minimal A/B repro in the issue body. Re-probed on the
  exact 0.18.1 binary: `fmt`, `check`, and `build` still reject the minimal
  block/newline form with `expected Else, found Eof`; the workaround remains.
  `tests_blocked/parser/if_else_newline.ch` is the mechanical bump probe, and
  it still compile-fails with the pinned diagnostic on 0.18.6 -- note that
  chelis#1267 reworded three of the four v0.19 block-separator diagnostics in
  that release without touching this one.

- **Float tensor `neq`: one residue left, and it is the native one
  ([chelis#630](https://github.com/Chelis-Lang/chelis/issues/630)).** Two
  residues were tracked here; 0.18.6 closes one of them.
    - **De-narrowed.** The borrowed/borrowed form
      `neq(lhs: &tensor[n, f32], rhs: &tensor[n, f32])` now checks at
      `tensor[n, bool]`; through 0.18.5 it selected the f32 overload and the
      declared signature was rejected. `chelis check` on the pinned probe
      scores 1.0 with an empty error list, so
      `tests_blocked/types/tensor_neq_borrowed.ch` reported CONFIG-ERROR
      (nothing compile-failed) and is promoted, per its own `.expect`
      instruction, to the executed regression `tests/types.ch`.
    - **Still blocked.** Native C remains semantically wrong for NaN. For
      `[NaN, -0.0, 3.5]`, `neq(copy(values), values)` evaluates to
      `[true, false, false]` under `chelis eval`, while the compiled program
      reports the NaN lane equal, because generated C derives `neq` from the
      two ordered `<` comparisons. Measured on the exact 0.18.6 binary as a
      lane bitmask: eval `1`, native `0`.
    - **Narrowing retained.** `src/frame.ch` therefore keeps its O(n),
      IEEE-safe scalar host-map for float masks under `chelis#630`.
    - **Probes.** `scripts/repro_native_neq_blocked.py` is the
      expected-to-fail trigger: it compares the two lanes on one source and
      reports FIX-DETECTED when they agree. It exists because the promotion
      above removed the only `tests_blocked/` entry this narrowing had, and a
      retained workaround with no live trigger outlives its bug. The residue
      is a wrong runtime answer rather than a rejected program, so it cannot
      live under `tests_blocked/` -- nothing compile-fails.
      `scripts/repro_native_nan.py` separately compile-links-runs the
      production mask/drop-core/count/any path and proves the host-map still
      works. Retire the host-map when the blocked probe reports
      FIX-DETECTED.

- **Native-lane probe harnesses had to change shape for 0.18.6 (no upstream
  defect; recorded here because every re-probe result above depends on it).**
  chelis#1079/#1082/#1083 make `chelis build` emit its own `int main(void)`
  for the C target, which evaluates every effect-free nullary definition and
  prints one `<name> = <value>` observation line. Four harnesses drove the
  native lane by renaming the entry symbol, supplying a driver `main`, and
  reading the process exit code; all four broke at once on this pin, with
  `call to undeclared function 'main__main'` or `duplicate symbol '_main'`.
  That is a harness incompatibility, not a Coral source defect: the generated
  C is valid and the same programs build, link, and run. Every probe now
  executes the compile command `chelis build` itself prints -- which also
  supplies the platform vector-math library the emitted `main` newly pulls in
  through Nautilus's tensor specializations -- and reads the entry's
  observation line, the same line shape `chelis eval` prints. Affected:
  `scripts/repro_multimodule_bare_build.py` (which now owns the shared
  helpers), `scripts/repro_native_nan.py`,
  `scripts/repro_package_frame_build.py`, and `parity/run_parity.py`'s
  window-runtime lane. The emitted entry always exits zero, so an exit-code
  verdict is no longer available to any of them.

- **Frame reads are still build-lane-blocked; Frame construction no longer is
  ([chelis#1226](https://github.com/Chelis-Lang/chelis/issues/1226),
  [coral#26](https://github.com/Chelis-Lang/coral/issues/26); successor to the
  retired chelis#941 boundary).** 0.18.5 lands bounded memoized
  monomorphization (chelis#1158), the non-recursive inlining fix
  (chelis#1201), and recursive dimension-generic monomorphization
  (chelis#1216). Measured on the exact 0.18.5 binary in the package lane and
  re-measured unchanged on 0.18.6:
    - **De-narrowed.** Constructing a real `Frame` and reading `ncols` builds,
      links, runs, and returns the same value as `chelis eval`. Through 0.18.4
      this was impossible -- `from_pairs` rejected at `hamt__from_pairs_rec`
      with the branded chelis#941 diagnostic, so a `Frame` could not be built
      at all. `scripts/repro_package_frame_build.py --target construct` pins
      the new capability.
    - **Still blocked.** Any read that pulls a column back out of the HAMT
      does not lower. `nrows` fails with `generic host call
      `pkg__coral__Coral__Frame__column_len` has no concrete checked type
      application to specialize (chelis#1226; [05-UNS-1])`, and `drop_nan`
      fails one layer further in on a `match` over `Column`'s constructors
      with `generic ADT `Column` has no applied type arguments`. Both come from
      the same round trip: `hamt_get[a](Hamt[a], string) -> Option[a]`
      instantiated at `a = Column[n]` does not carry the dimension back out.
      chelis#1226 is the live standing [05-UNS-5] authority for the class.
    - **Citation gap.** The `match` residue carries no issue number of its own,
      unlike the `column_len` one. Filed as
      [chelis#1260](https://github.com/Chelis-Lang/chelis/issues/1260) so a
      downstream probe has something live to cite.
    - **Probes.** `scripts/repro_package_frame_build.py` (both targets, package
      lane) and `scripts/repro_native_drop_nan_blocked.py` (bare concatenated
      lane). Re-probe at every pin bump; promote the full compile-link-run of
      an invoked Frame read only when `--target nrows` reports `FIX-DETECTED`.
    - **Coral-side fix landed with this measurement.** `hamt_entries` was used
      in `frame.ch`, `groupby.ch`, `join.ch`, and `reshape.ch` without being
      imported. `chelis check` scored 1.0 with an empty `unresolved_names` list
      and `chelis test` passed, but a build-lane entry that reaches those
      functions failed with `unbound variable: hamt_entries`. The imports are
      now declared, so Coral carries no workaround here and needs no narrowing
      citation. The checker gap that hid it is filed as
      [chelis#1264](https://github.com/Chelis-Lang/chelis/issues/1264) with a
      three-module reproducer: `chelis check` resolves a name the module never
      imported, reporting score 1.0 and an empty `unresolved_names` list, while
      `eval` and `build` both reject the same program. Sibling of the
      chelis#850 class (a score-1.0 check that does not survive the other
      lanes), different mechanism.

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
  build/link/run. The narrowing remains. Re-probed A/B on 0.18.6: the
  `zero_i32()` helper axis is still rejected with the identical ``gather` axis
  is not a compile-time integer constant` diagnostic, and the inline control
  still builds.

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

- **`_ = f(x)` marked `x` consumed when `f` destructured a record parameter
  ([chelis#1200](https://github.com/Chelis-Lang/chelis/issues/1200); RESOLVED
  on 0.18.5 by chelis PR #1208).** A 0.18.4 regression: a `_ =` wildcard
  discard desugared with the `destructure: true` marker, opening the
  Linearity-F2 destructure-consume scope over the rest of the enclosing body,
  so any later reuse of a variable a record-destructuring callee had touched
  was a hard `UseAfterConsume` instead of receiving the implicit Copy a named
  binding gets. It took Coral from 74 passing to 17 with seven test files
  failing to compile, and was worked around by binding instead of discarding at
  84 sites. On 0.18.5 the pinned reproducer no longer fails to compile; all 84
  sites are back to `_ =`, and the reproducer is the executed regression
  `tests/linearity.ch`.

- **Invoked recursive generic Frame operations hit the HAMT boundary
  ([chelis#941](https://github.com/Chelis-Lang/chelis/issues/941), successor
  [chelis#1158](https://github.com/Chelis-Lang/chelis/issues/1158); both
  CLOSED, boundary retired on 0.18.5).** `chelis build` no longer rejects
  `hamt__from_pairs_rec`, so a real `Frame` can be constructed in the build
  lane. The remaining Frame-read limitation is a different boundary and is
  tracked above under chelis#1226 rather than here.

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
