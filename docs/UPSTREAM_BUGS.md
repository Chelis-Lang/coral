# Upstream Chelis Bugs

This file names the upstream limitations that affect Coral at its Chelis
0.18.13 pin. Each entry gives the affected surface, a probe, and the condition
for checking it again.

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

Re-run each listed probe at every compiler pin bump and before a Coral
release. The native package probes use the published Nautilus dependency;
local candidate builds do not replace that release check.

### Re-probing

There are no checker-level upstream blockers to put in `tests_blocked/`.
The gather-axis test checks an intentional rejection under [05-AXIS-2] in
`tests_neg/frame/gather_axis_helper_neg.ch`. A future checker-level blocker
gets a source and diagnostic sidecar in `tests_blocked/` and runs with
`chelis test tests_blocked/ --expect blocked` until the upstream fix lands.

Native build limitations use Python probes under `scripts/`. Each exits 0
when the outcome matches this file and 1 when it changes:

| Probe | Entry |
|---|---|
| `scripts/repro_multimodule_bare_build.py --target {frame,groupby,join}` | chelis#2097 in stripped source builds |
| `scripts/repro_package_frame_build.py --target all` | Native/evaluator agreement for nine Frame entries |
| `scripts/repro_native_drop_nan_blocked.py` | chelis#2097 in the stripped `drop_nan` lane |
| `scripts/repro_native_nan.py`, `scripts/repro_native_neq.py` | Native NaN behavior |

## Actively blocking

## Tracking

- **Stripped Frame, GroupBy, and Join builds stop at an ownership-signature
  rejection ([chelis#2097](https://github.com/Chelis-Lang/chelis/issues/2097)).**

  *Reproducer:* `scripts/repro_multimodule_bare_build.py`, all three
  targets. Each concatenates Coral's Frame, GroupBy, or Join modules with
  their dependencies into one file and builds a trivial entrypoint with
  `chelis build`. All three reject at `frame__list_filter_string` with
  `does not match ownership signature`. The same diagnostic stops the
  stripped `drop_nan` entry in `scripts/repro_native_drop_nan_blocked.py`.

  *Affected surface:* none that ships. Coral is consumed as a Reef package,
  and its tests run in the evaluator. The limitation affects only these
  bare-C smoke builds.

  *Workaround:* `scripts/repro_native_nan.py` compiles only Coral's own
  float-NaN helpers rather than the whole Frame module chain, so it can
  still guard chelis#630 natively.

  *Re-probe trigger:* each compiler pin bump. If the smokes pass, test the
  full Frame module chain in `scripts/repro_native_nan.py`; if they reach a
  different rejection, classify that boundary before changing the probe.

- **`describe` and `drop_column` reject in native package builds
  ([chelis#3169](https://github.com/Chelis-Lang/chelis/issues/3169),
  [chelis#879](https://github.com/Chelis-Lang/chelis/issues/879);
  Coral-side tracker [coral#26](https://github.com/Chelis-Lang/coral/issues/26)).**

  *Reproducer:* Build an entry that calls each verb through `Coral.Frame`.
  `describe` rejects at `build_describe_pairs` because its checked type
  application is not concrete (chelis#1226, tracked as chelis#3169).
  `drop_column` rejects an anonymous function value with chelis#879.

  *Affected surface:* native `chelis build` of those invoked Frame verbs;
  package checking and evaluation work.

  *Re-probe trigger:* each compiler pin bump. Test each verb separately.

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

- **Parquet file I/O is unavailable
  ([chelis#850](https://github.com/Chelis-Lang/chelis/issues/850)).**

  *Reproducer:* A standalone entry that imports
  `Std.Io.Parquet (read_parquet)` and calls
  `len(read_parquet("missing.parquet"))` checks at score 1.0 and builds an
  executable. Running it exits 1 with
  `Std.Io.Parquet.read_parquet is not implemented: missing.parquet`.
  The `sig`-without-`def` example in chelis#850 rejects at checking, so it
  does not reproduce the missing-symbol behavior.

  *Affected surface:* `Coral.Io.read_parquet_frame` and
  `write_parquet_frame`.

  *Workaround:* both functions are exported so the API shape is stable, and
  both call `fail(...)` at runtime.

  *Re-probe trigger:* upstream movement on chelis#850 or the next Coral
  release. Re-run check, build, and the executable; a successful build
  alone does not establish working Parquet I/O.

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
