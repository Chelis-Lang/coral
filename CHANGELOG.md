# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

Prepared Coral 0.7.33 on the Chelis 0.17.3 staging candidate and Nautilus
0.7.36 candidate cascade. The compiler pin, Nautilus dependency, CI mirrors,
and managed conformance blocks move together. Local validation consumes the
exact SMT-enabled Chelis candidate and Nautilus commit `ee9a302`. Chelis
0.17.4 will replace 0.17.3 after chelis#935 is fixed; Nautilus and then Coral
must be retargeted before publication. No candidate is presented as an
official release asset.

Corrected all six `Coral.Window` public signatures to return `tensor[n, f32]`
for an input `tensor[n, f32]`. They preserve length by construction; the old
independent output dimension `m` was unconstrained. Positive compile-level
tests and a negative mismatched-extent contract now pin the preserved extent;
the runtime parity generator also emits a concrete same-extent wrapper.

The package build, 71-test evaluator suite, negative suite, documentation
checks, and strict pandas parity are green on the staging compiler. The
stripped Frame/GroupBy/Join bare-C probe is the one remaining blocked gate:
all three targets hit chelis#935 while lowering the nullary generic
`Hamt.Empty` constructor. Re-run that probe on the 0.17.4 candidate before
retargeting the pins.

Compiler-pin bump to chelis 0.16.1. `compiler = "=0.14.0"` to
`"=0.16.1"`; package version 0.7.30 to 0.7.31; CI env vars
(`CHELIS_TAG`, `CHELIS_VERSION`, `CORAL_VERSION`) updated to match.

Bare-build lane fix for a pre-existing lowering limitation: `chelis
build` (bare, single-file) rejects `gather` / `sort` axis arguments
passed through a zero-arg helper — verified identical on 0.12.1 /
0.14.0 / 0.16.1 — so `src/frame.ch` inlines `cast(0, int32)` at all 15
axis sites (12 `gather` + 3 `sort`) and drops the `zero_i32` helper
(tracked in `docs/UPSTREAM_BUGS.md` §Tracking). No behavior change;
package and test lanes were never affected.

`scripts/repro_multimodule_bare_build.py` repairs — the probe had been
dark since nautilus `stats.ch` began importing from
`Nautilus.Distributions`: the concat now pulls the transitive nautilus
modules (`special.ch`, `distributions.ch`) ahead of `stats.ch`;
zstd package tarballs fall back to the `zstd` binary on Python < 3.14;
`apply_name_map` renames whole words so pipe-position (`x |> f`) and
first-class references are prefixed (the old lookahead form silently
missed them — see the unnarrowed checker note in
`docs/UPSTREAM_BUGS.md`); `-fopenmp` is dropped when the local `gcc`
(macOS clang) rejects it. All three targets (frame / groupby / join)
build, link, and run clean on 0.16.1.

Documentation reconciliation: README Toolchain/Build, `AGENTS.md`
toolchain pin, `docs/releases.md` download examples, `docs/status.md`
typecheck pin, `SKILL.md` claims (bare builds, test lane, Parquet
re-probe), and mdBook current-gate claims (groupby, reshape, pandas
comparison) now agree on chelis 0.16.1 — they had been stale at 0.10.1
since the 0.12.0 bump. The Parquet parked entry records the 0.16.1
re-probe (still checks clean, still no runtime symbol).

The `nautilus` dependency moves 0.7.33 to 0.7.34 (its
chelis-0.16.1-pinning release, published 2026-07-16), with
`NAUTILUS_TAG` updated to match.

