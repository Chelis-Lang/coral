# Chelis 0.18.11 candidate

Prepared 2026-09-21 in the isolated `chore/chelis-0.18.11` worktree. Coral's
candidate version is 0.7.43. Compiler/workflow pins, managed blocks, maintained
sources, executable docs and probe generators target 0.18.11. No Coral release,
hosted CI or review is certified by this local receipt.

## Published inputs

All final gates use the installed official compiler at
`~/.chelis/toolchains/0.18.11/bin/chelis`, SHA-256
`416e7b5875c7b2d3c8cc5835e0b89a983ff46e866f6f4989d9876a93e2e60951`.
The release source commit supplied by the orchestrator is
`a7e592f88a148d8323b8f9a8f679c8e163ad3ee7`.

Nautilus is pinned to published **0.7.46**, from commit
`ead1d65e2d7e5763e5c7f90e8c417aa36fd552e2`.
Its successful release run is
[35672514516](https://github.com/Chelis-Lang/nautilus/actions/runs/35672514516).
Installed with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.46`;
local bytes match the supplied publisher receipt:

- CHB: `b581332e726ebec25a851bb7d453882dfa0c39c2cb5f640a4327d51d1b821b7a`.
- Archive: `8a37bccd8c57e8d0b727a0f23f8de7082008aef43ebc77f899e647290fb0b71f`.

The generated, ignored `reef.lock` records those exact hashes and compiler
`=0.18.11`, with compiler-bundled chelis-std 0.4.0. The former envelope-4
blocker is cleared; no dependency was locally repacked.

## Migration and validation

Canonical `i32`/`i64` and list `skip` replace retired language spellings in
sources and generated probes. The join helper `append_named[n]` now declares
the dimension already used by its three `Column[n]` annotations.
The original invalid parser witness is preserved, not formatter-normalized.
Migration-note filenames use lint-required snake_case. Historical release
receipts keep their original evidence.

The native tensor-inequality probe detected chelis#630's IEEE fix. The positive
`scripts/repro_native_neq.py` now verifies that both evaluator and native C
report only NaN unequal to itself for `[NaN, -0.0, 3.5]`. `is_nan` uses
`neq(col, col)`; native production mask/drop-core/count/any execution passes.
The old scalar host-map is removed, and its blocker entry is archived.

Passing local checks:

- `chelis reef build`; published-dependency package resolution.
- `chelis test tests/ --timeout 600 --jobs auto`: 80 passed.
- `chelis test tests_neg/ --expect neg --jobs 1`: six passed.
- `chelis test tests_blocked/ --expect blocked --jobs 1`: one passed.
- `scripts/run_skill_checks.py`: 11/11; `validate_book_examples.py`: 8/8.
- `uv run --project parity --frozen python parity/run_parity.py --strict`:
  all 45 golden inventory files and pandas comparison; rolling-mean/EWM native
  parity; all three generated negative cases. This command uses parity's
  isolated, repository-declared Python 3.12 environment; other scripts use the
  worktree's uv-managed Python 3.11.
- Five workflow/parity contract unit tests, static checks, source/doc formatting,
  lint, conformance audit and bump-check.
- Package Frame construction builds, links, runs and agrees with eval (2 columns).
  The `nrows` probe still matches chelis#1226's expected specialization boundary.
- The invoked native `drop_nan` probe still matches its existing host-inference
  boundary. No full Frame-read native support is claimed.

**The complete manual gate is not green.** All three non-shipping bare-C
Frame/GroupBy/Join module smokes stop at the documented chelis#2097
function-value ownership-signature mismatch in `frame__list_filter_string`.
The narrow native NaN regression remains deliberately separate. No compiler
workaround or weakened oracle was added to hide this limitation.

## Candidate artifact checks

After documentation and package probes removed their temporary modules, two
clean `reef build --no-auto-fetch` runs produced byte-identical artifacts.
`reef verify-artifact --json` reports `valid: true`, `errors: []`; an
archive copy with appended corrupt bytes is rejected. Local candidate hashes:

- CHB: `ce1cd84906996feae3adae75253c709d025cebbcc39e956447fd70298eade592`.
- Archive: `0dc97f32fc1e8f22a592762f144fe89632c52879da77e2869029b67c13f39852`.

These are local build receipts, not published Coral artifact identities.
