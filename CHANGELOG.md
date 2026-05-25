# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
`docs/maintenance-schedule.md` tracking the GitHub Actions Node 20 →
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
`upstream-bugs.md`); all references updated. Em-dash fixes in
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

Known limitations carried forward (see `docs/upstream-bugs.md`):

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
