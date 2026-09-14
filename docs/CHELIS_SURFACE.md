# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.9 (sha256:28011bed9ccb5778) -->
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
| Validated manifest | Coral `0.7.41`; `reef.toml` pins compiler `=0.18.9`, `chelis-std 0.4.0`, and Nautilus `0.7.44`. The regenerated local `reef.lock` binds both dependencies to `=0.18.9`. `chelis reef build` produces CHB SHA-256 `cafd7fac4d66a4b8a1302cbdee63b2c9d711355f2fc42619947a69f7e0cea010` and archive SHA-256 `50c8a61c3a7b0d3a87c979566ec3e38fc14c5d35a38bcf7a4b116249ce5470ee`. The `v0.7.41` release is pending publication, so these are the local gate build outputs and are not yet checked against published `v0.7.41` release assets |
| Published compiler | official `chelis 0.18.9` at tag commit `abff07b47eadc8d2be633e3a7d21220089befb6f`; Darwin arm64 archive SHA-256 `44e12cf187b37cb6d2a617e1573832a1bdcaa0e1564f59c4029e24081a84905d`; extracted binary SHA-256 `68e460df6e796891fb30c42904b0309b4d5e83d187944222faaaae63241101c7`. This gate ran on the **installed** toolchain payload extracted from that archive at `chelis-v0.18.9-darwin-arm64/bin/chelis`, byte-identical to the archive's `bin/chelis`. Linux glibc-2.31 assets for the same tag, sidecar-verified but exercised by CI rather than this gate run: archive `9aed0afbfc93a96a6804b4c82664869d74815bd27ca824dfeab02088b00ddb63` / binary payload `efe99c09f5d7d7372065206a332a2fd86b8aee77412262b0028cfbdbc98a19f2` (the default for `install-chelis` and the asset `release.yml` names) |
| Reef dependency | `nautilus 0.7.44`, **published** at source commit `aa50d1c7c911dbebb3f379c0a86b6690b139b9af`. Release assets verified against the sidecar: CHB SHA-256 `58a02e90957bf36cdfa0e995a7c14c397790956b6e6d0bbb060caea2d4b399c1`, archive SHA-256 `8c7a9d79a4fad87340e58bce06525cb2210c3344acf09bca03efe489a16d2bb0`. Installed with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.44`, the same path CI uses; the cascade validated against the isolated `CHELIS_REEF_HOME` registry while the sibling release was fresh. `describe` and the GroupBy aggregations link against it |
| Last refreshed | 2026-09-14 |

`@pin` means the row describes behavior available (or a limitation verified)
on the exact 0.18.9 / 0.7.44 chain. `@upstream` means the capability
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
