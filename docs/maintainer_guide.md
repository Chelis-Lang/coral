# Maintainer guide

## Setup

Coral builds with one exact Chelis compiler version, recorded as the
`compiler` pin in [`reef.toml`](../reef.toml). Install `chelisup`, the Chelis
toolchain manager, and then from a fresh clone run:

```sh
chelisup install 0.19.1
```

`chelisup install` provides the compiler pinned by `reef.toml`.
`chelisup` resolves the compiler per repository from `reef.toml`, so other
Chelis projects on the same machine are unaffected. Install the published
Nautilus tag named in `reef.toml` with
`chelis reef install --from-github Chelis-Lang/nautilus@vX.Y.Z`, substituting
the version, then run `chelis reef build`.

`--from-github` authenticates with `GITHUB_TOKEN`, falling back to
`gh auth token`.

Python tooling is managed by [uv](https://docs.astral.sh/uv/). Scripts under
`scripts/` use only the standard library but need Python 3.11 or newer, so run
them through uv as shown below rather than with a system interpreter. The
pandas parity harness is a separate uv project under `parity/`.

## Tests

| Suite | Command | What it checks |
|---|---|---|
| Native tests | `chelis test tests/ --timeout 600 --jobs auto` | Identities, hand-computed values, structural properties, and round trips, written in Chelis. Use `--jobs 1` to debug serially |
| Negative tests | `chelis test tests_neg/ --expect neg` | Each `tests_neg/<area>/<name>.ch` must fail to compile with the diagnostic on line 1 of its `.expect` file |
| pandas parity | `uv run --project parity --frozen python parity/run_parity.py --strict` | Checked-in goldens still match pandas, and native `rolling_mean` and `ewm` match their goldens by execution; see [`spec/scope.md`](../spec/scope.md#what-the-parity-harness-proves) |

`tests/` must never contain Python, and pandas, SciPy, or other oracle
libraries may be imported only under `parity/`. CI enforces both rules.

## Local gate

Run the whole gate before opening a pull request that changes library code:

```sh
rg --files -g '*.ch' -0 | xargs -0 -n1 chelis fmt --check
chelis lint --check .
chelis reef build
chelis test tests/ --timeout 600 --jobs auto
chelis test tests_neg/ --expect neg
uv sync --project parity --frozen
uv run --project parity --frozen python parity/run_parity.py --strict
uv run --python 3.11 --no-project python scripts/run_static_checks.py
uv run --python 3.11 --no-project python scripts/test_parity_contract.py
uv run --python 3.11 --no-project python scripts/test_release_workflow.py
uv run --python 3.11 --no-project python scripts/repro_native_nan.py
uv run --python 3.11 --no-project python scripts/repro_native_neq.py
uv run --python 3.11 --no-project python scripts/repro_native_drop_nan_blocked.py
chelis reef conform audit
chelis reef conform bump-check --base origin/main
```

When you change documentation, also run the example validators, which
type-check and build every complete ```` ```chelis ```` block in `SKILL.md` and
the book against the pinned compiler:

```sh
uv run --python 3.11 --no-project python scripts/run_skill_checks.py
uv run --python 3.11 --no-project python scripts/validate_book_examples.py
```

A compiler upgrade additionally runs the native-lane probes listed in
[`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md#re-probing), including
`scripts/repro_package_frame_build.py` and all three targets of
`scripts/repro_multimodule_bare_build.py`. Run the documentation validators
above on every compiler upgrade, including one without prose edits.

## Continuous integration

`ci.yml` runs on every pull request and every push to `main`:

1. **Pin and conformance guard.** `chelis reef conform audit` (the Chelis
   shell-repository conformance check), the release-workflow contract tests,
   `chelis reef conform bump-check`, which rejects a compiler pin change that
   skipped the upgrade checklist, and a check that every workflow's compiler,
   Nautilus, and Coral versions match `reef.toml`.
2. **Hard rules.** No Python under `tests/`, no pandas or SciPy in `src/` or
   `tests/`, and a non-empty native suite.
3. **Tests and parity**, run in parallel after the hard rules: the native,
   negative, and blocked suites plus the native NaN probes; and the static
   checks, example validators, and strict pandas parity. On pushes to `main`,
   a macOS job also builds the package.

`release.yml` builds, verifies, and publishes the release artifacts when a
`v*` tag is pushed; see [`docs/releases.md`](releases.md).

## Adding or changing public functions

- Export the function from its module and add it to [`SKILL.md`](../SKILL.md)
  §5 and the matching book chapter under [`docs/src/`](src/SUMMARY.md).
- Test every new public function on at least two distinct shapes or
  configurations. Where pandas defines the behavior, add a golden to
  `parity/gen_goldens.py`, regenerate, and review the new JSON.
- Pin every rejection the function promises with a case under `tests_neg/`.
- A deliberate narrowing (a `fail(...)` on input pandas accepts, an
  unsupported column type) cites either an upstream issue as `chelis#NNN` or a
  deferral in [`spec/scope.md`](../spec/scope.md#deferrals) at the narrowing
  site.

## Upstream compiler issues

When a Chelis limitation forces a workaround, search the
[Chelis tracker](https://github.com/Chelis-Lang/chelis/issues) for an existing
report, file one if there is none, and cite it as `chelis#NNN` at the
workaround site. Record it in [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md),
and add a reproducer under `tests_blocked/` when the test harness can express
one. `chelis reef conform audit` checks the citations.
[`docs/CHELIS_SURFACE.md`](CHELIS_SURFACE.md) lists what the pinned
compiler and standard library provide; read it before designing around a
suspected language gap.

## Upgrading the Chelis compiler

A compiler upgrade is a pull request that runs the checklist in
[`AGENTS.md`](../AGENTS.md#pin-bump-checklist). It starts with
`chelis reef conform bump <version>`, which updates every pin in lockstep,
after Nautilus has published a release for the same compiler. It then
re-probes every open upstream issue, promotes any fixed reproducer from
`tests_blocked/` into `tests/`, removes the corresponding workaround, and runs
the full local gate.
