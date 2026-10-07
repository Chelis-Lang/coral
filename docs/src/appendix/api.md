# API overview

Import Coral functions from their named module in a Reef project. For
example, `import Coral.Frame (from_pairs, get_float_col)` makes those two
names available to your program.

| Module | Main operations | Guide |
|---|---|---|
| `Coral.Frame` | `from_pairs`, `from_columns`, `empty`, `int_col_of_list`; typed accessors; `filter`, `head`, `tail`, `slice`, `sort_by`; `with_column`, `mutate`, `rename`, `drop_column`; missing-value helpers; `concat`, `describe` | [Construction](../frame/construction.md), [Filtering](../frame/filtering.md), [Changing columns](../frame/mutation.md), [Missing values](../frame/nan-handling.md), [Concatenation](../frame/concatenation.md), [Describe](../frame/describe.md) |
| `Coral.GroupBy` | `group_by`, `agg_sum`, `agg_mean`, `agg_count`, `agg_min`, `agg_max`, `agg`, `value_counts` | [GroupBy](../groupby.md) |
| `Coral.Join` | `inner_join`, `left_join`, `outer_join` | [Joins](../joins.md) |
| `Coral.Io` | CSV and JSON frame readers and writers; unavailable Parquet frame names | [CSV and JSON](../io.md) |
| `Coral.Window` | `rolling_sum`, `rolling_mean`, `rolling_std`, `rolling_min`, `rolling_max`, `ewm` | [Window](../window.md) |
| `Coral.Reshape` | `pivot`, `melt`, `stack`, `unstack` | [Reshape](../reshape.md) |
| `Coral.AsOf` | `asof_lookup`, `asof_join` and their `_list` forms | [Sorted-key lookup](../asof.md) |

See [limitations](limitations.md) for the input and output
constraints documented for supported operations.
