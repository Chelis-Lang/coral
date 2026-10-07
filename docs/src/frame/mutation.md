# Changing columns

Each operation returns a new frame; use the returned frame for the next
step.

| Function | Signature | Behavior | Failure |
|---|---|---|---|
| `with_column` | `(df: Frame[n], name: string, col: Column[n]) -> Frame[n]` | Replaces the column `name` in place, or appends it as the last column | None |
| `mutate` | same as `with_column` | Same as `with_column` | None |
| `rename` | `(df: Frame[n], old_name: string, new_name: string) -> Frame[n]` | Renames in place; the column keeps its position | `rename: target column already exists`; `missing column: OLD` |
| `drop_column` | `(df: Frame[n], name: string) -> Frame[n]` | Removes the column | `drop_column: missing column NAME` |

```chelis
module Coral.BookMutation
import Coral.Frame (FloatCol, from_pairs, with_column, rename, drop_column, int_col_of_list, ncols)
export (main)
def main() -> i64 = {
  frame = from_pairs([("price", FloatCol(to_tensor([10.0f32, 20.0f32])))])
  renamed = rename(frame, "price", "cost")
  extended = with_column(renamed, "qty", int_col_of_list([2i64, 3i64]))
  trimmed = drop_column(extended, "cost")
  ncols(trimmed)
}
```

`main` returns `1`: only `qty` remains.

## Pitfalls

- **Column length.** Give `with_column` a column with the frame's row
  count. It does not check the length when it runs, so a column of a
  different length produces a frame whose columns disagree.
- **Replacing changes the type.** `with_column` replaces a column of any
  type with the new one; replacing a `FloatCol` `a` with an `IntCol` keeps
  `a` at its position as an integer column.
- **Renaming to the same name.** `rename(df, "a", "a")` fails with
  `rename: target column already exists`, because the target check runs
  first.
- **Native builds.** `chelis build` rejects programs that call
  `drop_column`; see [limitations](../appendix/limitations.md).
