# Upstream Chelis Bugs

This file names the upstream limitations that affect Coral at the compiler
pin in [`reef.toml`](../reef.toml). Each entry gives the affected surface, a probe, and the condition
for checking it again.

## How this file works

Every limitation Coral works around is filed upstream and cited by number, as
`chelis#NNN` for the compiler or as `<repo>#NNN` for a sibling Chelis package
(written without a space, for example `coral#26`). The narrowing site in Coral
cites the issue or a deferral in
[`spec/scope.md`](../spec/scope.md#deferrals). A deferral caused by an
upstream limitation identifies the issue recorded here. Coral-owned choices
without an upstream blocker also live in that deferral list.

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
  `from_pairs` and applies one `with_column`. The recursive HAMT helpers can
  exceed the default 30-second per-test evaluator budget; this entry does
  not claim a timing measurement at the pinned compiler. Native execution
  has a separate validation boundary.

  *Affected surface:* evaluator workloads with wide frames.

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