`chelis reef conform` adoption (closes #17): `conform sync`
re-materializes the shared skill set from the pinned toolchain
(refreshed `cli-surface`, new `issue-resolution` / `packaging-install`,
stamped in `agent-skills/UPSTREAM.toml`) and stamps the `AGENTS.md`
managed inheritance block; `AGENTS.md` gains the Pin Bump Checklist and
the track-latest Toolchain Policy wording; `docs/upstream_bugs.md` is
renamed to `docs/UPSTREAM_BUGS.md` with the canonical §Actively blocking
/ §Tracking / §Parked / §Archived sections; `docs/CHELIS_SURFACE.md` is
added (coral-scoped capability inventory, all rows `@pin` at 0.16.1);
`tests_neg/frame/` lands three check-time negative contracts with
pinned-diagnostic `.expect` sidecars, run via `chelis test tests_neg/
--expect neg` locally and in CI; `parity/` becomes a locked uv project
(`pyproject.toml` + `uv.lock`, CI runs it via `uv run --project parity
--frozen`); `docs/issue_drafts/` is established with the parked
unbound-pipe draft; CI's `pin-consistency-guard` job now installs the
toolchain and runs `chelis reef conform audit --explain` plus `chelis
reef conform bump-check --base origin/main` (fetch-depth 0) alongside
the offline bash guard. The bare-lane syntactic-axis limitation is now
filed upstream as chelis#741 and cited from its Tracking entry.
`chelis reef conform audit` exits 0 (no MUST failures) and `bump-check`
reports the 0.14.0 → 0.16.1 pin change with a green audit.

Validation under chelis 0.16.1 against the released nautilus 0.7.34:
`chelis reef build`, `chelis test tests/ --timeout 600 --jobs auto`
(70 passed, 0 failed), `parity/run_parity.py --strict`,
`scripts/run_static_checks.py`, `scripts/run_skill_checks.py` (11/11),
`scripts/validate_book_examples.py` (8/8),
`scripts/repro_multimodule_bare_build.py` (all targets), `chelis lint
--check .`, and per-file `chelis fmt --check` all pass. Note: 0.16.1
`fmt` no longer accepts directory arguments (per-file only).

## [0.7.28] - 2026-06-25

Cascade to chelis v0.10.1, nautilus v0.7.30.

## [0.7.27] - 2026-06-23

Compiler-pin alignment for chelis 0.9.0. `compiler = "=0.8.0"` to
`"=0.9.0"`; the `nautilus` dependency 0.7.27 to 0.7.28 (its
chelis-0.9.0-pinning release); `chelis-std` stays 0.4.0. CI / release
workflow env vars (`CHELIS_TAG`, `CHELIS_VERSION`, `NAUTILUS_TAG`,
`CORAL_VERSION`, `PACKAGE_VERSION`) and the `install-chelis` action's
example version strings updated to track v0.9.0 / nautilus v0.7.28 /
coral 0.7.27. Package version bumped 0.7.26 to 0.7.27. `reef.lock`
regenerated against chelis 0.9.0 (resolves nautilus 0.7.28 +
chelis-std 0.4.0, both compiler-pinned `=0.9.0`).

Documentation reconciliation: the README Toolchain and Build sections,
`AGENTS.md` toolchain pin, `docs/status.md` typecheck pin,
`docs/releases.md` download / publish / consumer-dependency examples,
mdBook current-gate claims, and `SKILL.md` examples now agree on chelis
0.9.0 / nautilus 0.7.28 / coral 0.7.27.

Parity and triage harness fix for the chelis 0.9.0 C backend: the
generated entry point for an `f32`-returning `main` is now a C `float
main__main`, so `parity/run_parity.py` and
`scripts/repro_multimodule_bare_build.py` rename `float main` (was
`double main`) and declare the driver prototype as `float`. The
bare-build triage helper also now runs `chelis fmt --inplace` on its
synthesized module before `chelis build`, since the built-in style gate
blocks unformatted input.

No Coral API surface change. Validation under chelis 0.9.0: hard-rule
guard, `chelis lint --check .`, `chelis reef build`, `chelis test
tests/ --timeout 600 --jobs auto` (70 passed, 0 failed),
`parity/run_parity.py --strict`, static checks, SKILL examples, and
mdBook examples all pass.

## [0.7.26] - 2026-06-19

Compiler-pin alignment for chelis 0.8.0. `compiler = "=0.7.27"` to
`"=0.8.0"`; the `nautilus` dependency 0.7.26 to 0.7.27 (its
chelis-0.8.0-pinning release); `chelis-std` stays 0.4.0. CI / release
workflow env vars (`CHELIS_TAG`, `CHELIS_VERSION`, `NAUTILUS_TAG`,
`CORAL_VERSION`, `PACKAGE_VERSION`) updated to track v0.8.0 / nautilus
v0.7.27 / coral 0.7.26. Package version bumped 0.7.25 to 0.7.26.

Documentation reconciliation: the README Toolchain section, `AGENTS.md`
toolchain pin, `docs/status.md` typecheck pin, `docs/releases.md`
download / publish / consumer-dependency examples, mdBook current-gate
claims, and `SKILL.md` examples now agree on chelis 0.8.0 / nautilus
0.7.27 / coral 0.7.26.

No Coral API surface change. Validation under chelis 0.8.0: hard-rule
guard, `chelis lint --check .`, `chelis reef build`, `chelis test
tests/ --timeout 600 --jobs auto` (70 passed, 0 failed),
`parity/run_parity.py --strict`, static checks, SKILL examples, and
mdBook examples all pass.

## [0.7.25] - 2026-06-17

Compiler-pin alignment for chelis 0.7.27. `compiler = "=0.7.26"` to
`"=0.7.27"`; the `nautilus` dependency 0.7.25 to 0.7.26 (its
chelis-0.7.27-pinning release); `chelis-std` stays 0.4.0. CI / release
workflow env vars (`CHELIS_TAG`, `CHELIS_VERSION`, `NAUTILUS_TAG`,
`CORAL_VERSION`, `PACKAGE_VERSION`) updated to track v0.7.27 / nautilus
v0.7.26 / coral 0.7.25. Package version bumped 0.7.24 to 0.7.25
(keeping the +2 chelis-pin cadence: coral 0.7.25 pins chelis 0.7.27).

chelis 0.7.27 is chelis 0.7.26 plus the single chelis #399
eval-demangle fix; there are no breaking changes between 0.7.26 and
0.7.27. Coral uses only the core chelis-std surface (Std.Io / Csv /
Json / Test), no `prove`, no cross-module ADT evaluation, so the #399
fix does not affect it. No Coral API surface change (70 `chelis test`
cases pass unchanged). Mechanical bump only. Part of the coordinated
chelis 0.7.27 release cascade.

Documentation reconciliation: the README Toolchain section, `AGENTS.md`
toolchain pin, `docs/status.md` typecheck pin, and `docs/releases.md`
download / publish / consumer-dependency examples now agree on chelis
0.7.27 / nautilus 0.7.26 / coral 0.7.25.

## [0.7.24] - 2026-06-16

Compiler-pin alignment for chelis 0.7.26. `compiler = "=0.7.21"` to
`"=0.7.26"`; `chelis-std` 0.3.0 to 0.4.0; the `nautilus` dependency
0.7.20 to 0.7.25 (its chelis-0.7.26-pinning release); CI / release
workflow env vars (`CHELIS_TAG`, `CHELIS_VERSION`, `NAUTILUS_TAG`,
`CORAL_VERSION`, `PACKAGE_VERSION`) updated to track v0.7.26 / nautilus
v0.7.25 / coral 0.7.24. Package version bumped 0.7.19 to 0.7.24
(keeping the +2 chelis-pin cadence: coral 0.7.24 pins chelis 0.7.26).

Source migration for chelis #317/#327 (explicit cross-module
constructor imports, landed chelis 0.7.24): referencing another
module's ADT data constructor without naming it in the importing
module is now a hard `UnknownConstructor` error. Crossing from the
0.7.21 pin to 0.7.26 crosses that boundary, so every cross-module
`import Mod (Type, ...)` now also names the constructors that file
uses. Touched `src/io.ch` (Column `IntCol`/`FloatCol`/`StringCol`/
`BoolCol`, `Std.Io.Json` `JsonString`/`JsonInt`/`JsonFloat`/`JsonBool`/
`JsonNull`), `src/join.ch` (Column + `KeyValue`
`KeyIntValue`/`KeyFloatValue`/`KeyStringValue`/`KeyBoolValue`),
`src/groupby.ch` (`IntCol`/`FloatCol`), `src/reshape.ch`
(`FloatCol`/`StringCol`), the matching `tests/*.ch` imports, and the
compile-checked `SKILL.md` + `docs/src/**/*.md` examples (incl. the
`Coral.GroupBy` `AggSum`/`AggMean` aggregation specs). Construction is
unchanged; this is an import-list expansion only. No glob/`..` form
exists and re-export does not lift the requirement, so naming is
per-importing-module.

