# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.10 (sha256:28011bed9ccb5778) -->
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
| Validated manifest | Coral `0.7.42`; `reef.toml` pins compiler `=0.18.10`, `chelis-std 0.4.0`, and Nautilus `0.7.45`. The regenerated local `reef.lock` binds both dependencies to `=0.18.10`. `chelis reef build` produces CHB SHA-256 `73cd9ed7672de26b264a39eceb96b590067d7b1e04a8076e20e4e8f5d7347157` and archive SHA-256 `fab2d8c5194e270c1979b0be202665762b0cafb55b32e92dbb25ecb0f7e5213a`. The `v0.7.42` release is pending publication, so these are the local gate build outputs and are not yet checked against published `v0.7.42` release assets |
| Published compiler | official `chelis 0.18.10` at tag commit `b9095ccf2c0b76859aa447c6febe699fd287f1d2` (annotated tag object `e247a5d33cd2df552f57e3efddfd4ea30846b3b8`); Darwin arm64 archive SHA-256 `80c9c5b42a8fbcee6884915df1a4dafb8bcc1cae33199ded060d8b2ebece8bf0`; extracted binary SHA-256 `a6af380886b21761bc2822a814e4fef4232e8b8551922d32bca722cd4e04e1e2`. This gate ran on the **installed** toolchain payload extracted from that archive at `chelis-v0.18.10-darwin-arm64/bin/chelis`, byte-identical to the archive's `bin/chelis`. Linux glibc-2.31 assets for the same tag, sidecar-verified but exercised by CI rather than this gate run: archive `0843697e0a7783e383df0347ae431ae56f62b5a5ae34a7aa72ac37ee91df1e0b` / binary payload `6622e40bc786c562b5b66d370a84e46ded551dee70abfc617a71d026c0119b00` (the default for `install-chelis` and the asset `release.yml` names) |
| Reef dependency | `nautilus 0.7.45`, **published** at source commit `563f2737c2988eaa05ca1e6ce4e941cf86c296b8` (annotated tag object `f493395f6f07dd8a6afbf148b6cc1b7274947128`). Release assets verified against the sidecar: CHB SHA-256 `b1d55d8cf751e548c5f56a15c3b4f268328139510a9101ab51ae433117134ba4`, archive SHA-256 `4724b7b12ddc468f1db9ff327392d9437611f5f46834fe7e252fcf0db3010536`. Installed with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.45`, the same path CI uses. `describe` and the GroupBy aggregations link against it |
| Last refreshed | 2026-09-15 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact 0.18.10 / 0.7.45 chain. `@upstream` means the capability
is unavailable at that validated pin and must be re-probed before de-narrowing.

This is the Coral-scoped view of the
[canonical Chelis inventory at the target tag commit](https://github.com/Chelis-Lang/chelis/blob/abff07b47eadc8d2be633e3a7d21220089befb6f/docs/CHELIS_SURFACE.md).
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
