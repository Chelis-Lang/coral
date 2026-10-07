# First dataframe

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

In your Reef project, replace `Coral` in `module Coral.Doc01` with the
project's `module_prefix` and save the program as `src/doc01.ch`. Keep
`import Coral.Frame` unchanged. Run `chelis reef build`, then
`chelis eval --file src/doc01.ch` to see the result.

`FloatCol` stores a `tensor[n, f32]`; `StringCol` stores a `List[string]`.
Use `int_col_of_list` for ordinary `i64` columns so Coral creates the
corresponding all-false missing-value mask. [Construction](../frame/construction.md)
covers the other column forms.
