# Upstream Chelis Bugs

This file records the upstream Chelis compiler issues that currently shape
Coral: what each one blocks, how Coral works around it, and when to check it
again. It describes the state at the current **pin**, the exact compiler
release that `reef.toml` requires. Coral selects the published Chelis 0.18.13
toolchain and Nautilus 0.7.48, whose release is pending. Package-dependent
0.18.13 probes await that Nautilus release; the standalone gather-axis and
native NaN probes ran on 2026-10-05. The chelis#828 performance measurement
and chelis#850 Parquet check retain their earlier observations until
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

Entries live in one of three sections, each with its own re-probe cadence. To
**re-probe** an entry is to rerun its reproducer against the pinned toolchain
and record whether the limitation is still present.

| Section | Holds | Re-probe cadence |
|---|---|---|
| Actively blocking | Limitations that break a Coral surface at the current pin | Every compiler pin bump and before every Coral release |
| Tracking | Filed limitations that narrow Coral's implementation or its native lanes but not its shipped package surface | Every compiler pin bump |
| Archived | Fixed limitations kept for regression context | None; revisit only on a reported regression |

§Actively blocking has no confirmed entries at 0.18.13. A compiler regression that
breaks the shipped package, the native test suite, or the parity gate
belongs there.

### Re-probing

Reproducers the test harness can express are **blocked probes** under
`tests_blocked/`: sources that deliberately fail to compile, each paired with a
`.expect` sidecar whose first line pins the expected diagnostic and whose
remaining lines cite the blocker and say what to do when it is fixed.
`chelis test tests_blocked/ --expect blocked` runs them in CI. The remaining
gather-axis case guards an intentional checking rejection under [05-AXIS-2],
not an open compiler defect. A pass would signal a contract change to investigate.

The native-lane limitations cannot be expressed that way, so they have Python
probes under `scripts/`. Each exits 0 when the outcome matches what this file
records and 1 when it changes:

| Probe | Entry |
|---|---|
| `scripts/repro_multimodule_bare_build.py --target {frame,groupby,join}` | chelis#730; chelis#2097 masked |
| `scripts/repro_package_frame_build.py --target {construct,nrows,match_column}` | Positive native Frame paths; the `nrows` chelis#1226 instance cleared |
| `scripts/repro_package_frame_build.py --target {drop_nan,filter,head,slice,sort_by,with_column}` | Positive native/eval regressions for chelis#3153, pending Nautilus 0.7.48 |
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

- **`describe` and `drop_column` remain native-build gaps
  ([chelis#3169](https://github.com/Chelis-Lang/chelis/issues/3169),
  [chelis#879](https://github.com/Chelis-Lang/chelis/issues/879);
  Coral-side tracker [coral#26](https://github.com/Chelis-Lang/coral/issues/26)).**

  *Reproducer:* On the previous pin, `describe` reached a generic host call
  whose output dimension was not fixed by its inputs (chelis#3169), while
  `drop_column` reached the unsupported anonymous-function host ABI
  (chelis#879). These are distinct from the closed chelis#3153 defect.

  *Affected surface:* native `chelis build` of those invoked Frame verbs;
  package checking and evaluation were unaffected at the previous pin.

  *Re-probe trigger:* every compiler pin bump. Re-probe each verb in the
  package lane after Nautilus 0.7.48 is published, and record its separate
  result rather than inferring from the six repaired Frame paths.

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

- **chelis#3153**, unresolved host types for context-fixed empty-list actuals,
  is fixed in the 0.18.13 compiler. The six former expected-failure Frame
  probes (`drop_nan`, `filter`, `head`, `slice`, `sort_by`, `with_column`) have
  been converted to positive native/eval comparisons. Their package-lane
  verification awaits the Nautilus 0.7.48 release. The six further verbs
  named in coral#26 remain outside those executable comparisons.

- **chelis#741**, the gather-axis helper ambiguity, is resolved by a normative
  static-axis rule: `[05-AXIS-2]` requires a literal or cast-wrapped literal
  at checking, while `sort` admits a computed axis. The published 0.18.13
  checker rejects the helper form with `DimensionMismatch`; eval and native
  build reject it consistently. `tests_blocked/lowering/gather_axis_helper.ch`
  pins the deliberate rejection. Coral keeps inline gather axes by contract,
  and `tests/internal.ch` covers the supported sort helper.

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
