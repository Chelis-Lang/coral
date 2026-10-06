# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- `write_json_frame` serializes every object key and every cell value with
  `Std.Io.Json.to_json` instead of interpolating them into hand-assembled
  text, so quotes, backslashes and control characters are escaped by the
  stdlib's rules ([coral#55](https://github.com/Chelis-Lang/coral/issues/55)).
  A cell or column name containing a quote, a newline or a tab used to produce
  a document no JSON parser accepts, and the writer reported success. The
  backslash case was worse and silent: the three characters `a`, `\`, `b` were
  written as `"a\b"`, which is *valid* JSON in which `\b` is the backspace
  escape, so `read_json_frame` returned `a` on Coral's own output with both
  calls reporting success.
- `Coral.Io.json_cell` now returns `Json` rather than rendered text, and
  `json_float_cell` becomes `json_float_value`. The CSV writer's
  `column_value_string` still returns `string`, so substituting one cell
  helper for the other is a type error rather than a silent change of output
  in the other format.

Object keys keep the frame's column order, which `read_json_frame` preserves.
Only the object and array framing is assembled by Coral: `to_json` on a whole
`JsonObject` emits keys in Unicode scalar-key order, so a whole-document tree
build would make write-then-read permute a frame's columns. Finite float cells
keep the exact spelling they had before: a cell's f32 text is paired with the
f64 that text parses to, because an f32's shortest text is not the widened
f64's shortest text and the widened pairing would rewrite `0.1` as
`0.10000000149011612`.

## [0.7.46] - 2026-10-06

- Pin published Chelis 0.19.0, Nautilus 0.7.49, and shell format 7. The 21
  pipe-grouping sites in `Coral.AsOf` and `Coral.Internal.Hamt` use explicit
  parentheses; the pinned pipe migrator proved unchanged expanded Deep for all
  29 source and test files.
- Refresh the public scope, limitations, and compiler surface inventory. Remove
  inactive issue drafts and the resolved upstream-bug archive.

### Fixed

- `write_json_frame` renders a non-finite float cell as the JSON `null`
  literal instead of emitting a bare `NaN`, `inf` or `-inf` token, which no
  conforming JSON parser accepts. The writer used to report success and
  produce a document that `read_json_frame` itself could not load; a CSV
  file with a blank numeric cell reached this path without any user error,
  because missing floats are stored as `NaN`. `null` matches pandas
  `to_json`, and reads back as a missing float cell when the column holds
  at least one finite value; a column whose every cell is non-finite reads
  back as a string column, where the pre-fix document could not be read at
  all. It does not distinguish `NaN` from the infinities. Both
  `docs/src/io.md` and the limitations appendix now state the encoding and
  both losses. Finite floats, including signed zero, keep their numeric
  spelling, and CSV output is unchanged and pinned by a test (coral#51).

## [0.7.45] - 2026-10-05

- Advance the compiler pin to published Chelis 0.18.13 and prepare the
  Nautilus 0.7.48 dependency cascade. Refresh inherited Chelis guidance,
  skills, and the capability inventory with `reef conform sync`.
- Update native probes and the Window parity gate for `chelis build` compiling
  its own executable. Convert six Frame probes formerly blocked by
  chelis#3153 to native/evaluator comparisons. Pin the stripped Frame,
  GroupBy, Join, and `drop_nan` probes to chelis#2097's current
  ownership-signature rejection; `describe` and `drop_column` retain their
  separate native limitations.
- Match the two-field `JsonFloat(f64, string)` constructor and use its original
  token text when reading JSON cells, preserving decimal and exponent spelling
  in mixed columns.
- Keep `gather`'s literal-axis rule under `[05-AXIS-2]` as a checking
  rejection, move its probe into the negative suite, archive chelis#741,
  and retain computed-axis coverage for `sort`.
- Rename the maintainer guide to satisfy the 0.18.13 document filename rule.
- Describe the Parquet limitation as an explicit runtime stub: the standalone
  `Std.Io.Parquet` call checks and builds but fails when run; a bare signature
  without a definition now rejects at checking.

## [0.7.44] - 2026-10-01

Public-release cleanup. No change to any public function's behavior.

- Pin Coral 0.7.44 to the published Chelis 0.18.12 compiler and Nautilus
  0.7.47 package. A native `Frame` column read through `nrows` now builds,
  links, runs, and agrees with evaluation; the same is true for a match on
  a retrieved column. The named axis helper now works for `sort` and
  replaces three inline sort axes. Invoked `drop_nan` and stripped
  full-module builds remain blocked by chelis#730; the gather-axis helper
  still fails as expected under chelis#741.

- Add a pinned, redacted secret scan for pull requests and branch pushes, with a manual full-history scan.

- Documentation now describes the current pin instead of carrying
  per-version receipts. Removed the per-version migration notes
  (`docs/chelis_0_18_{9,10,11}_migration.md`), `docs/status.md`,
  `docs/maintenance_schedule.md`, `docs/testing_cutover_0.7.6.json`, and the
  unused `deps/chelis-std-0.2.0.tar.zst`. History stays in this file, pull
  requests, and git.
- `spec/phase3k.md`, a copy of the monorepo's Phase 3k plan that had drifted
  from both the monorepo and the implementation, is replaced by
  `spec/scope.md`: intent, architecture as built, departures from the plan,
  acceptance rules, known limitations, and dated deferrals D1-D9. Narrowing
  sites in `src/` cite their deferral or upstream issue.
- Rewrote `README.md`, `AGENTS.md`, `SKILL.md` §4-5, `docs/UPSTREAM_BUGS.md`,
  `docs/CHELIS_SURFACE.md`, `docs/releases.md`, and the book's installation,
  GroupBy, Join, IO, Window, Reshape, and appendix pages. Corrected claims
  that no longer held: that stripped native builds are clean (chelis#2097
  blocks them), that `Coral.Frame` has an executed pandas parity lane (only
  Window's `rolling_mean` and `ewm` do), and that `is_nan` uses a scalar
  host-map. Added `CONTRIBUTING.md`.
- Re-probed every upstream entry on 0.18.11. Archived chelis#849 (fixed; its
  blocked probe had drifted onto the intended one-expression-block rule) and
  chelis#405 (scalar `grad` builds natively). chelis#741 now fails in the
  evaluator as well as `chelis build` and has a mechanical blocked probe,
  `tests_blocked/lowering/gather_axis_helper.ch`. Re-measured chelis#828: a
  100-column frame plus one `with_column` takes about 164 s in `chelis test`.
- Retired the parked issue draft for unbound `|>` pipe targets without filing
  it: its original reproducer is correctly rejected on 0.18.11.
- `scripts/repro_multimodule_bare_build.py` is now an expected-failure probe
  for chelis#2097 and reports FIX-DETECTED when the smokes build again.
- Added native tests for multi-aggregation `agg` against the
  `agg_multi_city` golden and an int-key configuration. Filed coral#37 (a
  repeated value column fails) and coral#38 (`AggCount` rejects string and
  bool columns).
- CI actions move to their Node 24 majors: `actions/checkout@v6`,
  `actions/cache@v5`, `softprops/action-gh-release@v3`.

## [0.7.43] - 2026-09-22

- Prepare Coral 0.7.43 for Chelis 0.18.11 and published Nautilus 0.7.46,
  including canonical integer dtype spelling and refreshed conformance artifacts.
  Validation and native-C limits are recorded in the release pull request
  (#36).
- Use direct tensor inequality for float NaN masks after the official compiler
  passes the evaluator/native IEEE probe; retain positive native regressions.
- Migrate generated parity/probe programs and executable documentation, align
  the CI package version, and use lint-conforming migration-note filenames.
- Declare the missing dimension binder on the internal join `append_named`
  helper, preserving its existing row-dimension relationship.

## [0.7.42] - 2026-09-15

Compiler-pin and dependency repin change set for Chelis v0.18.10, the
2026-09-15 dependency wave consumed by C Note. `chelis reef conform bump
0.18.10` advances the compiler pin `=0.18.9` -> `=0.18.10` in `reef.toml`, both
workflow pin mirrors, and the managed blocks in `AGENTS.md` and
`docs/CHELIS_SURFACE.md`. The Coral package version advances from 0.7.41 to
0.7.42.

**The Nautilus cascade advances 0.7.44 -> 0.7.45.** Reef enforces exact
compiler-pin equality on dependencies, so the previous release (declaring
`=0.18.9`) is refused at coral's `=0.18.10` pin. CI installs the dependency with
`chelis reef install --from-github Chelis-Lang/nautilus@v0.7.45`. Both Chelis
v0.18.10 and Nautilus v0.7.45 are published, and the regenerated local
`reef.lock` binds `nautilus` and `chelis-std 0.4.0` to compiler `=0.18.10`.

**chelis#2068 (native-C airy ownership) is confirmed FIXED on 0.18.10.** 0.18.7
introduced a native-C ownership/liveness regression where a by-value owned
scalar passed to two or more argument slots of a user call in tail position was
wrongly moved; Nautilus's `special.ch::airy_gg` and `distributions.ch::betacf`
hit it. The issue's own minimal repro (`def g(x) = f3(x, x)`) now builds cleanly
on 0.18.10 (`chelis build --target c`, rc=0) where it failed on 0.18.9 with
`error: owner %1 in `g` b1 is not live`. Nautilus 0.7.45's whole-package
`chelis reef build` and sealed-artifact contract are green on 0.18.10, which
exercises `airy_gg` through the real build.

**The full multi-module native-NaN probe is NOT restored; it is blocked by a
separate gap, chelis#2097.** Restoring `scripts/repro_native_nan.py` to its full
`MODULE_PRESETS["frame"]` form (hamt + Nautilus special/distributions/stats +
frame) was attempted now that #2068 is fixed, but the full paste does not
compile — not because of #2068, but because it surfaces a separate, pre-existing
native-C completeness gap in Coral's own `frame.ch`: `error: direct call in
`frame__list_filter_string` does not match ownership signature of u226`.
`list_filter_string` threads a function-value parameter (`pred: string -> bool`)
through a direct call, which the native-C ownership pass rejects. This is filed
as [chelis#2097](https://github.com/Chelis-Lang/chelis/issues/2097). It is
**latent since <= 0.18.6 and fails identically on 0.18.9 and 0.18.10 — not a
0.18.10 regression** (#2068 previously shadowed it), and is the same diagnostic
class as the closed chelis#1732 for the function-value-passing variant that
#1732 did not cover. Coral therefore keeps its native-NaN canary **scoped to its
own first-order frame-NaN defs** (`zero_i64`, `one_i64`, `is_nan`, `any_nan`,
`count_nan`, `mask_to_index_list`) exactly as in 0.7.41 — the code chelis#630
narrows. The narrowed probe compiles, links, runs, and asserts the IEEE-correct
NaN observation on 0.18.10. Coral never calls `list_filter_string` through
native-C in any shipping lane.

**Validation status.** Locked against the published toolchain. On the published
Chelis 0.18.10 Darwin arm64 binary with Nautilus 0.7.45, the native suite and
`fmt --check`, `lint --check .`, `reef build`, the negative and blocked-probe
suites, the strict pandas parity gate, `run_static_checks.py`,
`run_skill_checks.py`, `validate_book_examples.py`, the narrowed `native float
NaN regression` probe, `reef conform audit`, and `reef conform bump-check
--base origin/main` are clean. Published hashes and the gate receipt are
recorded in `docs/chelis_0_18_10_migration.md`. chelis#2068 is recorded as
fixed and chelis#2097 as the new native-C function-value ownership gap in
`docs/UPSTREAM_BUGS.md`.

## [0.7.41] - 2026-09-14

Compiler-pin and package-boundary change set for Chelis v0.18.9, the
2026-09-14 dependency wave consumed by C Note. The compiler pin advances
`=0.18.6` -> `=0.18.9` in `reef.toml`, both workflow pin mirrors, and the
managed blocks in `AGENTS.md` and `docs/CHELIS_SURFACE.md`; the four
`agent-skills/*/SKILL.md` files were resynced verbatim from the Chelis
monorepo and are byte-identical to its `release/0.18.9-nn-cascade` branch.
The Coral package version advances from 0.7.40 to 0.7.41. Chelis 0.18.7 and
0.18.8 are skipped: 0.18.7 was published but its full native suite did not
complete, and 0.18.8 was never published, so 0.18.9 is the first release this
shell validates end to end.

**The Nautilus cascade advances 0.7.43 -> 0.7.44.** Reef enforces exact
compiler-pin equality on dependencies, so the previous release (declaring
`=0.18.6`) is refused at coral's `=0.18.9` pin. CI installs the dependency
with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.44`. Both
Chelis v0.18.9 and Nautilus v0.7.44 are now published, and the regenerated
local `reef.lock` binds `nautilus` and `chelis-std 0.4.0` to compiler
`=0.18.9`.

**Explicit package boundaries (coral#32).** 0.18.9 enforces in-package
exports, which exposed two cross-module dependencies that previously resolved
implicitly: `Coral.Frame` uses `Coral.Internal.Hamt.char_code`, and
`Coral.Reshape` uses `Coral.Frame.column_len`. The owning modules now export
those helpers and the consumers import them explicitly. `tests/column_length.ch`
adds populated and empty column-length cases for all four `Column` variants
(float, integer, string, boolean), and
`tests_neg/frame/column_length_scalar_neg.ch` retains scalar rejection.

**Threshold fixture (coral#33).** Tensor comparison operands must have
matching shapes under spec [05-OP-36], so the threshold-filter test builds its
mask by mapping an explicit elementwise predicate over the column and
converting the boolean list to a tensor. The fixture's oracle is unchanged:
the same three rows are selected and their sum is 600.
`tests_neg/frame/tensor_scalar_gt_neg.ch` pins the direct `gt(tensor, scalar)`
rejection, and `SKILL.md` / `docs/status.md` describe the current rule instead
of the historical v0.3.1 broadcast behavior.

**Validation status.** Locked against the published toolchain. On the
published Chelis 0.18.9 Darwin arm64 binary with Nautilus 0.7.44, the native
suite passes 80 of 80 tests in 50.16 s, and `fmt --check`, `lint --check .`,
`reef build`, the negative and blocked-probe suites, the strict pandas parity
gate, `run_static_checks.py`, `run_skill_checks.py` (11 of 11),
`validate_book_examples.py` (8 of 8), `reef conform audit`, and
`reef conform bump-check --base origin/main` are all clean. The
`tests_blocked/parser/if_else_newline.ch` probe stays blocked with its
diagnostic re-cited for 0.18.9, and the `Coral.Frame.concat` book example now
stacks two equal-length frames to satisfy 0.18.9's type-level row-count
tracking. Published hashes and the sonar gate receipt are recorded in
`docs/chelis_0_18_9_migration.md`. The non-shipping native bare-build
multimodule probe hits a Nautilus `special__airy_gg` native-lowering error
under 0.18.9 (the C-backend liveness regression chelis#2068); it is not a
shipping lane and is not a CI gate. The required `native float NaN regression`
CI step (`scripts/repro_native_nan.py`) was narrowed to natively compile only
Coral's own frame NaN path so it no longer drags airy/betacf through the C
backend; the chelis#630 guard is unchanged. See `docs/UPSTREAM_BUGS.md`.

## [0.7.40] - 2026-08-29

Compiler-pin, stdlib-migration, and de-narrowing change set for Chelis
v0.18.6. `chelis reef conform bump 0.18.6` advanced the compiler pin, both
workflow audit mirrors, and the managed blocks in `AGENTS.md`,
`docs/CHELIS_SURFACE.md`, and `agent-skills/`; the Coral package version
advanced from 0.7.39 to 0.7.40. Unlike the last two bumps this one required
real source edits: 0.18.6 is the largest breaking cut since 0.18.0.

**The Nautilus cascade has cleared.** Reef enforces exact compiler-pin
equality, so `chelis reef build` refused the last published Nautilus (0.7.42,
declaring `=0.18.5`) at coral's `=0.18.6` pin for most of this bump. The
dependency advances 0.7.42 -> **0.7.43**, which is now published at source
commit `7e3451b4977922d0bda80883ba385c7da211fc9e`. Its release assets were
verified against the sidecar -- CHB SHA-256
`c3e6fb6e2c3a397726df0cc53587d854ac48cab416c9dea80c9df717bfe0ef4d`, archive
SHA-256 `970fb4ff51e6dfdce3043bb6ad772a7df74fd4c05a0be2723d451b35ef7ddd05` --
and every gate below ran against those exact published bytes, installed with
`chelis reef install --from-github Chelis-Lang/nautilus@v0.7.43` into the
default registry, with no `CHELIS_REEF_HOME` override in play. The resulting
Coral artifacts are
CHB SHA-256
`672297eb6bafcffb8f3c4ad867f59aecece8cf114747fbfe2a112f3346edc2f1` and
archive SHA-256
`a6416fa595b092b34f1d5483429f65b4e19927db833288a18919d5b497ecc08f`. Both are
byte-identical to the published `v0.7.40` release assets and verify against
that release's sidecar, so this gate ran on the bytes the release ships.

An earlier round of the same gate ran against a locally built Nautilus
artifact from that shell's bump branch head (CHB
`99cfc7e0700cdf7f884a71a2752e8916fe3255836b92c698eb9fe26513e27cb3`, archive
`884f582328667a1617ad7b7aa371d96b6f99279e7e4c20700591dfde4d9fa306`). Those
values are superseded and describe a different package: the published release
descends from a commit that also carries Nautilus PR 49, adding 117 lines
across 20 `src/` modules the local build lacked. Coral's results are identical
on both.

The official chelis Darwin arm64 asset was verified at SHA-256
`08580435570c6fd44716f4d5c64117e973e379808cefeaaa97c8faefa2588f6c`
(installed payload `1c88c737d7d3740eb4adbe7b50ea31d29ee64498b9d74b35664255ca16aea8d4`,
byte-identical to the release tarball; upstream source commit
`cf49f85bf0d1bca2c87c88a3e459c446912189c0`). The whole gate below was re-run
end to end on the installed toolchain after v0.18.6 published. The
private-registry Nautilus 0.7.43 artifact reproduced byte-identical CHB and
archive hashes across three independent builds -- the pre-release local
compiler, the published archive, and the installed toolchain.

**`conform audit` on `origin/main` at the 0.18.6 conform version fails
independently of this bump**, measured in a throwaway worktree at
`8da830d`: `vendored-skills (§8)` FAILs there with `redteam-exec:
forked/stale` and `upstream-bugs (§4)` reports MANUAL. This change set turns
both green -- the bump's own restamp re-materializes the skill, and the
`docs/UPSTREAM_BUGS.md` §Actively blocking restructure below makes the §4
citation rule machine-checkable. `staleness-audit (§4)` PASSes in both
states: chelis#1270 widened the §4 grammar so a sibling `<repo>#NNN` also
counts as a citation owing coverage, and Coral's only such reference is
`coral#26` inside a Tracking entry that already owns two live probes.

**The removed `Std.Test` assertion aliases forced a suite-wide migration.**
0.18.6 deletes `assert_eq_int`, `assert_eq_bool`, and `assert_eq_string` and
makes `assert_eq[q]` generic, with no alias to fall back on; every one of the
eight `tests/*.ch` files failed to compile at the new pin. All **119** call
sites and the eight import lists now use `assert_eq`. `assert_close` also
acquired the `[p_float]` active-float restriction, which Coral's f32-only
tolerances already satisfy.

**`JsonBigInt` was silently emptying out-of-`int64` JSON cells.**
0.18.6 adds `JsonBigInt(string)` to the `Json` ADT (chelis#1314), so an
integer token outside `int64` range now parses -- carrying its exact decimal
spelling -- where it previously trapped `Overflow`. `Coral.Io`'s
`render_json_value` ended in a `| _ => ""` wildcard, so those cells silently
became empty strings and their whole column re-inferred as text or NaN. The
match now enumerates all eight variants explicitly, with `JsonBigInt(digits)
=> digits`: the exact digits reach column inference, the same value ingests
identically through the JSON and CSV paths, and adding a ninth variant
upstream is a compile error here instead of another silent cell.
`tests/io.ch` pins both the exact-digit passthrough and the numeric-column
inference; both fail against the previous wildcard.

**chelis#630's typing residue is fixed and de-narrowed.**
`neq(&tensor[n, f32], &tensor[n, f32])` now infers `tensor[n, bool]`, so
`tests_blocked/types/tensor_neq_borrowed.ch` stopped failing and is promoted,
per its own `.expect` instruction, to the executed regression
`tests/types.ch`. The **native** IEEE residue is unchanged -- compiled C still
reports the NaN lane equal because it derives `neq` from two ordered `<`
comparisons -- so `Coral.Frame.is_nan` keeps its scalar host-map. That
narrowing would otherwise have been left with no live trigger, so the new
`scripts/repro_native_neq_blocked.py` takes over the blocked half: it compares
the two lanes on one source (eval `1`, native `0`) and reports FIX-DETECTED
when they agree. It is a script rather than a `tests_blocked/` entry because
the residue is a wrong runtime answer, not a rejected program.

**Four native-lane probe harnesses had to change shape.** chelis#1079/#1082/
#1083 make `chelis build` emit its own `int main(void)` that evaluates every
effect-free nullary definition and prints one `<name> = <value>` observation
line. The old technique -- rename the entry symbol, supply a driver `main`,
read the exit code -- now collides with that emitted `main`
(`duplicate symbol '_main'`) or leaves the renamed symbol undeclared
(`call to undeclared function 'main__main'`). This is a harness
incompatibility, not a Coral source defect: the generated C is valid and the
same programs build, link, and run. `scripts/repro_multimodule_bare_build.py`
now owns three shared helpers (`emitted_compile_cmd`, `compiled_binary_path`,
`observed_root`) and `scripts/repro_native_nan.py`,
`scripts/repro_package_frame_build.py`, and `parity/run_parity.py`'s
window-runtime lane consume them. Each probe runs the compile command
`chelis build` itself prints -- which also supplies the platform vector-math
library the emitted `main` newly pulls in through Nautilus's tensor
specializations -- and reads the entry's observation line, the same line shape
`chelis eval` prints. The emitted entry always exits zero, so an exit-code
verdict is no longer available.

**Re-probed and unchanged:** chelis#849 (block `if`/`else` newline) still
compile-fails with the pinned diagnostic; chelis#741 stays narrowed, with the
`zero_i32()` helper axis still rejected A/B against a building inline
`cast(0, int32)` control; the chelis#1226 Frame-read boundary is unchanged in
both the package and bare lanes. The 0.18.6 breaking surfaces that do **not**
reach this corpus were checked directly rather than inferred from a green
suite: Coral calls no `diagonal`/`trace` (the chelis#1349 out-of-bounds fix),
no `assert_close_tensor` or `assert_eq_tensor`, no `init/xavier::sample`, no
prelude JSON or legacy JSON builtin aliases; it does not target HIP or Metal,
does not link the C ABI directly, and does not speak WireDag. The new `count`
reduction does not collide with Coral's `count` parameters, bindings, or
column names.

**Validation on 0.18.6:** conform audit conformant, no MUST failures (15
PASS, 2 MANUAL, 1 NA); `chelis reef build` produces `coral-0.7.40.chb` and
`.tar.zst`; **78 passed, 0 failed** (75 baseline plus two `JsonBigInt`
regressions and the promoted typing regression); 4 negative sidecars ok; 1
blocked probe ok; per-file `chelis fmt --check` clean over all 25 files in
`src`, `tests`, and `tests_neg`; `chelis lint --check .` exits 0 with no
blocking issues; all three bare-build targets, the native NaN regression, the
native `neq` blocker probe, both package-frame targets, and the bare
`drop_nan` blocker probe behave as documented; the strict pandas parity gate,
static checks, the parity generator contract, the release-workflow contract,
11/11 SKILL examples, and 8/8 mdBook examples all pass.

## [0.7.39] - 2026-08-22

Compiler-pin and de-narrowing change set for Chelis v0.18.5.
`chelis reef conform bump 0.18.5` advanced the compiler pin and every workflow
audit mirror; the Coral package version advanced from 0.7.38 to 0.7.39.
`chelis reef conform sync` produced no content delta beyond the version stamps
the bump had already written.

**Not releasable yet: the Nautilus dependency is staged, not published.** Reef
enforces exact compiler-pin equality on dependencies, and the last published
Nautilus (0.7.41) declares `=0.18.4`, so `chelis reef build` refuses it at
coral's `=0.18.5` pin with `error: package.compiler must be `=0.18.5` in
`nautilus``. The dependency advances 0.7.41 -> **0.7.42**, the version
nautilus#43 stages by moving the package version and the compiler pin in one
manifest. Both are red until that release is tagged, but only 0.7.42 is
correct as written when it is. Every gate below ran against a Nautilus
artifact built from nautilus#43's head
`c060cb921ddfa8e5b907709fecd581f520097610` into a private registry; Nautilus
needed no source change for 0.18.5, so the outstanding work is a release
rather than a fix.

**chelis#1200 is fixed and its narrowing is retired.** chelis PR #1208 stops a
`_ =` wildcard discard from opening the Linearity-F2 destructure-consume scope
over the rest of the enclosing body. The pinned reproducer no longer fails to
compile, so all **84** bind-not-discard sites across the seven affected test
files are back to `_ =`, every `-- chelis#1200:` citation is gone, and the
reproducer is promoted from `tests_blocked/linearity/` to the executed
regression `tests/linearity.ch`. The suite is **75 passed, 0 failed** -- the
74-test pre-regression baseline plus that promoted test.

**The Frame build lane partly de-narrows (coral#26).** chelis#1158, #1201, and
#1216 retire the chelis#941 recursive-generic HAMT boundary, so a real `Frame`
can now be constructed in the build lane: a package-lane entry calling
`from_pairs` and reading `ncols` builds, links, runs, and returns the same
value as `chelis eval`. Through 0.18.4 that program could not be compiled at
all. Frame *reads* that pull a column back out of the HAMT still do not lower
-- `nrows` stops at `column_len` (chelis#1226) and `drop_nan` at an unresolved
`Column` match -- so coral#26 is partially, not fully, resolved.
`scripts/repro_package_frame_build.py` pins both directions;
`scripts/repro_native_drop_nan_blocked.py` moves off its retired chelis#941
diagnostic onto the surviving one. The match residue carries no issue citation
of its own, which is filed upstream as chelis#1260.

**Missing `Coral.Internal.Hamt` imports declared.** `hamt_entries` was used in
`frame.ch`, `groupby.ch`, `join.ch`, and `reshape.ch` without being imported.
`chelis check` scored 1.0 with an empty `unresolved_names` list and the suite
passed, but the newly reachable build lane rejected it with `unbound variable:
hamt_entries`. No behavior change on the eval lane. The checker gap that hid it
is filed upstream as chelis#1264.

The official chelis Darwin arm64 asset was verified at SHA-256
`0ff7b4e168d8b51277e05d44bfa658364630176d56d79c9cf8aceaea15335551`
(installed payload `bcf8da8bd2df9acb8816194f9251b26e23ec57527d4fc928bea6e1f6120628b2`,
byte-identical to the release tarball; upstream source commit
`6602f01719f55b8d4c7f52ee70e7c7b58f136107`).

**Validation on 0.18.5:** conform audit conformant, no MUST failures;
75 passed, 0 failed; 4 negative sidecars ok; 2 blocked probes ok (chelis#849
and the borrowed/borrowed `neq` residue); all three bare-build targets and the
native NaN regression compile, link, and run; the strict pandas parity gate,
static checks, 11/11 SKILL examples, and 8/8 mdBook examples all pass. The
three 0.18.5 BREAKING changes -- polymorphic recursion rejected at check,
integer literals in bare type positions, and left-to-right `>` operand
evaluation -- have no exposure in this corpus.

## [0.7.38] - 2026-08-05

Compiler-pin, grammar-migration, and chelis#1200-workaround release for
Chelis v0.18.4, on Nautilus 0.7.41. `chelis reef conform bump 0.18.4`
advanced the compiler pin and all workflow audit mirrors; the Nautilus
dependency advanced 0.7.40 -> 0.7.41 (the 0.18.4-pinning Nautilus release);
the Coral package version advanced from 0.7.37 to 0.7.38.

**The entire Surf corpus migrated to canonical Surf v0.19 (chelis#1031).**
The migration and the pin bump are one atomic change: v0.19-canonical source
fails the 0.18.3 style gate and pre-v0.19 source fails the 0.18.4 one. Most
of the rewrite is `chelis migrate surf --from 0.18` output, driven per file
(chelis#1197); the residue was repaired from the compiler's own diagnostics.

**chelis#1200 workaround.** On 0.18.4 a `_ =` wildcard discard opens the
Linearity-F2 destructure-consume scope over the rest of the enclosing body,
so any later reuse of a variable consumed by a record-destructuring callee
fails to compile. This regressed the suite to 17 passed / 7 files failing.
84 discard sites across the seven affected test files are rewritten to named
`asserted_N`/`bound_N` bindings, each citing chelis#1200 at the site;
`tests_blocked/linearity/wildcard_discard_consume.ch` pins the reproducer.
`src/` needed no change. With the workaround the suite is fully restored:
**74 passed, 0 failed** -- identical to the 0.18.3 baseline.

The official chelis Darwin arm64 asset was verified at SHA-256
`ac905d2a2d471ff09a46e39c7ae78ede85aab2f97515553b445ffd0dc0d29fea`
(installed payload `b6b80d65bf1822f6ad926915b4c5d4b3c94e414a9afcafa0bc02f9fc29a48037`,
byte-identical to the release tarball; upstream source commit
`c0138c828bf2c42e1c8941e824f16616bd974fd5`). Nautilus 0.7.41 was consumed at
its published sidecar hashes (CHB
`e92a47020f5691b49e5b39aba0094c7e1ed2e39d9dce55a9a135fd34480cc083`).

**Validation on 0.18.4:** conform audit conformant, no MUST failures;
74 passed, 0 failed; 4 negative sidecars ok; 3 blocked probes ok (the two
carried probes plus the new chelis#1200 reproducer).

## [0.7.37] - 2026-08-04

Compiler-pin and de-narrowing change set for the published Chelis 0.18.3 /
Nautilus 0.7.40 cascade. `chelis reef conform bump 0.18.3` advanced the compiler
pin and every workflow audit mirror, and the Coral package version advanced from
0.7.35 to 0.7.37.

**This bump skips 0.18.2.** The 0.7.36 / 0.18.2 candidate (PR #24 as originally
opened) was never published: it failed `scripts/repro_native_nan.py` with
`unsupported: builtin 'floor' on 'chelis build' host emission (codegen:c)`.
Nautilus 0.7.39 had worked the chelis#759 float-to-integer trap around by
wrapping five casts in `floor(...)`, and `floor` has no compiled-lane expression
identity, so the native build lane broke for every downstream consumer. Chelis
0.18.3 ships `cast_trunc` ([05-OP-6]) on the Surf, eval, and compiled-C
surfaces; Nautilus 0.7.40 moves those sites onto it. Coral needed no source
change of its own — the regression is green again purely from the dependency
fix.

The annotated Chelis v0.18.3 tag resolves to
`29700dd73c0e35b672bdd384493054b3107ce308`. Its published Darwin arm64 archive
and extracted binary have SHA-256
`cc8737adf8c21040432d94b96635ef48895bd7ac8cdf94bd7696046c44bc7371` and
`3a14b0d7e0a46a49c9b25f3dc61573d5972a91b411021672e09b8e3e0e9e1eba`. Nautilus
0.7.40 is published from commit
`c8466b29ffbe4ebc4126363db8c62a06a5b10e7f` (CHB
`2ba0d478f55d5b270801ada1b51d8dbc75a4d721a24bb8aa42f6f663b0e19bad`, archive
`a881f0b96a908a8356b720bfe21e6bde724bea204310e51957b452ad3740a47c`); those
bytes are identical to the pre-release build this change set was first
validated against.

No §Tracking entry moved at this pin: chelis#849, the borrowed/borrowed float
tensor `neq` residue, and chelis#941 all stay blocked.

Complete local gate: 74 positive tests, 4 negative contracts, 2 blocked probes,
strict pandas parity green, `repro_native_nan.py` OK, `repro_multimodule_bare_build.py`
OK, `repro_native_drop_nan_blocked.py` blocked as expected, 11/11 SKILL examples,
8/8 mdBook examples, static checks OK, conform audit green, bump-check green.

## [0.7.35] - 2026-08-01

Prepared the Coral 0.7.35 manifest and CI mirrors for the published Chelis
0.18.1 / Nautilus 0.7.38 cascade. The required `chelis reef conform bump
0.18.1` restamped the managed conformance blocks and the Nautilus dependency
moved only after its official release workflow published checksum-sealed
assets.

This is release-candidate validation, not a publication claim. The annotated
Chelis v0.18.1 tag resolves to
`c8db387d06d538ce8039ac37645a43def48373c9`. Its published glibc-2.31 archive
and extracted binary have SHA-256
`88a1a53b47b7168e4df614e66a6d9313176174b1dc3a25a43db5f73a3ee8f0cd` and
`0d7a46262b4ba2975702d5ed2def5d54b79b5d68258602da59069b6715cc690b`.
Nautilus v0.7.38 is published from commit
`6b4c10f19a2cd120c08ba3c7d9cb746c161106ec`; its CHB and archive SHA-256 are
`cad8bd996ddeddb25f698496a394ab45388a120f9b870e7832cb5b87b5935740` and
`39a81b079dfae2a0aa907574954eeb48631757fb5fb1d0940def0c8a98adf4f6`.

The de-narrowing pass restores O(1) `numel` row counts after live 0.18.1
probes showed empty tensors now report zero, and restores direct tensor-bool
`not`. Owned and copied-left float tensor `neq` now infer bool, but a fresh
evaluator-versus-native red-team probe found that the native C lowering is
still not IEEE-correct for NaN (chelis#630). Coral therefore retains an O(n)
scalar host-map for float NaN masks while integer masks and mask inversion use
direct tensor `not`. New empty-column and float/int drop-NaN tests cover the
evaluator paths, and a compile-link-run regression covers float mask,
drop-core, count, and any behavior in native C. Full native
`drop_nan(Frame, ...)` remains explicitly blocked at recursive generic
`hamt__from_pairs_rec` (chelis#941); a mechanical expected-failure probe now
prevents the trivial-entry bare-module smoke from being mistaken for that
capability. The chelis#849 newline parser and chelis#741 helper-axis
limitations remain reproducible and cited.

The complete local gate passes on the exact official dependency chain: 74/74
native tests, 4/4 negative contracts, 2/2 Chelis expected-to-fail blocker
probes plus the native chelis#941 expected failure,
strict pandas/runtime parity, 11/11 SKILL examples, 8/8 mdBook examples, all
three trivial-entry bare-C module smokes, conformance audit, and bump-check. The
release artifacts pass canonical verification, reject independently corrupted
CHB and archive controls, and rebuild byte-identically. Candidate SHA-256
values are `457bc6a41246795f0ce77763e490b4869225faf837255d15e655fb3e709e9a8b`
(CHB) and `8a95c0bb412c86040cba5210d4a305034761d5a205291c30b472c324b78650f5`
(archive). Official Coral release identities remain contingent on the
post-merge tag workflow.

Prepared Coral 0.7.33 for the published Chelis 0.17.4 and Nautilus 0.7.36
cascade. The compiler pin, Nautilus dependency, CI mirrors, and managed
conformance blocks move together. Validation consumes the official
publisher-checksummed releases: Chelis tag commit `0b0c92f9916163b05a483fba70473496923730e6`
and Nautilus tag commit `2c434a9dfefca79c371b4c66af62b121a47841d6`.

Hardened CI and release transport: Linux uses the glibc-2.31 compiler asset,
Linux and Darwin verify the publisher sidecar before extraction, toolchain
caches are checksum-schema scoped, and the Coral release requires canonical
artifact verification plus a byte-identical rebuild and publishes a checksum
manifest for the complete payload set.

Corrected all six `Coral.Window` public signatures to return `tensor[n, f32]`
for an input `tensor[n, f32]`. They preserve length by construction; the old
independent output dimension `m` was unconstrained. Positive compile-level
tests and a negative mismatched-extent contract now pin the preserved extent;
the runtime parity generator also emits a concrete same-extent wrapper.

The package build, 71-test evaluator suite, 4-case negative suite,
documentation checks, strict pandas parity, and stripped
Frame/GroupBy/Join trivial-entry bare-C smokes are green on the exact final
compiler and Nautilus package after chelis#935. Invoked recursive generic
Frame operations are a separate chelis#941 boundary.

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
