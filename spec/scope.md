# Coral scope and acceptance

This document defines Coral's supported behavior, architecture, and checks
for new public functions. The function-level API inventory lives in
[`SKILL.md`](../SKILL.md) §5 and the [book](../docs/book/src/SUMMARY.md).

## Intent

Coral is a Reef package for the [Chelis](https://github.com/Chelis-Lang/chelis)
language that provides typed dataframes. Its `Coral` modules load CSV and
JSON data, select, filter, sort, and change columns, group and aggregate,
join, reshape, compute rolling and exponentially weighted statistics, and
write CSV and JSON. Selected results are compared with pandas goldens under
the acceptance rules below.

The distinguishing design choice is that numeric columns are Chelis tensors.
A float column retrieved with `get_float_col` is a `tensor[n, f32]`, so it
can be passed straight into the rest of a tensor program rather than
converted out of a separate dataframe runtime.

## Architecture

- **Pure Chelis.** Coral has no C or Rust FFI and no compiler special-casing.
  The summary statistics in `describe` delegate to `Nautilus.Stats`, a sibling
  Reef package; the GroupBy aggregations are Coral's own.
- **Typed columns.** `Column[n]` is a sum type over four payloads:
  `FloatCol(tensor[n, f32])`, `IntCol(tensor[n, i64], tensor[n, bool])`
  (values plus a missing-value mask), `BoolCol(tensor[n, bool])`, and
  `StringCol(List[string])`. Tensor payloads carry the symbolic row count
  `n`; `from_pairs` checks the length of every payload, including string
  lists. Operations that change the row count, such as
  `filter`, `head`, joins, and reshapes, return a frame with a fresh row
  dimension.
- **Persistent column store.** A `Frame` stores its columns in a persistent
  hash array mapped trie (`Coral.Internal.Hamt`), not a copy-on-write `Dict`,
  plus an explicit column order. `drop_column` and `rename` update the trie
  through `hamt_remove` and `hamt_put`, returning a new frame that shares
  unchanged trie branches; `with_column` rebuilds the trie from its entries.
- **Host-list algorithms, tensor payloads.** Column payloads are stored as
  tensors, but the relational algorithms run on host lists: grouping and
  joins match keys by equality and preserve first-seen key order, and string
  sorting is an insertion sort. `filter`, `head`, `tail`, `slice`, and
  `sort_by` apply the resulting row indices to tensor columns with `gather`;
  joins, grouping, and string columns select rows through host lists.

## Acceptance

A change to Coral's public surface is accepted when:

- every new public function has Chelis tests in `tests/*.ch` on at least two
  distinct shapes or configurations, asserting hand-computed values,
  mathematical identities, structural properties, or round trips;
- every rejection the function promises is pinned by a negative case under
  `tests_neg/`, which must fail to compile with the diagnostic on line 1 of
  its `.expect` sidecar;
- where pandas defines the behavior, a reviewed golden under
  `parity/goldens/` records the pandas result for the same input (adapted to
  Coral's documented ordering where the two differ, as the `outer_join` and
  `melt` goldens are);
- `SKILL.md` and the book are updated, and their complete ```` ```chelis ````
  examples still type-check and build under `scripts/run_skill_checks.py`
  and `scripts/validate_book_examples.py`.

### What the parity harness proves

`parity/run_parity.py --strict` does three things. It confirms that every
checked-in golden still matches what `parity/gen_goldens.py` derives from
pandas on its fixed input, so the goldens cannot drift from the reference.
Two goldens are pandas output reordered to Coral's documented order:
`outer_join` (left rows in order, then right-only rows) and `melt`
(`variable`, `value`, then the id columns). It compiles `rolling_mean` and
`ewm` to generated C, runs them, and compares the output with pandas goldens.
And it checks three generated negative cases. Only those two Window
functions are compared against pandas by execution. For Frame, GroupBy,
Join, IO, and Reshape, the goldens are the reference that the Chelis tests'
hand-computed expectations are written against, not an automated
comparison (deferral D7).

## Known limitations

Upstream compiler limitations are tracked, with reproducers and re-probe
triggers, in [`docs/UPSTREAM_BUGS.md`](../docs/UPSTREAM_BUGS.md). The ones a
user is most likely to notice:

- **Parquet** is unavailable (chelis#850).
- **Generated-C coverage of the Frame API.** The package probes exercise
  construction, `nrows`, column matching, `drop_nan`, `filter`, `head`,
  `slice`, `sort_by`, and `with_column`. They do not establish support for
  the full API. `describe` and `drop_column` have open compiler issues
  ([chelis#3169](https://github.com/Chelis-Lang/chelis/issues/3169),
  [chelis#879](https://github.com/Chelis-Lang/chelis/issues/879)); stripped
  Frame, GroupBy, and Join builds are tracked by
  [chelis#2097](https://github.com/Chelis-Lang/chelis/issues/2097).
- **Evaluator cost of the HAMT.** Evaluating frames with 100 or more columns
  may require a longer test timeout ([coral#16](https://github.com/Chelis-Lang/coral/issues/16)).

## Deferrals

Each deliberate narrowing of Coral's surface has an entry here. Runtime
rejection sites cite `spec/scope.md` § Deferrals (Dn).

- **D1: Bool group keys.** `group_by` can collect bool keys, but the
  aggregations and `value_counts` cannot return a bool key column: they fail
  at runtime with "bool regrouping is not supported yet". Int, float, and
  string keys are supported.
- **D2: Bool columns in joins.** A bool non-key column in either input frame
  fails every join at runtime. A bool key column fails `inner_join` and
  `left_join`; `outer_join` accepts it and returns the key as strings (D9).
- **D3: Numeric aggregation types.** `agg_sum`, `agg_mean`, `agg_min`, and
  `agg_max` accept float and int value columns only. Every spec in `agg`,
  including `AggCount`, names a float or int value column
  ([coral#38](https://github.com/Chelis-Lang/coral/issues/38)). `agg_count`
  counts rows per group without a value column.
- **D4: Reshape column types.** `pivot` requires string index and pivot-key
  columns and a float values column; `melt` requires string id columns and
  float value columns. `stack` and `unstack` inherit these rules.
- **D5: Gradients.** Coral makes no claim that `grad` differentiates through
  its host-list algorithms. A claim needs a `grad` test against an exact or
  finite-difference reference.
- **D6: GPU execution.** No Coral operation is validated on a GPU backend.
- **D7: Executed parity beyond Window.** Frame, GroupBy, Join, IO, and
  Reshape have pandas goldens but no automated Coral-versus-golden
  execution.
- **D8: Stability.** The public API is alpha. Function-level stability
  labels are not assigned.
- **D9: `outer_join` key type.** `outer_join` returns the key column as a
  string column whatever the key type (an int key `2` becomes `"2"`), where
  pandas keeps the key's type. `inner_join` and `left_join` keep it.
- **D10: Parquet file I/O.** `read_parquet_frame` and
  `write_parquet_frame` are exported but fail explicitly. `Std.Io.Parquet`
  provides no working file I/O implementation (chelis#850); the upstream
  reproduction and re-probe trigger are in `docs/UPSTREAM_BUGS.md`.
