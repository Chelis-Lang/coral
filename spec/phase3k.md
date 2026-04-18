# Phase 3k — Coral

Source of truth for the Coral shell implementation. Extracted verbatim
from `spec/design/chelis_phase3_plan.md` §3k in the
[`Chelis-Lang/chelis`](https://github.com/Chelis-Lang/chelis) monorepo.
Keep this file in sync with the monorepo section — any change to scope,
module list, test plan, or acceptance oracle lands in both places in the
same change set.

---

## 3k: Coral — Typed Dataframes

**Goal:** A reef package for structured tabular data where numeric columns are
GPU-accelerable tensors and string columns are host-side lists. The unique feature: AD
flows through dataframe operations, enabling sensitivity analysis no existing dataframe
library supports.

**Prerequisite:** 3h (gather, scatter, argsort for sort-by/group-by), 3d (collections
for string columns), 3g (Std.IO.Csv/Json for data loading).

### Core Design

A DataFrame is `Dict[String, Column]` where:

```chelis
type Column =
  | IntCol(tensor[n, int64])
  | FloatCol(tensor[n, f32])
  | StringCol(List[String])
  | BoolCol(tensor[n, bool])
```

Numeric columns are tensors on the lazy RISC DAG — they go through the tensor lane, get
GPU-accelerated, support AD, and benefit from the compiler's operation fusion. A
`filter → mutate → aggregate` pipeline on numeric columns may compile to a single fused
kernel. String columns are host-side lists — they go through the host lane and execute
eagerly. The type system tracks which columns are which. No query optimizer — numeric
optimization comes from the tensor compiler's existing fusion passes, not a
dataframe-specific planner.

**Persistent column dictionary (HAMT).** The internal `Dict[String, Column]` backing a
Frame uses a persistent data structure (hash array mapped trie) so that `with_column`,
`drop_column`, and `rename` produce new frames that share column references with the
original via structural sharing. This is a performance requirement for AD through frame
pipelines: `grad(fn_with_10_frame_ops)` produces intermediate frames on the backward
pass, and without structural sharing each intermediate copies the entire column
dictionary — making AD memory cost O(num_columns * num_operations) instead of
O(num_operations). The HAMT stores column references (`Arc` handles to immutable
tensors), not column data, so the tree is small at real portfolio sizes (50-100
columns). Pure-Chelis HAMT is strongly preferred over Rust-side HAMT so the persistent
dict composes transparently with `grad`; decide at implementation start which path
actually composes (see open question #7 in the Coral design spec in the main repo).

### API Stability Convention

Every function in Coral's API surface table (below and in the forthcoming SKILL.md)
carries a `Stability` label: `stable` (signature will not change between releases —
safe for AI training-corpus inclusion) or `alpha` (signature may change — excluded or
down-weighted for training). This convention is inherited from the cross-cutting design
decision in `chelis/spec/design/chelis_canonical_reference.md`. Coral v0.1.0 ships with
all public API marked `alpha` by default; the `stable` promotion happens once the AD
story and persistent-dict implementation are validated against the Phase 3k acceptance
oracle.

### Modules

| Module | Contents | Key Primitives Used |
|---|---|---|
| `Coral.Frame` | DataFrame construction, column selection, row filtering (boolean mask → `gather`), sorting by column (`argsort` → `gather` all columns), mutation (add computed column), column type queries, `rename`, vertical `concat`, `describe` (calls `Nautilus.Stats`), `value_counts` (groupby shorthand). **NaN handling lives here, not in a separate module:** `is_nan`, `fill_nan`, `drop_nan`, `any_nan`, `count_nan`. Float columns use IEEE 754 NaN propagation (GPU kernels handle NaN correctly); integer columns use a companion boolean mask for missingness. | gather, argsort, where, `Nautilus.Stats` |
| `Coral.GroupBy` | Group-by via `argsort` + run-length detection, aggregation (sum, mean, count, min, max per group) via segmented `scatter(..., "add")` | argsort, scatter, cumsum |
| `Coral.Join` | Sort-merge join on typed key columns, left/inner/outer join variants | argsort, gather, concat |
| `Coral.Reshape` | Pivot (long → wide), melt (wide → long), stack/unstack | Dict manipulation, tensor reshape |
| `Coral.Window` | Rolling operations over numeric columns: `rolling_mean`, `rolling_sum`, `rolling_std`, `ewm` (exponentially weighted moving average). Expressible via `cumsum` tricks but worth naming. | cumsum, einsum |
| `Coral.IO` | DataFrame-aware CSV loading (wraps `Std.IO.Csv`, auto-detects column types, returns typed DataFrame), JSON loading, DataFrame → CSV export, **`read_parquet` / `write_parquet` backed by the Rust `parquet2` crate in the runtime** (same integration pattern as `mmap_file` via `memmap2` in 3g). Parquet is the standard columnar format for ML datasets and the largest functional gap vs pandas. | `Std.IO.Csv`, `Std.IO.Json`, runtime `parquet2` FFI |

### AD Through Dataframes

The key differentiator. Because filter is `gather` and aggregation is
`scatter(..., "add")` + `sum`/`mean`, the entire filter → aggregate pipeline is
differentiable:

```chelis
def portfolio_risk(prices: Coral.Frame, threshold: f32) -> f32 = {
  -- filter: gather (differentiable)
  high_vol = Coral.filter(prices, \row -> get_float(row, "volatility") > threshold)
  -- aggregate: mean over tensor column (differentiable)
  Coral.mean_col(high_vol, "return")
}

-- Sensitivity of risk measure to threshold
grad(portfolio_risk, wrt=threshold)  -- works because filter → gather → AD
```

No existing dataframe library supports this.

### Competitive Position vs pandas / Polars

**Where Coral wins:**
- **GPU-accelerated numeric columns for free.** A filter → mutate → aggregate pipeline on
  numeric columns compiles through the tensor DAG and can fuse into a single GPU kernel.
  pandas is CPU-only even with the Arrow backend. RAPIDS cuDF has GPU dataframes but a
  different API; Coral's numeric columns are tensors, so they get GPU acceleration
  without a separate code path.
- **AD through dataframe operations.** `grad(portfolio_risk)` where `portfolio_risk`
  filters a frame and aggregates a column flows through `gather` and `sum`. pandas,
  Polars, and RAPIDS cannot do this.
- **Statically typed columns once retrieved.** `get_float_col(df, "price")` returns
  `tensor[n, f32]`. Wrong column *type* is caught at the type-system level. Column
  *existence* is still dynamic because column names are strings.
- **Effect-tracked provenance.** Loading a CSV/Parquet has `IO` effect; a frame derived
  purely from computation is pure. The type system tracks what each frame depends on.

**Where pandas/Polars win:**
- **Query optimization.** Polars has lazy query plans with predicate pushdown,
  projection pushdown, and join reordering. Coral is eager for string columns and
  lazy-via-tensor-DAG for numeric columns — no cross-operation query planner. For
  complex multi-join analytical queries, Polars will be faster.
- **Missing-data maturity.** pandas has decades of NaN handling baked into every
  operation. Coral's NaN story starts with IEEE 754 propagation plus mask columns for
  integers — functional but newer.
- **Ecosystem.** pandas has thousands of integrations. Coral has none. Cold-start
  problem only adoption solves.

### Test Plan

- `Coral.Frame`: construct from columns, select, filter, sort_by, mutate — all produce
  correct results
- `Coral.Frame` NaN: `fill_nan`, `drop_nan`, `is_nan` match pandas reference on mixed
  float/int test data; GPU kernels propagate NaN correctly
- `Coral.GroupBy`: group_by + sum/mean/count matches pandas.groupby reference on test
  data
- `Coral.Join`: inner join matches pandas.merge on test data, key type enforcement works
- `Coral.Window`: `rolling_mean` / `rolling_std` / `ewm` match pandas reference within
  tolerance
- `Coral.IO`: CSV round-trip (load → export → reload) preserves data and column types;
  **Parquet round-trip** via `parquet2` preserves schema and typed columns
- AD: `grad` through filter + aggregate pipeline produces correct gradients
- GPU: numeric column operations compile to HIP and produce correct results (manual gate)
- Negative: wrong column name errors, type mismatch errors, join key type mismatch errors

### Acceptance Oracle

`cargo test -p chelis-cli phase3k_coral_oracle -- --exact` — loads data into a
DataFrame from both CSV and Parquet, filters rows (including NaN handling), applies a
rolling window, groups by a column, aggregates, and verifies results match expected
values. Plus a separate AD test computing `grad` through a filter-aggregate pipeline.

**Effort:** medium. The core Frame/GroupBy/IO modules are the priority; Join, Reshape,
and Window can ship with minimal implementations and grow. Parquet via `parquet2` is a
runtime FFI addition following the existing `memmap2` pattern.
