# Chelis 0.18.10 migration

Coral advances with the C Note dependency chain. This release requires the
published Chelis 0.18.10 and Nautilus 0.7.45, with the canonical compiler bump
and fresh compiler-bound artifacts. It is a repin change set: the compiler pin
advances `=0.18.9` -> `=0.18.10`, the Nautilus dependency advances `0.7.44` ->
`0.7.45`, and the Coral package version advances `0.7.41` -> `0.7.42`. The
`chelis reef conform bump 0.18.10` run advanced `reef.toml`, both workflow pin
mirrors, and the managed blocks in `AGENTS.md` and `docs/CHELIS_SURFACE.md`.

## chelis#2068 is fixed on 0.18.10 (native-C airy ownership)

0.18.7 introduced a native-C ownership/liveness regression
([chelis#2068](https://github.com/Chelis-Lang/chelis/issues/2068)): a by-value
owned scalar passed to two or more argument slots of a user call in
tail/return position was wrongly moved, so the native compile failed. Nautilus's
`special.ch::airy_gg` (and `distributions.ch::betacf`) hit it. **0.18.10 fixes
it.** Verified directly with the issue's own minimal repro:

```
def f3(a: f32, b: f32) -> f32 = add(a, b)
def g(x: f32) -> f32 = f3(x, x)
def main() -> f32 = g(cast(0.5, f32))
```

- `chelis build repro.ch --target c` on **0.18.9**: `error: owner %1 in `g` b1
  is not live` (rc=1).
- Same command on **0.18.10**: builds cleanly, emits C, links (rc=0).

Nautilus 0.7.45's own whole-package `chelis reef build` and sealed-artifact
contract are green on 0.18.10, which exercises `airy_gg` through the real build.

## Restoring the full multi-module native-NaN probe: attempted, blocked by chelis#2097

With #2068 fixed, restoring `scripts/repro_native_nan.py` to its full
`MODULE_PRESETS["frame"]` multi-module form (hamt + Nautilus
special/distributions/stats + frame) was attempted. It does **not** compile —
but not because of #2068. The full paste now surfaces a **separate,
pre-existing** native-C completeness gap in Coral's own `frame.ch`:

```
error: direct call in `frame__list_filter_string` does not match ownership signature of u226
```

`list_filter_string` threads a function-value parameter (`pred: string -> bool`)
through a direct call to `list_filter_string_acc`, which the native-C ownership
pass rejects. This is filed as
[chelis#2097](https://github.com/Chelis-Lang/chelis/issues/2097). It is **latent
since <= 0.18.6 and fails identically on 0.18.9 and 0.18.10 — it is not a
0.18.10 regression.** #2068 previously shadowed it (the full probe stopped at
the earlier airy error). It is the same diagnostic class as chelis#1732 (closed
for the *nullary* direct-call case), for the function-value-passing variant that
#1732 did not cover. Minimal standalone repro (deterministic, fails on both
0.18.9 and 0.18.10):

```
def zero_i64() -> int64 = cast(0, int64)
def one_i64() -> int64 = cast(1, int64)
def list_filter_string_acc(pred: string -> bool, items: List[string], acc: List[string]) -> List[string] =
  if eq(len(items), zero_i64()) then acc else {
    current = index(items, zero_i64())
    next = if pred(current) then append(acc, current) else acc
    list_filter_string_acc(pred, drop(items, one_i64()), next)
  }
def list_filter_string(pred: string -> bool, items: List[string]) -> List[string] = list_filter_string_acc(pred, items, [])
def main() -> int64 = cast(0, int64)
```

Coral therefore keeps its native-NaN canary **scoped to its own first-order
frame-NaN defs** (`zero_i64`, `one_i64`, `is_nan`, `any_nan`, `count_nan`,
`mask_to_index_list`) exactly as in 0.7.41. That slice is the code chelis#630
narrows (`is_nan`'s per-element `neq(x, x)` scalar host-map); the probe still
compile-links-runs it and reads the IEEE-correct NaN observation (`main = 0`).
Coral never calls `list_filter_string` through native-C in any shipping lane.

## Published toolchain identity

Chelis 0.18.10, tag `v0.18.10`, source commit
`b9095ccf2c0b76859aa447c6febe699fd287f1d2`, annotated tag object
`e247a5d33cd2df552f57e3efddfd4ea30846b3b8`, release run `34966582543`.

- Darwin arm64 archive SHA-256
  `80c9c5b42a8fbcee6884915df1a4dafb8bcc1cae33199ded060d8b2ebece8bf0`;
  extracted `bin/chelis` SHA-256
  `a6af380886b21761bc2822a814e4fef4232e8b8551922d32bca722cd4e04e1e2`. The gate
  ran on this installed Darwin payload.
- Linux glibc-2.31 archive SHA-256
  `0843697e0a7783e383df0347ae431ae56f62b5a5ae34a7aa72ac37ee91df1e0b`;
  compiler payload SHA-256
  `6622e40bc786c562b5b66d370a84e46ded551dee70abfc617a71d026c0119b00`. This is
  the CI toolchain default; its gate run is CI's.

Nautilus 0.7.45, tag `v0.7.45`, source commit
`563f2737c2988eaa05ca1e6ce4e941cf86c296b8`, annotated tag object
`f493395f6f07dd8a6afbf148b6cc1b7274947128`. Release assets verified against the
sidecar: CHB SHA-256
`b1d55d8cf751e548c5f56a15c3b4f268328139510a9101ab51ae433117134ba4`, archive
SHA-256 `4724b7b12ddc468f1db9ff327392d9437611f5f46834fe7e252fcf0db3010536`.
Installed with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.45`,
the path CI uses. The regenerated local `reef.lock` binds both `nautilus` and
`chelis-std 0.4.0` to compiler `=0.18.10`.

Coral 0.7.42 `chelis reef build` outputs, pending publication of the `v0.7.42`
release assets: CHB SHA-256
`73cd9ed7672de26b264a39eceb96b590067d7b1e04a8076e20e4e8f5d7347157`, archive
SHA-256 `fab2d8c5194e270c1979b0be202665762b0cafb55b32e92dbb25ecb0f7e5213a`.

## Validation status

The gate ran on the published Chelis 0.18.10 Darwin arm64 binary against
Nautilus 0.7.45. Every shipping and CI-gated lane passes: per-file
`fmt --check`, `lint --check .`, `reef build`, the native suite
`test tests/ --jobs auto`, `test tests_neg/ --expect neg`,
`test tests_blocked/ --expect blocked`, the strict pandas parity gate,
`run_static_checks.py`, `run_skill_checks.py`, `validate_book_examples.py`,
`reef conform audit --explain`, and `reef conform bump-check --base
origin/main` (pin change 0.18.9 to 0.18.10). The required `native float NaN
regression` step (`scripts/repro_native_nan.py`) compiles, links, runs, and
passes on 0.18.10 in its 0.7.41 narrowed scope (the chelis#630 guard). The
non-shipping full multi-module native bare-build lane remains blocked by
chelis#2097 as described above; it is not a shipping lane and not a CI gate.
