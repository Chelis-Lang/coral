# Concatenation

`Coral.Frame.concat` vertically stacks frames with the same ordered schema.

The current first-pass parity slice supports `IntCol`, `FloatCol`, `StringCol`,
and `BoolCol` in concat.

```chelis
module Coral.BookConcat
import Coral.Frame (from_pairs, concat, nrows)
export (main)

def main() -> int64 = {
  lhs = from_pairs([
    ("id", IntCol(to_tensor([cast(1, int64), cast(2, int64)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)]))))
  ])
  rhs = from_pairs([
    ("id", IntCol(to_tensor([cast(3, int64)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64)]), to_tensor([cast(0, int64)]))))
  ])
  nrows(concat([lhs, rhs]))
}
```
