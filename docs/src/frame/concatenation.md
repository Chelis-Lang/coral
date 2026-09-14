# Concatenation

`Coral.Frame.concat` vertically stacks frames with the same ordered schema.

The current first-pass parity slice supports `IntCol`, `FloatCol`, `StringCol`,
and `BoolCol` in concat. The typed signature is `concat[n, k](frames:
List[Frame[n]]) -> Frame[k]`, so every stacked frame shares one static row
count `n`; the example below stacks two two-row frames into a four-row result.

```chelis
module Coral.BookConcat
import Coral.Frame (BoolCol, from_pairs, concat, nrows, int_col_of_list)
export (main)
def main() -> int64 = {
  lhs = from_pairs([("id", int_col_of_list([cast(1, int64), cast(2, int64)])), ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)]))))])
  rhs = from_pairs([("id", int_col_of_list([cast(3, int64), cast(4, int64)])), ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(1, int64)]), to_tensor([cast(0, int64), cast(0, int64)]))))])
  nrows(concat([lhs, rhs]))
}
```
