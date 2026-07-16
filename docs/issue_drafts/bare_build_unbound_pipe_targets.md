# Draft: `chelis build` accepts unbound `|>` pipe targets in large concatenated programs and emits implicit C externs

**Target:** `Chelis-Lang/chelis`
**Filing condition:** narrow to a minimal reproducer first. Single-reference
minimal cases are correctly rejected with `UnboundVariable`, so the report is
not actionable until the scale/context trigger is isolated. Do not file as-is.

## Observed (chelis 0.16.1, macOS arm64)

While coral's bare-build triage probe
(`scripts/repro_multimodule_bare_build.py`) still had a name-prefixing bug —
its `apply_name_map` only rewrote `name(` / `name[` call sites, so
pipe-position references (`x |> log_gamma_core |> exp`) and first-class
references kept their original, now-undefined names — `chelis build` on the
resulting ~2,000-line single-file concat (coral frame/groupby/join +
nautilus special/distributions/stats, ~13 unbound references in pipe
position):

- exited rc=0 with no `UnboundVariable` diagnostic, and
- emitted C that calls the unbound names as undeclared functions
  (`log_gamma_core(...)`, `bitpos(...)`, `popcount_i64(...)`,
  `has_value(...)`, …), so the native compile failed downstream with
  `-Wimplicit-function-declaration` errors.

## Expected

Every unbound reference — pipe-position or otherwise — is rejected at check
time, as the minimal cases are:

```chelis
def helper(x: f32) -> f32 = mul(x, x)
def main() -> f32 = cast(2.0, f32) |> undefined_fn
```

```
error: Check errors: Type errors: [CheckError { kind: UnboundVariable,
message: "unbound variable: undefined_fn", ... }]
```

The same correct rejection occurs with the unbound pipe target inside a
nested `if` branch of a non-`main` function. `chelis test tests_neg/` in
coral pins the single-reference rejection
(`tests_neg/frame/unbound_function_neg.ch`).

## Reproduction of the anomalous acceptance

In `Chelis-Lang/coral`, check out `scripts/repro_multimodule_bare_build.py`
from immediately **before** the whole-word `apply_name_map` fix in the
chelis-0.16.1 pin-bump change set (coral PR #18), then:

```sh
python3 scripts/repro_multimodule_bare_build.py --target groupby
```

`chelis build` succeeds; the native `gcc` step fails on the implicit
declarations listed above.

## Why it matters

If the admission is real (not an artifact of the probe environment), a
whole-program build can pass checking while referencing symbols that do not
exist, deferring the failure to the C toolchain — or, worse, linking against
an unrelated symbol if one happens to exist. Soundness of check-time name
resolution should not depend on program size.