Documentation reconciliation: the README Toolchain section
(`compiler = "=0.7.20"`, nautilus 0.7.19) and the `ci.yml`
`CORAL_VERSION` / mac-smoke `dist/coral-<v>.chb` path (0.7.18) were
stale against the prior package version; all version-stamped surfaces
(README, `AGENTS.md`, `docs/status.md`, `docs/releases.md`, both
workflows) now agree on chelis 0.7.26 / nautilus 0.7.25 / coral 0.7.24.

No Coral API surface change (70 `chelis test` cases pass unchanged).
chelis-std is compiler-bundled as of 0.7.26 (the binary embeds
chelis-std 0.4.0); the upstream ML move out of chelis-std is
transparent to Coral, which uses only the core surface (Std.Io / Csv /
Json / Test). Part of the coordinated chelis 0.7.26 release cascade.

## [0.7.19] - 2026-06-01

Compiler-pin alignment for chelis 0.7.21. `compiler = "=0.7.20"` to
`"=0.7.21"`; the `nautilus` dependency 0.7.19 to 0.7.20 (the 0.7.21-pinning
release); CI / release workflow env vars (`CHELIS_TAG`, `CHELIS_VERSION`,
`NAUTILUS_TAG`, `PACKAGE_VERSION`) updated to track v0.7.21 / nautilus
v0.7.20. Package version bumped 0.7.18 to 0.7.19. No Coral API changes
(70 `chelis test` cases pass unchanged). Part of the coordinated chelis
0.7.21 release cascade.

