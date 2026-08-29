# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.6 (sha256:28011bed9ccb5778) -->
This file is a domain-scoped view of the canonical Chelis capability surface,
generated for the pinned toolchain. Each capability row is marked `@pin` (usable
at the current pin) or `@upstream` (lands at the next bump). **Read it before
designing around a suspected language gap** — most downstream over-narrowing
traces to not knowing the real surface. Regenerate with `chelis reef conform
sync` at every pin bump; the upstream source of truth is `docs/CHELIS_SURFACE.md`
in `Chelis-Lang/chelis`.
<!-- END CHELIS MANAGED BLOCK: chelis-surface-header -->

## Version scope

| Item | Value |
|---|---|
| Validated manifest | Coral `0.7.40`; `reef.toml` pins compiler `=0.18.6`, `chelis-std 0.4.0`, and Nautilus `0.7.43` |
| Published compiler | **not published yet.** The annotated `v0.18.6` tag resolves to commit `cf49f85bf0d1bca2c87c88a3e459c446912189c0`, but the release workflow for that tag was still running when this gate was produced, so no publisher-checksummed archive or sidecar exists to quote. This gate ran on a `chelis 0.18.6` binary built from the release branch head `1186231f96e8b3c491f576c07fd0e4d5709772df`, whose tree is byte-identical to the tag commit, with binary SHA-256 `ab979f8c064bd0c25a15ed757ca2a0dda8241b82a7b0f1b8144e5062ebf52e00`. That is a local build and carries no publisher checksum; replace this row with the release identities and re-run the gate before tagging Coral `0.7.40` |
| Reef dependency | `nautilus 0.7.43`, **staged, not yet published**. It is the version the Nautilus 0.18.6 bump declares (that change moves the package version and the compiler pin in one manifest), so pinning it now makes this change set correct as written the moment the cascade tags. Until then reef has nothing to resolve and `chelis reef build` fails in CI. Validated here against an artifact built from the Nautilus `chore/chelis-0.18.6` working tree at base commit `f209413cba4b10e43014ae61f402b69ee84c04b2` into a private registry: CHB SHA-256 `99cfc7e0700cdf7f884a71a2752e8916fe3255836b92c698eb9fe26513e27cb3`, archive SHA-256 `884f582328667a1617ad7b7aa371d96b6f99279e7e4c20700591dfde4d9fa306`. Those are local-build hashes and carry no publisher checksum; replace them with the release sidecar values when v0.7.43 is tagged |
| Last refreshed | 2026-08-29 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact 0.18.6 / 0.7.43 chain. `@upstream` means the capability
is unavailable at that validated pin and must be re-probed before de-narrowing.

