# Upstream Chelis Bugs

This file records the upstream Chelis compiler issues that currently shape
Coral: what each one blocks, how Coral works around it, and when to check it
again. It describes the state at the current **pin**, the exact compiler
release that `reef.toml` requires. Coral pins the published Chelis 0.18.12
toolchain and Nautilus 0.7.47 package. The pin-bump probes due under the
cadences below were run on 2026-10-01. The chelis#828 performance measurement
and parked chelis#850 Parquet check retain their earlier observations until
their stated triggers. Earlier re-probe records are in git history and
[`CHANGELOG.md`](../CHANGELOG.md).

## How this file works

Every limitation Coral works around is filed upstream and cited by number, as
`chelis#NNN` for the compiler or as `<repo>#NNN` for a sibling Chelis package
(written without a space, for example `coral#26`). A limitation that is not yet
filed is cited by the path of its draft under
[`docs/issue_drafts/`](issue_drafts/README.md). The same citation appears at
the **narrowing site**, the place in Coral where a feature is restricted or
replaced because of the limitation, so that `chelis reef conform audit` can
match the two mechanically. Narrowings that are Coral's own choice rather than
a compiler limitation are listed as deferrals in
[`spec/scope.md`](../spec/scope.md#deferrals) instead.

Entries live in one of four sections, each with its own re-probe cadence. To
**re-probe** an entry is to rerun its reproducer against the pinned toolchain
and record whether the limitation is still present.

| Section | Holds | Re-probe cadence |
|---|---|---|
| Actively blocking | Limitations that break a Coral surface at the current pin | Every compiler pin bump and before every Coral release |
| Tracking | Filed limitations that narrow Coral's implementation or its native lanes but not its shipped package surface | Every compiler pin bump |
| Parked | Missing upstream features Coral stubs out | When upstream signals movement, or at the next minor Coral release |
| Archived | Fixed limitations kept for regression context | None; revisit only on a reported regression |

§Actively blocking has no entries at 0.18.12. A compiler regression that
breaks the shipped package, the native test suite, or the parity gate
belongs there.

### Re-probing

Reproducers the test harness can express are **blocked probes** under
`tests_blocked/`: sources that must fail to compile, each paired with a
`.expect` sidecar whose first line pins the expected diagnostic and whose
remaining lines cite the blocker and say what to do when it is fixed.
`chelis test tests_blocked/ --expect blocked` runs them in CI. A probe that
stops failing reports `CONFIG-ERROR` ("no test records produced"), which means
the upstream fix has landed: remove the workaround, promote the probe to a
test under `tests/`, and archive the entry.

The native-lane limitations cannot be expressed that way, so they have Python
probes under `scripts/`. Each exits 0 when the outcome matches what this file
records and 1 when it changes:

| Probe | Entry |
|---|---|
| `scripts/repro_multimodule_bare_build.py --target {frame,groupby,join}` | chelis#730; chelis#2097 masked |
| `scripts/repro_package_frame_build.py --target {construct,nrows,match_column}` | Positive native Frame paths; the `nrows` chelis#1226 instance cleared |
| `scripts/repro_package_frame_build.py --target {drop_nan,filter,head,slice,sort_by,with_column}` | chelis#3153 in the package lane |
| `scripts/repro_native_drop_nan_blocked.py` | chelis#730 in the stripped lane |
| `scripts/repro_native_nan.py`, `scripts/repro_native_neq.py` | chelis#630 regressions (Archived) |

## Actively blocking

## Tracking

- **Stripped Frame, GroupBy, and Join builds stop at unresolved host
  inference ([chelis#730](https://github.com/Chelis-Lang/chelis/issues/730);
  earlier [chelis#2097](https://github.com/Chelis-Lang/chelis/issues/2097)
  diagnostic is masked).**

  *Reproducer:* `scripts/repro_multimodule_bare_build.py`, all three
  targets. Each concatenates Coral's Frame, GroupBy, or Join modules with
  their dependencies into one file and builds a trivial entrypoint with
  `chelis build`. On 0.18.12 all three fail with `host type did not resolve
  before the code-generation boundary`. On 0.18.11 they reached the later
  chelis#2097 ownership-signature diagnostic. An isolated direct call to
  the production `list_filter_string` with a named predicate also stops
  at chelis#730, so the new diagnostic is not evidence that chelis#2097
  is fixed.

  *Affected surface:* none that ships. Coral is consumed as a Reef package,
  and its tests run in the evaluator. The limitation affects only these
  bare-C smoke builds.

  *Workaround:* `scripts/repro_native_nan.py` compiles only Coral's own
  float-NaN helpers rather than the whole Frame module chain, so it can
  still guard chelis#630 natively.

  *Re-probe trigger:* every pin bump. When the smokes pass, restore the full
  Frame module chain in `scripts/repro_native_nan.py`; if they reach a
  different rejection, investigate that boundary before re-citing it.

- **Six invoked `Frame` verbs still fail native lowering
  ([chelis#3153](https://github.com/Chelis-Lang/chelis/issues/3153);
  Coral-side tracker [coral#26](https://github.com/Chelis-Lang/coral/issues/26)).**

  `drop_nan`, `filter`, `head`, `slice`, `sort_by`, and `with_column`.
  chelis#3153 is one defect: a bare `[]` passed as the accumulator of a
  recursive dimension-generic function whose element type is a
  dimension-generic ADT — in Coral, `(string, Column[n])`. Upstream controls
  show seeding that accumulator, or dropping the ADT wrapper, both build.

  **The diagnostic prints `chelis#730`, which is not the defect.** That
  citation is hard-coded into the format string in
  `crates/chelis-ir/src/host.rs`, and
  [chelis#730](https://github.com/Chelis-Lang/chelis/issues/730) is a
  tracking hub (77 sub-issues), so the number the compiler emits names the
  plan rather than the thing that would close this. None of the hub's open
  children owned this shape, which is why #3153 was filed. Track #3153; do
  not re-cite #730 from the diagnostic text.

  *Reproducer:* `scripts/repro_package_frame_build.py` imports
  `Coral.Frame` in a Reef project. `--target construct` builds, links,
  runs, and agrees with eval at `ncols = 2`. `--target nrows` now does the
  same at `nrows = 3`: the former chelis#1226 diagnostic no longer occurs
  for this Coral instance. A direct match on a retrieved `Column[n]` also
  builds and runs, returning its three-element length. These probes do
  not establish a class-wide fix for chelis#1226 or the older
  [chelis#1260](https://github.com/Chelis-Lang/chelis/issues/1260)
  match diagnostic. The six expected-failure targets above each reject
  with `host type did not resolve before the code-generation boundary`.
  `scripts/repro_native_drop_nan_blocked.py` confirms that boundary in
  the separate stripped-module lane.

  *Pinned to the 0.18.12 compiler.* Reproducing against chelis `main`
  needs a regenerated `reef.lock`: `SHELL_FORMAT_VERSION` moved 5 → 6
  upstream, so `main` rejects every published 0.18.12-era shell with
  `shell format version 5 is unsupported; expected 6`. That wall is not a
  Coral defect, and the six rejections above were confirmed still present
  on `main` once the lock was regenerated.

  *Affected surface:* native `chelis build` of those six invoked Frame
  paths. The Reef package, evaluator, and test suites are unaffected.
  `nrows`, `ncols`, `get_column`, `get_float_col`, `column_type`, and
  `rename` do build, link, and run. Frame verbs with no probe above still
  need their own before claiming coverage.

  *Not this entry:* `drop_column` also rejects, but with a different
  diagnostic (`unsupported: anonymous function value `fn``, from
  `list_filter_string`). chelis#3153 does not cover it and no upstream
  issue yet owns it, so it is deliberately not pinned.

  *Workaround:* none in Coral's source. The native NaN regression compiles
  the NaN helpers on bare tensors instead of through a `Frame`.

  *Re-probe trigger:* every pin bump. The now-positive `nrows` read runs
  in CI. When any of the six targets reports a fix, compile, link, run,
  and compare that invoked path with eval before changing its expectation.

- **A `gather` axis passed through a helper call is rejected
  ([chelis#741](https://github.com/Chelis-Lang/chelis/issues/741)).**

  *Reproducer:* `tests_blocked/lowering/gather_axis_helper.ch`. With
  `def zero_i32() -> i32 = cast(0, i32)`, `gather(xs, idx, zero_i32())`
  fails with `` `gather` axis is not a compile-time integer constant ``.
  On 0.18.12 the blocked suite still matches this diagnostic; inline
  gather axes remain exercised by Coral's positive tests. The sibling
  `sort(xs, zero_i32())` form now evaluates and builds; a direct native
  compile, link, and run agreed with eval, and `tests/internal.ch` guards
  its evaluator behavior.

  *Affected surface:* none visible to users.

  *Workaround:* `src/frame.ch` writes `cast(0, i32)` inline at every
  `gather` axis. Its three numeric `sort` sites now call the named
  `axis_zero()` helper.

  *Re-probe trigger:* the blocked probe runs in CI on every change.

- **Evaluator cost of the HAMT column store
  ([chelis#828](https://github.com/Chelis-Lang/chelis/issues/828); Coral-side
  tracker [coral#16](https://github.com/Chelis-Lang/coral/issues/16)).**

  *Reproducer:* a `chelis test` case that builds a 100-column frame with
  `from_pairs` and applies one `with_column`. Re-measured on 0.18.11
  (Apple silicon): about 164 seconds, far beyond the 30-second default
  per-test budget. The cost is per-call evaluator overhead in the recursive
  HAMT helpers, not the algorithm; native code is unaffected.

  *Affected surface:* evaluator workloads with wide frames. The design range
  is 50 to 100 columns.

  *Workaround:* none; Coral's tests use narrow frames.

  *Re-probe trigger:* when upstream reports evaluator speedups on
  chelis#828, or when a Coral user needs 100 or more columns in the
  evaluator.

## Parked

- **`Std.Io.Parquet` has no runtime backing
  ([chelis#850](https://github.com/Chelis-Lang/chelis/issues/850)).**

  *Reproducer:* `import Std.Io.Parquet (read_parquet)` checks at score 1.0
  on 0.18.11, but the module exports signatures only and
  `libchelis_runtime.a` contains no Parquet symbol. A call lowers to an
  undeclared C function and the native compile fails. The issue is filed
  against that gap: a score-1.0 check should not lower to a missing runtime
  symbol.

  *Affected surface:* `Coral.Io.read_parquet_frame` and
  `write_parquet_frame`.

  *Workaround:* both functions are exported so the API shape is stable, and
  both call `fail(...)` at runtime.

  *Re-probe trigger:* upstream movement on chelis#850, or the next minor
  Coral release.

## Archived

- **chelis#849**, a newline before `else` inside a `{ }` block rejected at
  parse time. Fixed upstream and verified on 0.18.11: the form parses and
  evaluates. The former blocked probe no longer tested this bug (it failed on
  the intended one-expression-block rule instead) and was retired. It cannot
  become a regression test because `chelis fmt` rewrites the form onto one
  line, which is also the layout `parity/run_parity.py` generates.
- **chelis#630**, native tensor `neq` not IEEE-correct at NaN. Fixed at
  0.18.11. `Coral.Frame.is_nan` uses `neq(col, col)` directly, and
  `scripts/repro_native_neq.py` and `scripts/repro_native_nan.py` are the
  native regressions; `tests/types.ch` covers the borrowed-operand typing.
- **chelis#405**, scalar `grad` in the C backend. Verified on 0.18.11:
  `grad` of a scalar function builds and runs natively. Coral never depended
  on it; gradients through Coral remain deferral D5 in `spec/scope.md`.
- **chelis#2068**, a native C liveness error on a by-value scalar passed to
  several argument slots of a tail call. It surfaced through Nautilus code in
  Coral's native probes and was verified fixed on 0.18.10; Coral never
  narrowed for it. The upstream issue remains open.
- **chelis#1200**, `_ = f(x)` marking `x` consumed. Fixed at 0.18.5;
  `tests/linearity.ch` is the regression.
- **chelis#646** (empty-tensor `numel`) and **chelis#647** (`not` on a bool
  tensor). Fixed at 0.18.1; Coral uses both directly, and the empty-column
  and NaN-drop tests cover them.
- **chelis#941** and its successor **chelis#1158**, recursive generic host
  calls rejected in native builds, which made `Frame` construction
  impossible there. Fixed at 0.18.5; the remaining Frame-read boundary is
  chelis#1226 above.
- **chelis#935**, nullary generic constructors losing their type arguments in
  C lowering. Fixed at 0.17.4.
- **Unbound `|>` pipe targets accepted in large native builds** (a parked,
  never-filed draft). The original reproducer is correctly rejected with
  `UnboundVariable` on 0.17.1 and on 0.18.11, so the draft was retired
  without filing. `tests_neg/frame/unbound_function_neg.ch` pins the
  rejection of a single unbound direct call.
