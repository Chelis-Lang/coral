# First Dataframe

`from_pairs` creates a frame in the order you list its columns. Each column
must have the same number of rows. This example has two rows, so `main`
returns `2`:

```chelis
module Coral.Doc01
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows)
export (main)
def main() -> i64 = {
  prices = FloatCol(to_tensor([1.0f32, 2.0f32]))
  names = StringCol(["a", "b"])
  frame = from_pairs([("price", prices), ("name", names)])
  nrows(frame)
}
```

The examples in this guide use `Coral.*` module declarations so they can be
checked inside the Coral package. To use this program in your own Reef
project, replace `Coral` in the **module declaration** with your project's
`module_prefix`, and save the file under the matching `src/` path. Leave the
`import Coral.Frame` line as written. Run `chelis reef build`, then
`chelis eval --file <path-to-your-file.ch>` to see the result.

`FloatCol` stores a `tensor[n, f32]`; `StringCol` stores a `List[string]`.
Use `int_col_of_list` for ordinary `i64` columns so Coral creates the
corresponding all-false missing-value mask. [Construction](../frame/construction.md)
covers the other column forms.
