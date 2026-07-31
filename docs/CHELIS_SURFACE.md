# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.17.5 (sha256:28011bed9ccb5778) -->
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
| Validated manifest | Coral `0.7.34`; `reef.toml` pins compiler `=0.17.5`, `chelis-std 0.4.0`, and Nautilus `0.7.37` |
| Published compiler | official `chelis 0.17.5` at tag commit `333cb4d3688573036d37828eba68416c11c5d1b4`; glibc-2.31 archive SHA-256 `65f5949a540a547aacbee9845b3d40d2a02d1b28e3c8d608fc7af140fafd6ccf`; extracted binary SHA-256 `9728e7824cd5d8aba26daf5189f95b90c98f9636b8aa0b6ca2fe9cc286c44801` |
| Reef dependency | official `nautilus 0.7.37` at tag commit `1b932d75ed4d03a53f90b2093f0801992e963050`; CHB SHA-256 `daeb7a4a3cef0f3c98e06c048998cd207a9aa372d161e7c115e430068ecbdd1d`; archive SHA-256 `d5a861566850a0706aae07f68b21bc2eecdd0dfcedafbe26a0083447fa24143b`; sidecar-file SHA-256 `e72adb65a3707745751836217b5f8e29095424a279d464332e7284f59fb8f3a3` |
| Last refreshed | 2026-07-31 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact official 0.17.5 / 0.7.37 chain. `@upstream` means the capability
is unavailable at that validated pin and must be re-probed before de-narrowing.

This is the Coral-scoped view of the
[canonical Chelis inventory at the published target tag commit](https://github.com/Chelis-Lang/chelis/blob/333cb4d3688573036d37828eba68416c11c5d1b4/docs/CHELIS_SURFACE.md).
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
| Borrowing and linearity | v0.14.0 enforces left-to-right evaluation order for linearity: consuming reads (`index(xs, i)`) must be bound with `let` before a `drop(xs, ...)` in the same expression. `src/` was rewritten for this at the 0.14.0 bump and stays clean on the 0.17.5 release. | `@pin` |

### Primitive and builtin families used by Coral

| Family touched by `src/` | Names used by Coral | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div` | Aggregations, window recurrences (rolling/ewm), and describe statistics. Float `div` follows IEEE-754; Coral manufactures NaN as `div(0.0, 0.0)` (`nan_f32`). | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Row filtering, join keys, sort comparators, NaN detection. `not` is scalar-only on the pinned release (`UPSTREAM_BUGS` §Tracking); bool-tensor complements are reformulated through list maps. | `@pin` |
| Host-list operations | `len`, `index`, `append`, `drop`, `range`, `map`, `fold`, `filter` | Coral's Frame algorithms are host-list-first; tensors are used for bulk payloads. `len(to_list(xs))` is the row-count path because `numel(to_tensor([]))` returns 1 upstream (`UPSTREAM_BUGS` §Tracking). | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Column payloads round-trip between tensors (storage/gather) and host lists (algorithms). Valid on eval, package, and bare-C lanes. | `@pin` |
| Tensor movement | `gather`, `sort` | Row selection (`head`/`tail`/`slice`, sort-permutation application) and sort-by. **Bare-lane constraint**: the axis argument must be a syntactic literal or inline `cast(<int>, int32)`; a helper call defeats rank monomorphization in bare `chelis build` (`UPSTREAM_BUGS` §Tracking) — which is why `frame.ch` inlines `cast(0, int32)` at every axis site. Package/test lanes are indifferent. | `@pin` |
| String ordering | `str_lt`, `str_lt_pos`, `str_char_lt` | Lexicographic sort-by on `StringCol` and stable key ordering in GroupBy/Join. | `@pin` |
| Failure | `fail` | Guard rails for schema mismatches and the intentional Parquet stubs (`read_parquet_frame` / `write_parquet_frame`). | `@pin` |

### Standard library and reef dependencies

| Surface | Used by Coral | Status |
|---|---|---|
| `Std.Io` (`write_text`) + `Std.Io.Csv` (`read_csv`) | CSV read path and all file writes (CSV/JSON emit via `write_text`). Round-trips are golden-tested against pandas in `parity/`. | `@pin` |
| `Std.Io.Json` (`Json` ADT, `load_json`, `json_array`, `json_object`) | JSON read/write for `Coral.Io`. | `@pin` |
| `Std.Io.Parquet` | **Signatures only.** Import checks clean but there is no runtime backing (no symbol in `libchelis_runtime.a`, re-probed at 0.16.1); Coral ships intentional `fail(...)` stubs (`UPSTREAM_BUGS` §Parked). | `@pin` |
| `Nautilus.Stats` (`mean_vec`, `min_vec`, `max_vec`, `quantile_vec`, `std_vec`) | `describe` and GroupBy aggregations delegate scalar statistics to nautilus. The reef dep must carry the same compiler pin as coral — bump order is nautilus first. | `@pin` |

### Lanes

| Lane | Coral usage | Status |
|---|---|---|
| Evaluator (`chelis test`) | The 71-test positive suite (`tests/*.ch`) and negative suite (`tests_neg/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Bare C build (`chelis build` + native link) | Not a shipping lane; the stripped Frame/GroupBy/Join probes build, link, and run on the official 0.17.5 / Nautilus 0.7.37 chain after chelis#935. The syntactic-axis constraint above remains in force. | `@pin` |
| `grad` / AD | Not part of Coral's surface: `grad` through Coral's host-list algorithms is not an advertised capability, and host-lane scalar AD remains a deferred upstream item (`UPSTREAM_BUGS` §Parked). Doc usage stays illustrative. | `@pin` |