This is the Coral-scoped view of the
[canonical Chelis inventory at the target tag commit](https://github.com/Chelis-Lang/chelis/blob/cf49f85bf0d1bca2c87c88a3e459c446912189c0/docs/CHELIS_SURFACE.md).
The tag, asset, and binary identities pin the acceptance evidence.
Version-sensitive limitation rows below resolve to the probes or manual
re-probe records cited in [`docs/UPSTREAM_BUGS.md`](UPSTREAM_BUGS.md).

## Capability inventory

### Types, dimensions, and ownership

| Capability | Coral consequence | Status |
|---|---|---|
| Active scalar precisions | Chelis admits `f32`, `f64`, `bf16`, `f16`, signed integers, `bool`, and `string`. Coral's column payloads are deliberately `f32` (`FloatCol`), `int64` (`IntCol` values + mask), `bool` (`BoolCol`), and `string` (`StringCol`); counts and row indices are `int64`. | `@pin` |
| Literals, casts, and promotion | Unsuffixed floats default to `f32` and integers to `int32`; there is no implicit promotion — `cast` is explicit everywhere Coral crosses widths (`cast(0, int32)` axis args, `cast(x, int64)` counts, `cast(v, f32)` payloads). | `@pin` |
| Algebraic data types and match | `Column` / `Frame` / `KeyValue` / `Json` are ADTs consumed by exhaustive `match`. This is the backbone of every per-column-type dispatch in `frame.ch`, `groupby.ch`, `join.ch`, `reshape.ch`, and `io.ch`. | `@pin` |
| Symbolic dimensions | `Column[n]` / `Frame[n]` / `tensor[n, f32]` carry a symbolic row count through the whole public API; call sites instantiate `n` by unification, and shape changes (`head`, `tail`, `slice`, joins, reshape) introduce fresh dims (`Column[k]`). | `@pin` |
| Borrowing and linearity | v0.14.0 enforces left-to-right evaluation order for linearity: consuming reads (`index(xs, i)`) must be bound with `let` before a `drop(xs, ...)` in the same expression. `src/` was rewritten for this at the 0.14.0 bump and stays clean on the 0.18.6 release. | `@pin` |

### Primitive and builtin families used by Coral

| Family touched by `src/` | Names used by Coral | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div` | Aggregations, window recurrences (rolling/ewm), and describe statistics. Float `div` follows IEEE-754; Coral manufactures NaN as `div(0.0, 0.0)` (`nan_f32`). | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Row filtering, join keys, sort comparators, NaN detection. The 0.18.6 pin supports tensor-bool `not`, and borrowed/borrowed `neq` now infers `tensor[n, bool]` (pinned by `tests/types.ch`). Float tensor `neq` is still IEEE-wrong for NaN in native C, so float `is_nan` keeps its O(n) scalar host-map (`chelis#630`, triggered by `scripts/repro_native_neq_blocked.py`); integer masks and mask inversion use tensor `not` directly. | `@pin` |
| Host-list operations | `len`, `index`, `append`, `drop`, `range`, `map`, `fold`, `filter` | Coral's Frame algorithms are host-list-first; tensors are used for bulk payloads. Host lists retain `len`; tensor row counts use O(1) `numel`. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Column payloads round-trip between tensors (storage/gather) and host lists (algorithms). Empty-tensor `numel` correctly returns zero on 0.18.6, so Frame and IO row counts use it directly. Valid on eval, package, and bare-C lanes. | `@pin` |
| Tensor movement | `gather`, `sort` | Row selection (`head`/`tail`/`slice`, sort-permutation application) and sort-by. **Bare-lane constraint**: the axis argument must be a syntactic literal or inline `cast(<int>, int32)`; a helper call defeats rank monomorphization in bare `chelis build` (`UPSTREAM_BUGS` §Tracking) — which is why `frame.ch` inlines `cast(0, int32)` at every axis site. Package/test lanes are indifferent. | `@pin` |
| String ordering | `str_lt`, `str_lt_pos`, `str_char_lt` | Lexicographic sort-by on `StringCol` and stable key ordering in GroupBy/Join. | `@pin` |
| Failure | `fail` | Guard rails for schema mismatches and the intentional Parquet stubs (`read_parquet_frame` / `write_parquet_frame`). | `@pin` |

### Standard library and reef dependencies

| Surface | Used by Coral | Status |
|---|---|---|
| `Std.Io` (`write_text`) + `Std.Io.Csv` (`read_csv`) | CSV read path and all file writes (CSV/JSON emit via `write_text`). Round-trips are golden-tested against pandas in `parity/`. | `@pin` |
| `Std.Test` (`assert_true`, `assert_false`, `assert_eq`, `assert_close`) | The whole `tests/` suite. 0.18.6 removes the `assert_eq_int` / `assert_eq_bool` / `assert_eq_string` aliases and makes `assert_eq[q]` generic, so all three collapse into `assert_eq`; there is no alias to fall back on. `assert_close[p_float]` now carries the active-float restriction, which Coral's f32-only tolerances satisfy. Coral uses neither `assert_close_tensor` nor `assert_eq_tensor`. | `@pin` |
| `Std.Io.Json` (`Json` ADT, `load_json`, `json_array`, `json_object`) | JSON read/write for `Coral.Io`. 0.18.6 adds the `JsonBigInt(string)` variant (chelis#1314): an integer token outside `int64` range now ingests carrying its exact decimal spelling instead of trapping `Overflow`, so `read_json_frame` accepts documents it used to reject. `Coral.Io.render_json_value` matches all eight variants explicitly rather than through a wildcard, so a future variant is a compile error here instead of a silently empty cell; `tests/io.ch` pins both the exact-digit passthrough and the resulting column inference. | `@pin` |
| `Std.Io.Parquet` | **Signatures only.** Import checks clean but there is no runtime backing (no symbol in `libchelis_runtime.a`, re-probed at 0.16.1); Coral ships intentional `fail(...)` stubs (`UPSTREAM_BUGS` §Parked). | `@pin` |
| `Nautilus.Stats` (`mean_vec`, `min_vec`, `max_vec`, `quantile_vec`, `std_vec`) | `describe` and GroupBy aggregations delegate scalar statistics to nautilus. The reef dep must carry the same compiler pin as coral — bump order is nautilus first. | `@pin` |

### Lanes

| Lane | Coral usage | Status |
|---|---|---|
| Evaluator (`chelis test`) | The 78-test positive suite (`tests/*.ch`) and 4-case negative suite (`tests_neg/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Native C build (`chelis build` + native link) | Not a shipping lane. **Frame construction lowers; Frame reads still do not.** A package-lane entry that calls `from_pairs` and reads `ncols` builds, links, runs, and matches `chelis eval` (through 0.18.4 a `Frame` could not be constructed at all, `chelis#941`); `nrows` still stops at `column_len` (`chelis#1226`) and `drop_nan` at an unresolved `Column` match (`chelis#1260`). Both directions are pinned by `scripts/repro_package_frame_build.py`. Stripped Frame/GroupBy/Join modules with a trivial constant entrypoint still build, link, and run, and separate native regressions execute the float NaN mask/drop-core/count/any path and pin the surviving IEEE `neq` divergence. **0.18.6 changed this lane's entrypoint shape:** `chelis build` now emits its own `int main(void)` that evaluates every effect-free nullary definition and prints one `<name> = <value>` observation line (`chelis#1079`/`#1082`/`#1083`), it always exits zero, and it links against the platform vector-math library. Probes therefore run the compile command `chelis build` prints and read the entry's observation line instead of renaming the entry and supplying a driver. The syntactic-axis constraint above also remains in force. | `@pin` |
| `grad` / AD | Not part of Coral's surface: `grad` through Coral's host-list algorithms is not an advertised capability, and host-lane scalar AD remains a deferred upstream item (`UPSTREAM_BUGS` §Parked). Doc usage stays illustrative. | `@pin` |
