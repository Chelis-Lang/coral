# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.5 (sha256:28011bed9ccb5778) -->
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
| Validated manifest | Coral `0.7.39`; `reef.toml` pins compiler `=0.18.5`, `chelis-std 0.4.0`, and Nautilus `0.7.41` |
| Published compiler | official `chelis 0.18.5` at tag commit `6602f01719f55b8d4c7f52ee70e7c7b58f136107`; Darwin arm64 archive SHA-256 `0ff7b4e168d8b51277e05d44bfa658364630176d56d79c9cf8aceaea15335551`; extracted binary SHA-256 `bcf8da8bd2df9acb8816194f9251b26e23ec57527d4fc928bea6e1f6120628b2` (the glibc-2.31 archive for the same tag is SHA-256 `6b9b944ccd96b0053fc071de0ecfbb9e80e02a07a6a176e87056267ae8e0c26a`, extracted binary `fc544b9362c9ff0c244c03216a6e44fbf4d36665802d11b5cf3514d017c1e29a`, verified against its sidecar but exercised by CI rather than this gate run) |
| Reef dependency | official `nautilus 0.7.41` at tag commit `5bf6fd11ea4faa5bec0ca79e8974653b5e3158f8`; its sidecar-verified CHB has SHA-256 `e92a47020f5691b49e5b39aba0094c7e1ed2e39d9dce55a9a135fd34480cc083` and its archive has SHA-256 `1bba785ccead8c38275f8daa111a27516b4f21d16eb3223c23dbb7bcb6a0a6f3`, taken from the published sidecar per chelis#1002. **That artifact declares `compiler = "=0.18.4"`, so reef's exact-pin equality check refuses it at coral's `=0.18.5` pin.** Nautilus source at the same commit builds clean at `=0.18.5` with only the pin flipped; this gate ran against such a rebuild in a private registry, and a re-cut Nautilus release is the only thing outstanding |
| Last refreshed | 2026-08-22 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact official 0.18.5 / 0.7.41 chain. `@upstream` means the capability
is unavailable at that validated pin and must be re-probed before de-narrowing.

This is the Coral-scoped view of the
[canonical Chelis inventory at the published target tag commit](https://github.com/Chelis-Lang/chelis/blob/29700dd73c0e35b672bdd384493054b3107ce308/docs/CHELIS_SURFACE.md).
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
| Borrowing and linearity | v0.14.0 enforces left-to-right evaluation order for linearity: consuming reads (`index(xs, i)`) must be bound with `let` before a `drop(xs, ...)` in the same expression. `src/` was rewritten for this at the 0.14.0 bump and stays clean on the 0.18.5 release. | `@pin` |

### Primitive and builtin families used by Coral

| Family touched by `src/` | Names used by Coral | Lane and architectural consequence | Status |
|---|---|---|---|
| Elementwise arithmetic | `add`, `sub`, `mul`, `div` | Aggregations, window recurrences (rolling/ewm), and describe statistics. Float `div` follows IEEE-754; Coral manufactures NaN as `div(0.0, 0.0)` (`nan_f32`). | `@pin` |
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Row filtering, join keys, sort comparators, NaN detection. The 0.18.5 pin supports tensor-bool `not`, but float tensor `neq` is still IEEE-wrong for NaN in native C and borrowed/borrowed `neq` still selects the f32 overload. Float `is_nan` therefore uses an O(n) scalar host-map (`chelis#630`); integer masks and mask inversion use tensor `not` directly. | `@pin` |
| Host-list operations | `len`, `index`, `append`, `drop`, `range`, `map`, `fold`, `filter` | Coral's Frame algorithms are host-list-first; tensors are used for bulk payloads. Host lists retain `len`; tensor row counts use O(1) `numel`. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Column payloads round-trip between tensors (storage/gather) and host lists (algorithms). Empty-tensor `numel` correctly returns zero on 0.18.5, so Frame and IO row counts use it directly. Valid on eval, package, and bare-C lanes. | `@pin` |
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
| Evaluator (`chelis test`) | The 75-test positive suite (`tests/*.ch`) and 4-case negative suite (`tests_neg/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Native C build (`chelis build` + native link) | Not a shipping lane. **Frame construction now lowers.** On 0.18.5, a package-lane entry that calls `from_pairs` and reads `ncols` builds, links, runs, and matches `chelis eval`; through 0.18.4 a `Frame` could not be constructed at all (`chelis#941`). Frame *reads* that pull a column back out of the HAMT do not lower: `nrows` stops at `column_len` (`chelis#1226`) and `drop_nan` at an unresolved `Column` match (`chelis#1260`). Both directions are pinned by `scripts/repro_package_frame_build.py`. Stripped Frame/GroupBy/Join modules with a trivial constant entrypoint still build, link, and start, and a separate native regression executes the float NaN mask/drop-core/count/any path. The syntactic-axis constraint above also remains in force. | `@pin` |
| `grad` / AD | Not part of Coral's surface: `grad` through Coral's host-list algorithms is not an advertised capability, and host-lane scalar AD remains a deferred upstream item (`UPSTREAM_BUGS` §Parked). Doc usage stays illustrative. | `@pin` |
