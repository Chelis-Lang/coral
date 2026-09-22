# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.11 (sha256:28011bed9ccb5778) -->
This file is a domain-scoped view of the canonical Chelis capability surface,
generated for the pinned toolchain. Each capability row is marked `@pin` (usable
at the current pin) or `@upstream` (lands at the next bump). **Read it before
designing around a suspected language gap** — most downstream over-narrowing
traces to not knowing the real surface. Regenerate with `chelis reef conform
sync` at every pin bump; the upstream source of truth is `docs/CHELIS_SURFACE.md`
in `Chelis-Lang/chelis`.
<!-- END CHELIS MANAGED BLOCK: chelis-surface-header -->

## Version scope

Coral 0.7.43 targets official Chelis 0.18.11 and published Nautilus 0.7.46.
The package build, 80 positive tests, six negative cases, one parser blocker,
executable documentation and strict pandas parity pass locally. Three non-shipping
bare-C module smokes remain blocked by chelis#2097.

[The migration receipt](chelis_0_18_11_migration.md) records compiler and dependency
identities, exact checks and remaining boundaries; the
[preceding receipt](chelis_0_18_10_migration.md) preserves historical evidence.
`@pin` describes the pinned surface within those bounded checks, not full phase,
AD or GPU acceptance. `@upstream` capabilities require a fresh probe before use.
The [canonical inventory](https://github.com/Chelis-Lang/chelis/blob/a7e592f88a148d8323b8f9a8f679c8e163ad3ee7/docs/CHELIS_SURFACE.md)
owns the compiler-wide surface. Last refreshed: 2026-09-21.

## Capability inventory

### Types, dimensions, and ownership

| Capability | Coral consequence | Status |
|---|---|---|
| Active scalar precisions | Chelis admits `f32`, `f64`, `bf16`, `f16`, signed integers, `bool`, and `string`. Coral's column payloads are deliberately `f32` (`FloatCol`), `i64` (`IntCol` values + mask), `bool` (`BoolCol`), and `string` (`StringCol`); counts and row indices are `i64`. | `@pin` |
| Literals, casts, and promotion | Unsuffixed floats default to `f32` and integers to `i32`; there is no implicit promotion — `cast` is explicit everywhere Coral crosses widths (`cast(0, i32)` axis args, `cast(x, i64)` counts, `cast(v, f32)` payloads). | `@pin` |
| Algebraic data types and match | `Column` / `Frame` / `KeyValue` / `Json` are ADTs consumed by exhaustive `match`. This is the backbone of every per-column-type dispatch in `frame.ch`, `groupby.ch`, `join.ch`, `reshape.ch`, and `io.ch`. | `@pin` |
| Symbolic dimensions | `Column[n]` / `Frame[n]` / `tensor[n, f32]` carry a symbolic row count through the whole public API; call sites instantiate `n` by unification, and shape changes (`head`, `tail`, `slice`, joins, reshape) introduce fresh dims (`Column[k]`). | `@pin` |
| Borrowing and linearity | Consuming reads must precede list traversal that consumes the same value. Coral binds those reads explicitly; the positive package suite validates the migrated paths. | `@pin` |

### Primitive and builtin families used by Coral

| Family touched by `src/` | Names used by Coral | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div` | Aggregations, window recurrences (rolling/ewm), and describe statistics. Float `div` follows IEEE-754; Coral manufactures NaN as `div(0.0, 0.0)` (`nan_f32`). | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Row filtering, join keys, sort comparators, NaN detection. The 0.18.6 pin supports tensor-bool `not`, and borrowed/borrowed `neq` now infers `tensor[n, bool]` (pinned by `tests/types.ch`). At 0.18.11, `scripts/repro_native_neq.py` verifies NaN self-inequality and finite/signed-zero equality in eval and native C. `is_nan` now uses tensor `neq` directly; the production native NaN regression also passes. Integer masks and mask inversion use tensor `not` directly. | `@pin` |
| Host-list operations | `len`, `index`, `append`, `skip`, `range`, `map`, `fold`, `filter` | Coral's Frame algorithms are host-list-first; tensors are used for bulk payloads. Host lists retain `len`; tensor row counts use O(1) `numel`. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Column payloads round-trip between tensors (storage/gather) and host lists (algorithms). Empty-tensor `numel` correctly returns zero on 0.18.6, so Frame and IO row counts use it directly. Valid on eval, package, and bare-C lanes. | `@pin` |
| Tensor movement | `gather`, `sort` | Row selection (`head`/`tail`/`slice`, sort-permutation application) and sort-by. **Bare-lane constraint**: the axis argument must be a syntactic literal or inline `cast(<int>, i32)`; a helper call defeats rank monomorphization in bare `chelis build` (`UPSTREAM_BUGS` §Tracking) — which is why `frame.ch` inlines `cast(0, i32)` at every axis site. Package/test lanes are indifferent. | `@pin` |
| String ordering | `str_lt`, `str_lt_pos`, `str_char_lt` | Lexicographic sort-by on `StringCol` and stable key ordering in GroupBy/Join. | `@pin` |
| Failure | `fail` | Guard rails for schema mismatches and the intentional Parquet stubs (`read_parquet_frame` / `write_parquet_frame`). | `@pin` |

### Standard library and reef dependencies

| Surface | Used by Coral | Status |
|---|---|---|
| `Std.Io` (`write_text`) + `Std.Io.Csv` (`read_csv`) | CSV read path and all file writes (CSV/JSON emit via `write_text`). Round-trips are golden-tested against pandas in `parity/`. | `@pin` |
| `Std.Test` (`assert_true`, `assert_false`, `assert_eq`, `assert_close`) | The whole `tests/` suite. 0.18.6 removes the `assert_eq_int` / `assert_eq_bool` / `assert_eq_string` aliases and makes `assert_eq[q]` generic, so all three collapse into `assert_eq`; there is no alias to fall back on. `assert_close[p_float]` now carries the active-float restriction, which Coral's f32-only tolerances satisfy. Coral uses neither `assert_close_tensor` nor `assert_eq_tensor`. | `@pin` |
| `Std.Io.Json` (`Json` ADT, `load_json`, `json_array`, `json_object`) | JSON read/write for `Coral.Io`. 0.18.6 adds the `JsonBigInt(string)` variant (chelis#1314): an integer token outside `i64` range now ingests carrying its exact decimal spelling instead of trapping `Overflow`, so `read_json_frame` accepts documents it used to reject. `Coral.Io.render_json_value` matches all eight variants explicitly rather than through a wildcard, so a future variant is a compile error here instead of a silently empty cell; `tests/io.ch` pins both the exact-digit passthrough and the resulting column inference. | `@pin` |
| `Std.Io.Parquet` | **Signatures only.** Import checks clean but there is no runtime backing (no symbol in `libchelis_runtime.a`, re-probed at 0.16.1); Coral ships intentional `fail(...)` stubs (`UPSTREAM_BUGS` §Parked). | `@pin` |
| `Nautilus.Stats` (`mean_vec`, `min_vec`, `max_vec`, `quantile_vec`, `std_vec`) | `describe` and GroupBy aggregations delegate scalar statistics to nautilus. The reef dep must carry the same compiler pin as coral — bump order is nautilus first. | `@pin` |

### Lanes

| Lane | Coral usage | Status |
|---|---|---|
| Evaluator (`chelis test`) | The 80-test positive suite (`tests/*.ch`) and six-case negative suite (`tests_neg/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Native C build (`chelis build` + native link) | Not a shipping lane. Package Frame construction plus `ncols` builds, links, runs and agrees with eval. The `nrows` probe still matches chelis#1226; invoked `drop_nan` still matches its host-inference boundary. All three stripped Frame/GroupBy/Join module smokes stop at chelis#2097's function-value ownership-signature mismatch. Separate native NaN and window regressions pass; they do not prove full Frame lowering. | `@pin` |
| `grad` / AD | Not part of Coral's surface: `grad` through Coral's host-list algorithms is not an advertised capability, and host-lane scalar AD remains a deferred upstream item (`UPSTREAM_BUGS` §Parked). Doc usage stays illustrative. | `@pin` |
