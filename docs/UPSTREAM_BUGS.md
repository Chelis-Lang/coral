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

One evaluator-level blocker has a probe in `tests_blocked/`:
`tests_blocked/io/read_json_frame_row_depth_blocked.ch`, run with
`chelis test tests_blocked/ --expect blocked`. It reports FIX-detected, and
fails loudly, once the pinned toolchain carries the upstream fix.

There are no checker-level upstream blockers. The gather-axis test checks an
intentional rejection under [05-AXIS-2] in
`tests_neg/frame/gather_axis_helper_neg.ch`. A future checker-level blocker
gets a source and diagnostic sidecar in `tests_blocked/` the same way.

Native build limitations use Python probes under `scripts/`. Each exits 0
when the outcome matches this file and 1 when it changes:

| Probe | Entry |
|---|---|
| `scripts/repro_multimodule_bare_build.py --target {frame,groupby,join}` | chelis#2097 in stripped source builds |
| `scripts/repro_package_frame_build.py --target all` | Native/evaluator agreement for nine Frame entries |
| `scripts/repro_native_drop_nan_blocked.py` | chelis#2097 in the stripped `drop_nan` lane |
| `scripts/repro_native_nan.py`, `scripts/repro_native_neq.py` | Native NaN behavior |

## Actively blocking

- **`read_json_frame` is bounded by document size, at roughly 950 rows under
  `chelis test` and 236 under `chelis eval`
  ([chelis#2307](https://github.com/Chelis-Lang/chelis/issues/2307)).**
  `Std.Io.Json` parses with depth proportional to the input's size, so the
  parser exhausts the stack before Coral sees the document.

  *Reproducer:* `tests_blocked/io/read_json_frame_row_depth_blocked.ch`
  (`chelis test tests_blocked/ --expect blocked`), a 2,000-row document.

  *Measured at this pin,* macOS arm64. **No figure here is meaningful without
  its lane:** `chelis eval` runs on the process main thread and `chelis test`
  on a larger worker stack, and the two differ by roughly 4x. Quoting one at a
  reader on the other is wrong by that factor in whichever direction.

  | lane | varied axis | passes | overflows |
  |---|---|---|---|
  | `chelis test` | array elements, one short int cell each | 960 | 975 |
  | `chelis test` | characters in one string cell, one element | 2,440 | 2,537 |
  | `chelis test` | `read_json_frame` end to end, one `IntCol` | 954 | 993 |
  | `chelis eval` | array elements, one short int cell each | 236 | 243 |
  | `chelis eval` | characters in one string cell, one element | 595 | 614 |
  | `chelis eval` | `read_json_frame` end to end, one `IntCol` | 236 | 243 |

  The per-axis rows call `load_json` and `json_array` only, with **no Coral
  symbol on the path**. That is what establishes the bound is not Coral's, and
  the `chelis eval` rows establish it more strongly than the worker rows do:
  on the tighter budget the bare-parser and end-to-end brackets are not merely
  overlapping but *identical*, so Coral contributes no measurable depth even
  where roughly a quarter as much is available. The element rows are identical
  for an array of bare scalars and an array of objects, so Coral's own
  per-entry walk was never implicated either: that walk is now a `map`, and
  both end-to-end figures are unchanged by the change that made it one.

  Note that chelis#2307's own headline figure, 1,209 bytes, is a `chelis eval`
  measurement of a long string, and its table brackets the worker lane loosely
  at 4,000/8,000 characters. The rows above are this repository's own
  measurements through `load_json` and `read_json_frame`, not that issue's
  figures restated.

  *Not established:* whether the two depth bounds share one budget. Mixed
  documents large enough to test it (500 elements of 1,000 characters,
  roughly 500 KB) exceed the 150-second test timeout before they overflow,
  because the same parser accumulates strings quadratically
  ([chelis#943](https://github.com/Chelis-Lang/chelis/issues/943), open).
  Smaller mixed documents pass: 500 elements of 100 characters, and 800 of
  50, both read.

  *Affected surface:* `read_json_frame` only. `read_csv_frame`,
  `write_csv_frame`, and `write_json_frame` each handle 20,000 rows.

  *Workaround:* none in Coral. Read large tabular data as CSV, which has no
  comparable bound.

  *Re-probe trigger:* chelis#2307 is closed upstream, fixed by
  [chelis#3336](https://github.com/Chelis-Lang/chelis/pull/3336) at merge
  commit `24b1f8e0b6d815eff12f868999813023915da05d`, which is an ancestor of
  chelis `main` and carried by no release tag yet. The first release
  containing the fix is the first tag reported by
  `git tag --contains 24b1f8e0b6d815eff12f868999813023915da05d` in a chelis
  checkout. Re-run the blocked probe at that pin bump; a changelog claim is
  not verification, and chelis `CHANGELOG.md` records neither issue.

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

No entries.
