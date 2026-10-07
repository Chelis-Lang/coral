# API overview

Import Coral functions from their named module in a Reef project. For
example, `import Coral.Frame (from_pairs, get_float_col)` makes those two
names available to your program. Import constructors the same way:
`FloatCol`, `IntCol`, `StringCol`, `BoolCol`, the `ColumnType` values
`IntType`, `FloatType`, `StringType`, `BoolType`, and the GroupBy specs
`AggSum`, `AggMean`, `AggCount`, `AggMin`, `AggMax`.

In the signatures below, `F[n]` stands for `Frame[n]` and `T[n, d]` for
`tensor[n, d]`. A result `F[k]` or `F[m]` has a row count fixed only when
the function runs.

## Coral.Frame

| Function | Signature | Guide |
|---|---|---|
| `from_pairs` | `(pairs: List[(string, Column[n])]) -> F[n]` | [Construction](../frame/construction.md) |
| `from_columns` | `(cols: Dict[string, Column[n]]) -> F[n]` | [Construction](../frame/construction.md) |
| `empty` | `(schema: Dict[string, ColumnType]) -> F[n]` | [Construction](../frame/construction.md) |
| `int_col_of_list` | `(values: List[i64]) -> Column[n]` | [Construction](../frame/construction.md) |
| `get_float_col`, `get_int_col`, `get_bool_col` | `(df: F[n], name: string) -> T[n, f32]`, `T[n, i64]`, `T[n, bool]` | [Construction](../frame/construction.md) |
| `get_string_col` | `(df: F[n], name: string) -> List[string]` | [Construction](../frame/construction.md) |
| `get_column` | `(df: F[n], name: string) -> Column[n]` | [Construction](../frame/construction.md) |
| `columns`, `column_type` | `(df: F[n]) -> List[string]`, `(df: F[n], name: string) -> ColumnType` | [Construction](../frame/construction.md) |
| `nrows`, `ncols` | `(df: F[n]) -> i64` | [Construction](../frame/construction.md) |
| `filter` | `(df: F[n], mask: T[n, bool]) -> F[k]` | [Filtering](../frame/filtering.md) |
| `head`, `tail` | `(df: F[n], count: i64) -> F[k]` | [Filtering](../frame/filtering.md) |
| `slice` | `(df: F[n], start: i64, finish: i64) -> F[k]` | [Filtering](../frame/filtering.md) |
| `sort_by` | `(df: F[n], name: string, ascending: bool) -> F[n]` | [Filtering](../frame/filtering.md) |
| `with_column`, `mutate` | `(df: F[n], name: string, col: Column[n]) -> F[n]` | [Changing columns](../frame/mutation.md) |
| `rename` | `(df: F[n], old_name: string, new_name: string) -> F[n]` | [Changing columns](../frame/mutation.md) |
| `drop_column` | `(df: F[n], name: string) -> F[n]` | [Changing columns](../frame/mutation.md) |
| `is_nan`, `fill_nan`, `any_nan`, `count_nan`, `drop_nan` | Float NaN helpers | [Missing values](../frame/nan-handling.md) |
| `is_nan_col`, `fill_nan_col`, `drop_nan_col`, `any_nan_col`, `count_nan_col` | Integer mask helpers | [Missing values](../frame/nan-handling.md) |
| `concat` | `(frames: List[F[n]]) -> F[k]` | [Concatenation](../frame/concatenation.md) |
| `describe` | `(df: F[n]) -> F[m]` | [Describe](../frame/describe.md) |

## Other modules

| Module | Functions | Guide |
|---|---|---|
| `Coral.GroupBy` | `group_by(df, key_name) -> GroupedFrame[n]`; `agg_sum`, `agg_mean`, `agg_min`, `agg_max` `(grouped, col) -> F[m]`; `agg_count(grouped) -> F[m]`; `agg(grouped, specs: List[(string, AggFn)]) -> F[m]`; `value_counts(df, key_name) -> F[m]` | [GroupBy](../groupby.md) |
| `Coral.Join` | `inner_join`, `left_join`, `outer_join` `(left: F[n], right: F[m], on: string) -> F[k]` | [Joins](../joins.md) |
| `Coral.Io` | `read_csv_frame`, `read_json_frame` `(path: string) -> F[n]`; `write_csv_frame`, `write_json_frame` `(df: F[n], path: string) -> unit`; `read_parquet_frame` and `write_parquet_frame` fail when called | [CSV and JSON](../io.md) |
| `Coral.Window` | `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max` `(col: T[n, f32], window: i64) -> T[n, f32]`; `ewm(col: T[n, f32], alpha: f32) -> T[n, f32]` | [Window](../window.md) |
| `Coral.Reshape` | `melt(df, id_cols, value_cols)`, `pivot(df, index_col, columns_col, values_col)`, `stack(df)`, `unstack(df, index_col)`, each `-> F[m]` | [Reshape](../reshape.md) |
| `Coral.AsOf` | `asof_lookup`, `asof_join` and their `_list` forms | [Sorted-key lookup](../asof.md) |

See [limitations](limitations.md) for input and output
constraints and for the functions that `chelis build` rejects.
