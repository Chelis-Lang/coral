# Chelis Capability Surface (this shell)

<!-- BEGIN CHELIS MANAGED BLOCK: chelis-surface-header chelis@0.18.12 (sha256:28011bed9ccb5778) -->
This file is a domain-scoped view of the canonical Chelis capability surface,
generated for the pinned toolchain. Each capability row is marked `@pin` (usable
at the current pin) or `@upstream` (lands at the next bump). **Read it before
designing around a suspected language gap** — most downstream over-narrowing
traces to not knowing the real surface. Regenerate with `chelis reef conform
sync` at every pin bump; the upstream source of truth is `docs/CHELIS_SURFACE.md`
in `Chelis-Lang/chelis`.
<!-- END CHELIS MANAGED BLOCK: chelis-surface-header -->

## Version scope

Coral pins Chelis **0.18.12** (`compiler = "=0.18.12"` in `reef.toml`)
and depends on Nautilus **0.7.47**, the published release built for that
compiler.

| Artifact | Identity |
|---|---|
| Chelis `v0.18.12` | tag commit `c81d8188de6ebad032c1bb1c0a427eb0408feee3` |
| `chelis-v0.18.12-linux-x86_64-glibc2.31.tar.gz` (CI) | SHA-256 `f82ab4e2a9667cc08047a2732d61aec02501d29c9355b195bee6a64186a81c66` |
| `chelis-v0.18.12-darwin-arm64.tar.gz` | SHA-256 `8cdcbf598c3f04e37a9a211e7abaa67fbaf6d4c135a34f00c1944b1e43b8e90d` |
| Nautilus `v0.7.47` | commit `76a66ae921cafeef538e1ff48ea53fdc253c1724` |
| `nautilus-0.7.47.chb` | SHA-256 `cd5c04ecfcd2445b7f7a7e0a997d721f20c85aac4524ae626571c3db96008603` |
| `nautilus-0.7.47.tar.zst` | SHA-256 `dfe18e834c2d6e49282afd682e0452e51575c3d1dcefd4db3267098e98bba716` |

The archive hashes match the publisher's `.sha256` sidecars on each release.

`@pin` rows describe what Coral uses at this pin, within the checks Coral
runs; they do not claim gradient or GPU support (see
[`spec/scope.md`](../spec/scope.md#deferrals)). `@upstream` capabilities need
a fresh probe before use. The
[canonical inventory](https://github.com/Chelis-Lang/chelis/blob/v0.18.12/docs/CHELIS_SURFACE.md)
owns the compiler-wide surface. Last refreshed: 2026-10-01.

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
| Comparisons and logic | `eq`, `neq`, `lt`, `lte`, `gt`, `gte`, `and`, `or`, `not` | Row filtering, join keys, sort comparators, NaN detection. `is_nan` is `neq(col, col)` on a float tensor, which is IEEE-correct at NaN in both the evaluator and native C (`scripts/repro_native_neq.py`). Borrowed/borrowed `neq` infers `tensor[n, bool]` (`tests/types.ch`). Integer masks and mask inversion use tensor `not` directly. Tensor operands must have matching shapes; there is no tensor/scalar comparison, so scalar thresholds are mapped over the elements (`tests_neg/frame/tensor_scalar_gt_neg.ch`). | `@pin` |
| Host-list operations | `len`, `index`, `append`, `skip`, `range`, `map`, `fold`, `filter` | Coral's Frame algorithms are host-list-first; tensors are used for bulk payloads. Host lists retain `len`; tensor row counts use O(1) `numel`. | `@pin` |
| Tensor/host bridges and queries | `to_tensor`, `to_list`, `numel` | Column payloads round-trip between tensors (storage/gather) and host lists (algorithms). Empty-tensor `numel` returns zero, so Frame and IO row counts use it directly. | `@pin` |
| Tensor movement | `gather`, `sort` | Row selection (`head`/`tail`/`slice`, sort-permutation application) and sort-by. **Constraint** (chelis#741): `gather` needs a literal or inline `cast(<int>, i32)` axis; the helper form remains blocked. The `sort` helper form works at this pin, so `frame.ch` calls `axis_zero()` at its three numeric sort sites. The gather rejection is pinned by `tests_blocked/lowering/gather_axis_helper.ch`, and `tests/internal.ch` exercises the sort helper. | `@pin` |
| String ordering | `str_lt`, `str_lt_pos`, `str_char_lt` | Lexicographic sort-by on `StringCol` and stable key ordering in GroupBy/Join. | `@pin` |
| Failure | `fail` | Guard rails for schema mismatches and the intentional Parquet stubs (`read_parquet_frame` / `write_parquet_frame`). | `@pin` |

### Standard library and reef dependencies

| Surface | Used by Coral | Status |
|---|---|---|
| `Std.Io` (`write_text`) + `Std.Io.Csv` (`read_csv`) | CSV read path and all file writes (CSV/JSON emit via `write_text`). Round-trips are golden-tested against pandas in `parity/`. | `@pin` |
| `Std.Test` (`assert_true`, `assert_false`, `assert_eq`, `assert_close`) | The whole `tests/` suite. `assert_eq` is generic over the compared type; `assert_close` is restricted to the active float types, which Coral's `f32` tolerances satisfy. Coral uses neither `assert_close_tensor` nor `assert_eq_tensor`. | `@pin` |
| `Std.Io.Json` (`Json` ADT, `load_json`, `json_array`, `json_object`) | JSON read/write for `Coral.Io`. An integer token outside `i64` range ingests as `JsonBigInt(string)` carrying its exact decimal spelling. `Coral.Io.render_json_value` matches all eight `Json` variants explicitly rather than through a wildcard, so a future variant is a compile error here instead of a silently empty cell; `tests/io.ch` pins the exact-digit passthrough and the resulting column inference. | `@pin` |
| `Std.Io.Parquet` | **Signatures only** (chelis#850). The import checks clean, but `libchelis_runtime.a` has no Parquet symbol (re-probed at 0.18.11); Coral ships intentional `fail(...)` stubs (`UPSTREAM_BUGS` §Parked). | `@pin` |
| `Nautilus.Stats` (`mean_vec`, `min_vec`, `max_vec`, `quantile_vec`, `std_vec`) | `describe` delegates its summary statistics to Nautilus; the GroupBy aggregations are Coral's own. Reef requires the dependency to declare the same compiler pin as Coral, so Nautilus is bumped first. | `@pin` |

### Lanes

| Lane | Coral usage | Status |
|---|---|---|
| Evaluator (`chelis test`) | The positive suite (`tests/*.ch`), the negative suite (`tests_neg/`), and the blocked-probe suite (`tests_blocked/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Native C build (`chelis build` + native link) | Not a shipping lane. Construction plus `ncols`, `nrows`, and a match on a retrieved column build, link, run, and agree with eval in package-context probes. Invoked `drop_nan` and stripped Frame/GroupBy/Join smokes still stop at chelis#730. The earlier chelis#1226 `nrows` instance cleared; chelis#2097 is masked in the stripped smokes. Native float-NaN and Window parity regressions pass on bare tensors; they do not prove full Frame lowering. | `@pin` |
| `grad` / AD | Not part of Coral's surface. Scalar `grad` builds natively at this pin (chelis#405 is archived), but Coral makes no claim that `grad` differentiates through its host-list algorithms (`spec/scope.md` deferral D5). | `@pin` |
