# First Dataframe

```chelis
module Coral.Doc01
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows)
export (main)
def main() -> int64 = {
  df = from_pairs([("price", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32)]))), ("name", StringCol(["a", "b"]))])
  nrows(df)
}
```
