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

Coral pins Chelis **0.18.11** (`compiler = "=0.18.11"` in `reef.toml`) and
depends on Nautilus **0.7.46**, the Nautilus release built for that compiler.

| Artifact | Identity |
|---|---|
| Chelis `v0.18.11` | tag commit `a7e592f88a148d8323b8f9a8f679c8e163ad3ee7` |
| `chelis-v0.18.11-linux-x86_64-glibc2.31.tar.gz` (CI) | SHA-256 `5b97fdf8d20582f022b945bccdc8020d222ad16cbc90047aa369e0d54fd3afd3` |
| `chelis-v0.18.11-darwin-arm64.tar.gz` | SHA-256 `386b2912d21f2b4a2fc6f7f42ab71625c5f1258b2d90c48c2e263b3fc435c289` |
| Nautilus `v0.7.46` | commit `ead1d65e2d7e5763e5c7f90e8c417aa36fd552e2` |
| `nautilus-0.7.46.chb` | SHA-256 `b581332e726ebec25a851bb7d453882dfa0c39c2cb5f640a4327d51d1b821b7a` |
| `nautilus-0.7.46.tar.zst` | SHA-256 `8a37bccd8c57e8d0b727a0f23f8de7082008aef43ebc77f899e647290fb0b71f` |

The archive hashes match the publisher's `.sha256` sidecars on each release.

`@pin` rows describe what Coral uses at this pin, within the checks Coral
runs; they do not claim gradient or GPU support (see
[`spec/scope.md`](../spec/scope.md#deferrals)). `@upstream` capabilities need
a fresh probe before use. The
[canonical inventory](https://github.com/Chelis-Lang/chelis/blob/a7e592f88a148d8323b8f9a8f679c8e163ad3ee7/docs/CHELIS_SURFACE.md)
owns the compiler-wide surface. Last refreshed: 2026-09-25.

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
| Tensor movement | `gather`, `sort` | Row selection (`head`/`tail`/`slice`, sort-permutation application) and sort-by. **Constraint** (chelis#741): the axis argument must be a literal or an inline `cast(<int>, i32)`; a helper call is rejected by rank monomorphization in the evaluator and in `chelis build`, which is why `frame.ch` inlines `cast(0, i32)` at every axis site. Pinned by `tests_blocked/lowering/gather_axis_helper.ch`. | `@pin` |
| String ordering | `str_lt`, `str_lt_pos`, `str_char_lt` | Lexicographic sort-by on `StringCol` and stable key ordering in GroupBy/Join. | `@pin` |
| Failure | `fail` | Guard rails for schema mismatches and the intentional Parquet stubs (`read_parquet_frame` / `write_parquet_frame`). | `@pin` |

### Standard library and reef dependencies

| Surface | Used by Coral | Status |
|---|---|---|
| `Std.Io` (`write_text`) + `Std.Io.Csv` (`read_csv`) | CSV read path and all file writes (CSV/JSON emit via `write_text`). Round-trips are golden-tested against pandas in `parity/`. | `@pin` |
| `Std.Test` (`assert_true`, `assert_false`, `assert_eq`, `assert_close`) | The whole `tests/` suite. `assert_eq` is generic over the compared type; `assert_close` is restricted to the active float types, which Coral's `f32` tolerances satisfy. Coral uses neither `assert_close_tensor` nor `assert_eq_tensor`. | `@pin` |
| `Std.Io.Json` (`Json` ADT, `load_json`, `json_array`, `json_object`) | JSON read/write for `Coral.Io`. An integer token outside `i64` range ingests as `JsonBigInt(string)` carrying its exact decimal spelling. `Coral.Io.render_json_value` matches all eight `Json` variants explicitly rather than through a wildcard, so a future variant is a compile error here instead of a silently empty cell; `tests/io.ch` pins the exact-digit passthrough and the resulting column inference. | `@pin` |
| `Std.Io.Parquet` | **Signatures only** (chelis#850). The import checks clean, but `libchelis_runtime.a` has no Parquet symbol (re-probed at 0.18.11); Coral ships intentional `fail(...)` stubs (`UPSTREAM_BUGS` §Parked). | `@pin` |
| `Nautilus.Stats` (`mean_vec`, `min_vec`, `max_vec`, `quantile_vec`, `std_vec`) | `describe` and GroupBy aggregations delegate scalar statistics to Nautilus. Reef requires the dependency to declare the same compiler pin as Coral, so Nautilus is bumped first. | `@pin` |

### Lanes

| Lane | Coral usage | Status |
|---|---|---|
| Evaluator (`chelis test`) | The positive suite (`tests/*.ch`), the negative suite (`tests_neg/`), and the blocked-probe suite (`tests_blocked/`). | `@pin` |
| Package build (`chelis reef build`) | Release artifact (`dist/coral-<ver>.chb` + `.tar.zst`). | `@pin` |
| Native C build (`chelis build` + native link) | Not a shipping lane. Constructing a `Frame` and reading `ncols` builds, links, runs, and agrees with eval; reading a column (`nrows`, `drop_nan`) does not lower yet (chelis#1226, chelis#730). The stripped Frame/GroupBy/Join module smokes stop at chelis#2097. The native float-NaN and Window parity regressions pass on bare tensors; they do not prove full Frame lowering. | `@pin` |
| `grad` / AD | Not part of Coral's surface. Scalar `grad` builds natively at this pin (chelis#405 is archived), but Coral makes no claim that `grad` differentiates through its host-list algorithms (`spec/scope.md` deferral D5). | `@pin` |