## [0.7.18] - 2026-05-29

Retargets Coral to chelis 0.7.20 and Nautilus 0.7.19. No Coral API
surface change; this is a toolchain/dependency alignment release for
the chelis 0.7.20 default `chelis test` batching behavior and the
matching Nautilus package release.

## [0.7.17] - 2026-05-26

Retargets Coral to chelis 0.7.19 (no source changes; bug-fix-only
toolchain bump). Chelis 0.7.19 ships six bug fixes: doc-filename-convention
lint rule path-based opt-in (#190), backend-c emits f32/f64 constants via
bit pattern instead of a lossy format string (#189), `grad` is routed
through `grad_dag_checked` and Floor/Ceil/Argmax/Argmin emit
AdError::NotSupported (#197), `chelis check` exits non-zero when errors
are present (#207), GitHub Actions bumped to Node-24-compatible versions
(#188), and runtime shape semantics documented in spec §4.7 (#208), plus
the red-team follow-up bundle that closed 4 M1/M2/L1/L2 findings from
the #207 review. Nautilus stays at v0.7.17 (its chelis 0.7.19 alignment
release has not been tagged at the time of this Coral release).

## [0.7.16] - 2026-05-25

Retargets Coral to chelis 0.7.18 + nautilus 0.7.17. Closes the chelis #237
audit by restructuring 13 owned-linear `Frame[n]` / `GroupedFrame[n]`
reuse-after-consume sites across `src/frame.ch` (head, tail, slice,
filter, with_column, concat, describe, sort_by, reindex_all),
`src/reshape.ch` (pivot, melt), `src/groupby.ch` (agg),
`src/join.ch` (assemble_outer_join, assemble_join), and the matching
`&Frame` → owned-Frame accessor signature updates in `src/io.ch` and
`src/apismoke.ch`. Public Frame[n] / GroupedFrame[n] annotations
preserved; internal helpers added (compute_sort_perm_for,
build_describe_pairs, extract_named_pair_local, etc.). Parity-golden
metadata + gen_goldens.py em-dash aligned.

## [0.7.15] - 2026-05-25

Parity-golden follow-up for the 0.7.14 AsOf release. Regenerates the
frame golden metadata under the current pandas generator so main CI and
release assets agree on the checked-in parity corpus.

## [0.7.14] - 2026-05-25

FlukeBall support release. Adds `Coral.AsOf` and wires the API smoke
surface for as-of lookup behavior used by betting and sports history
pipelines. Retargets Coral to chelis 0.7.16 and Nautilus 0.7.16 so CI,
release, and Reef metadata agree on the current upstream shell set.

## [0.7.13] — 2026-05-22

Compiler-pin bump to chelis 0.7.11, which carries a stricter linearity
analysis for tensor-carrying ADTs (per `spec/04-type-system.md` §8.4 and
`spec/design/implicit_linearity.md`). Coral's `Frame[n]` is
tensor-carrying via `Hamt[Column[n]]`, so 19 latent `UseAfterConsume`
violations surfaced on the bump. All 19 are real source bugs that the
0.7.10 checker did not flag; they are fixed in this release. Nautilus
dep bumped from 0.7.12 to 0.7.13 (matching pin-alignment release of
nautilus). Package version `0.7.12` → `0.7.13`; CI/release workflow
env vars updated for v0.7.11 / v0.7.13.

### Fixed — linearity of `Frame` across accessor calls

The root cause: read-only accessors (`nrows`, `ncols`, `columns`,
`get_column`, `get_float_col`, `get_int_col`, `get_string_col`,
`get_bool_col`, `get_int_mask`, `column_type`, `key_values`) were
declared as taking owned `Frame[n]`, which consumed the frame on every
call. Patterns like `if neq(len(mask_list), nrows(df)) then ... else
... get_column(df, name) ...` then tripped use-after-consume when the
later `get_column` (often inside a `map(fn (name) -> ..., columns(df))`
closure) saw `df` already consumed.

Fix, in three patterns:

- **Accessor signatures changed to borrow** (`&Frame[n]` parameter).
  Auto-borrow at call sites keeps the existing API for callers passing
  owned `Frame[n]`; return types unchanged. Same change applied to
  `Coral.Io` rendering helpers (`render_csv`, `render_json`, `csv_rows`,
  `csv_row`, `json_rows_out`, `json_row`, `row_count`, `write_csv_frame`,
  `write_json_frame`) and to `Coral.Reshape.melt_one_col`,
  `melt_var_val_cols`, `melt_build_id_cols`.
- **Closure-capture fan-out replaced with recursive helpers.** Where a
  function had two `map(fn (...) -> ... df ..., ...)` calls both
  capturing `df` (closure capture is a non-fan-out consume and is not
  auto-copied), the second is rewritten as a recursive helper taking
  `df: &Frame[n]`. Applies to `Coral.Frame.describe`
  (`numeric_column_names`), `Coral.Frame.concat` (`concat_build_pairs`),
  and the two join assemblers in `Coral.Join` (`build_outer_left_cols`,
  `build_outer_right_cols`, `build_join_left_cols`).
- **`GroupedFrame` accessor signatures changed to borrow.**
  `Coral.GroupBy.{agg_sum, agg_mean, agg_count, agg_min, agg_max}` now
  take `gf: &GroupedFrame[n]`. `Coral.GroupBy.agg` extracts its initial
  base via a new `initial_agg_base(gf: &GroupedFrame[n])` helper so the
  match-on-`gf` does not consume the scrutinee before the recursive
  `apply_specs(_, gf, _)` tail call.

Behavior preserved end-to-end: `chelis test tests/ --jobs auto` →
65 passed, 0 failed under chelis 0.7.11. `chelis check src/*.ch` →
score 1, errors []. No public surface change beyond `&Frame[n]` /
`&GroupedFrame[n]` borrow signatures, which are call-site backward
compatible (owned `Frame[n]` auto-borrows).

## [0.7.12] — 2026-05-22

nautilus dep bump to 0.7.12, which carries the WS-A warning-regression
close-out and the WS-B structural plateau-stop hardening for
`Nautilus.CurveFit`, `Nautilus.Ode`, and `Nautilus.Integrate` (aligned
with the `Nautilus.Roots` discipline shipped in 0.7.11). No coral
source changes. No compiler-pin change (still `=0.7.10`). Also adds
`docs/maintenance_schedule.md` tracking the GitHub Actions Node 20 →
Node 24 migration deadline (2026-06-02); no CI changes this release.

Verified under chelis 0.7.10 / nautilus 0.7.12: `chelis reef build`
clean; `chelis test tests/ --jobs auto` → 65 passed, 0 failed;
`chelis lint --check .` → 0 errors, 0 warnings.

## [0.7.11] — 2026-05-22

nautilus dep bump to 0.7.11, which carries the `Nautilus.Roots`
f32-plateau hardening missed in nautilus 0.7.10. No coral source
changes; no compiler-pin change (still `=0.7.10`). 65/65 tests, 0
lint warnings/errors.

This is the second wave of a two-release f32-plateau hardening
sequence upstream. nautilus 0.7.10 hardened `Nautilus.Optim` and
`Nautilus.Special` against unit-roundoff stalls that chelis 0.7.10's
f32-preserving evaluator exposed (golden-section / Brent / Newton
plateau-stops in `optim.ch`; elliptic AGM plateau-stops in
`special.ch`); `Nautilus.Roots` was left unhardened in that wave
and shipped with the same latent NaN-on-sub-ULP-tolerance bug.
nautilus 0.7.11 applies the structurally-identical fix to
`bisection_rec` / `newton_rec` / `brent_rec`, completing the
pattern. coral itself never tripped either failure mode, but the
dep bump tracks the corrected nautilus release so downstream
consumers see a single coral version line aligned with the
post-hardening nautilus.

## [0.7.10] — 2026-05-15

Compiler-pin alignment for chelis 0.7.10 (skipping the 0.7.9 pin at
the consumer level — chelis 0.7.9 shipped a `chelis test` lowering
blocker that 0.7.10 fixed). `compiler = "=0.7.8"` → `"=0.7.10"`,
nautilus dep `0.7.9` → `0.7.10` (the matching pin-alignment release),
package version `0.7.9` → `0.7.10`, CI/release workflow env vars
updated to track v0.7.10.

No source changes. coral builds clean under chelis 0.7.10 — none of
its multi-dim functions tripped chelis 0.7.9's `check_declared_dvars_rigid`
(dims stay independent: input vs output row counts, left vs right
frame sizes), and no linearity violations surfaced. `chelis test
tests/` passes 65/65; `chelis lint --check .` reports 0 warnings,
0 errors.

### Changed — doc renames

Three `docs/` files renamed from SCREAMING_SNAKE_CASE to kebab-case
to satisfy `doc-filename-convention §8.5` (`RELEASES.md` →
`releases.md`, `STATUS.md` → `status.md`, `UPSTREAM_BUGS.md` →
`upstream_bugs.md`); all references updated. Em-dash fixes in
`parity/gen_goldens.py` and `parity/run_parity.py` for
`no-em-dash-in-public-strings §8.6`.

## [0.7.9] — 2026-05-13

Compiler-pin alignment release for chelis 0.7.8. No source changes
from 0.7.8 — only the `compiler = "=0.7.7"` → `"=0.7.8"` pin bump,
nautilus dep bump to 0.7.9 (the matching pin-alignment release of
nautilus), package version bump to 0.7.9, and CI/release workflow
env updates. Required because chelis 0.7.8's reef validator rejects
any package whose `package.compiler` is not exactly `=0.7.8`. All
65 native tests + 12 red-team probes re-verified under 0.7.8 with
zero source changes.

## [0.7.8] — 2026-05-13

Lint-cleanup pass that pays down the 105 advisory warnings deferred
from 0.7.7, plus correctness fixes for several latent NaN/empty/CSV
bugs surfaced by an adversarial red-team pass. No compiler pin
change (chelis 0.7.7 / nautilus 0.7.7 unchanged).

Lint:

- `chelis lint --check src/` and `chelis lint --check tests/` are
  now both 0 warnings under chelis 0.7.7. Previous state: 105 src/
  warnings (48 `prefer-pipe-operator`, 57 `redundant-linearity-call`)
  + 18 tests/ warnings. Mix of `chelis lint --fix` auto-rewrites,
  let-binding the nested first-arg of `f(g(x), …)` calls, and
  hand-stripping `copy()` / `_ = drop(x)` lines per the
  `implicit-linearity` migration.
- Three pipe-chain auto-fixes in `src/internal/hamt.ch`
  (`hamt_size` / `add` / `sub` patterns) had to be reverted from
  `lhs |> f |> rhs |> g |> binop` form back to nested-call form;
  the lint auto-fix chained both args of the outer binop into the
  pipe and produced semantically wrong code (calling a value as if
  it were a function).
- AGENTS.md / CLAUDE.md toolchain-pin section corrected from
  "chelis v0.7.6" (stale since 0.7.7 release) to "chelis v0.7.7".

Correctness fixes (red-team surfaced; all pre-existing latent bugs):

- `drop_nan` no longer crashes. Was calling `not(tensor[n, bool])`
  which chelis 0.7.7's scalar-only `not` rejects. Now constructs
  the keep-mask directly via `bool_list_to_tensor(map(fn x -> eq(x, x), …))`.
- `filter` / `head` / `tail` / `slice` no longer crash on zero-row
  output. Root cause: `numel(to_tensor([]))` returns 1 in chelis
  0.7.7, breaking the `gather`-based reindex when the index list
  is empty. Added an `empty_column_like` helper and short-circuit
  for empty-result paths. Same fix transitively repairs inner-join
  with disjoint keys.
- `column_len` / `row_count` now route through `len(to_list(xs))`
  instead of `numel(xs)` so empty numeric columns report length 0.
  Workaround for the chelis-0.7.7 `numel` bug; restore once
  upstream fixes it.
- `rolling_min` / `rolling_max` now propagate NaN through any
  window containing a NaN. Previously `lt(NaN, acc)` and
  `gt(NaN, acc)` returned false under IEEE rules, so non-head NaNs
  were silently swallowed.
- CSV writer is now RFC-4180 compliant: string fields containing
  comma, double-quote, or newline are wrapped in quotes with any
  internal quotes doubled. CSV round-trip of strings like
  `"with,comma"` now preserves the value.
- JSON `null` no longer silently downgrades int/float columns to
  StringCol. `infer_csv_column` now recognises `""` as a missing
  cell when the rest of the column is int-or-null (→ IntCol with
  mask) or float-or-null (→ FloatCol with NaN at null positions).

Known limitations carried forward (see `docs/upstream_bugs.md`):

- `is_nan` is currently O(n) host-path: chelis 0.7.7's overload
  resolution of `neq(&tensor, &tensor)` does not return a bool
  tensor, so the tensor-native NaN-mask path the spec promises
  ("filter → mutate → aggregate compiles to a single fused
  kernel") is unavailable. Restore once upstream `neq` returns
  `tensor[n, bool]` for ref/ref pairs.
- HAMT at 100 keys exceeds the default 30s `chelis test` budget
  under chelis 0.7.7's native evaluator. Cost is per-call evaluator
  overhead, not algorithmic. Unaffected by the C-build path.
  Documented design range is 50–100 columns.

Validation: `chelis lint --check src/` and `chelis lint --check tests/`
report 0 warnings, exit 0. `chelis test tests/` passes 65/65. Twelve
red-team probes covering NaN / HAMT / sort_by / filter-slice / concat /
groupby / IO / window / join / reshape / with_column / empty-frame /
JSON also pass under `chelis test`.

## [0.7.7] — 2026-05-12

Compiler-pin alignment release for chelis 0.7.7. Bumps package
version and `compiler = "=0.7.6"` → `"=0.7.7"`, updates the nautilus
dep to 0.7.7, and updates CI/release workflow env vars (CHELIS_TAG,
CHELIS_VERSION, NAUTILUS_TAG, CORAL_VERSION, PACKAGE_VERSION) so the
release workflow downloads chelis 0.7.7 and produces coral-0.7.7
assets. Required because chelis 0.7.7's reef validator rejects any
package whose `package.compiler` is not exactly `=0.7.7`.

No source changes. `chelis lint --check src/` produces 105 advisory
warnings (all `redundant-linearity-call` and `prefer-pipe-operator`,
deferred to a separate cleanup pass) and zero error-severity findings
under 0.7.7. `chelis test tests/` passes 65/65.

## [0.7.6] — 2026-05-11

Compiler and dependency alignment release. Tracks chelis 0.7.6 and
nautilus 0.7.6, consumes released Chelis binaries in CI, and cuts the
native Chelis test lane over from per-file matrix sharding to
`chelis test tests/ --jobs auto`.

Validation recorded in `docs/testing_cutover_0.7.6.json`:

- `chelis test tests/ --jobs auto`: 65 passed, 0 failed, 0:34.06
- `chelis test tests/ --jobs 1`: 65 passed, 0 failed, 0:38.72

## [0.6.1] — 2026-05-06

Compiler-pin alignment release. Tracks chelis 0.6.0 → 0.6.1
(bootstrap-list patch) and nautilus 0.6.0 → 0.6.1 (companion
alignment). No source changes from 0.6.0 — only version + pin
bumps to align with chelis 0.6.1.

## [0.6.0] — 2026-05-06

Naming-convention release. Aligns coral with the recorded style
guide in `chelis/spec/01-nomenclature.md`. Track-forward for chelis
0.6.0 / chelis-std 0.2.0 / nautilus 0.6.0.

### Changed (breaking) — `Coral.Frame` `_int → _col` family per §7.2

Five paired NaN-handling functions renamed:

| Old              | New              |
|------------------|------------------|
| `is_nan_int`     | `is_nan_col`     |
| `any_nan_int`    | `any_nan_col`    |
| `count_nan_int`  | `count_nan_col`  |
| `fill_nan_int`   | `fill_nan_col`   |
| `drop_nan_int`   | `drop_nan_col`   |

The `_int` suffix in the old names was misleading: it didn't
describe the element type of the principal argument (which is a
`Frame`, not int data) — it meant "Frame-form variant accepting an
int column name." The §7.2 type-suffix policy reserves element-type
suffixes for monomorphizing element types; container-form
distinction goes through a distinct verb instead. The `_col` suffix
unambiguously names "column-form variant of the same operation,"
with column dtype inferred when the column is fetched.

### Changed (breaking) — module renames per §6.2

| Old                       | New                       |
|---------------------------|---------------------------|
| `Coral.Internal.HAMT`     | `Coral.Internal.Hamt`     |
| `Coral.IO`                | `Coral.Io`                |
| `Coral.Tests.IO`          | `Coral.Tests.Io`          |

Per §6.2 (Title-case compounds, never ALL-CAPS abbreviations).
Within-pair alignment: `Coral.Internal.Hamt` exports the `Hamt`
type constructor, matching the new module name.

### Changed — `Std.IO` → `Std.Io` import-side updates

Coral source modules now import `Std.Io` (and `Std.Io.Csv`,
`Std.Io.Json`) instead of `Std.IO`. Track-forward for the chelis-std
0.2.0 rename.

### Changed — compiler pin bumped to `=0.6.0`

`reef.toml` now requires:
- chelis-std 0.2.0 (was 0.1.0)
- nautilus 0.6.0 (was 0.5.0)
- compiler =0.6.0 (was =0.5.0)

Downstream consumers (e.g., shoals) must bump their pins to match.

### Style guide

Adheres to `chelis/spec/01-nomenclature.md`. Local `STYLE.md` is a
one-line pointer at the central guide. Coral.Frame's data-domain
prefixes (`agg_/list_/key_/hash_/enum_/char_/ints_/melt_/csv_/json_/
left_/join_/...`) are recognized as common-verb idioms by the
chelis-lint allowlist.
