# Joins

`Coral.Join` matches rows by equality on one key column that both frames
name `on`. All three joins have the signature
`(left: Frame[n], right: Frame[m], on: string) -> Frame[k]`.

| Join | Rows returned |
|---|---|
| `inner_join(left, right, on)` | One row per matching left/right pair |
| `left_join(left, right, on)` | The inner rows, plus each unmatched left row once |
| `outer_join(left, right, on)` | The left join's rows, then each unmatched right row once |

Integer, float, and string keys work; bool keys fail for inner and left
joins. A bool non-key column in either input causes any join to fail. A
key column missing from either frame fails with `missing column: NAME`.

Give both key columns the same type. Coral does not convert or reject
mismatched key types: an integer key never equals a float or string key,
so the rows simply do not match. An inner join of integer keys `[1, 2]`
against float keys `[1.0, 2.0]`, or against string keys `["1", "2"]`,
returns zero rows, and the outer join of the integer and string frames
returns four rows with keys `"1"`, `"2"`, `"1"`, `"2"`.

## Matching and order

- **Duplicate keys** produce every matching pair. Coral walks left rows
  in order and, for each, emits its matches in right-row order. Left keys
  `["a", "b", "a"]` against right keys `["a", "a", "c"]` give four inner
  rows: left row 0 with right rows 0 and 1, then left row 2 with right
  rows 0 and 1.
- **Missing keys match each other.** A NaN float key matches a NaN key on
  the other side, and a masked integer key matches a masked key whatever
  their stored numbers. This differs from SQL, where a null key matches
  nothing.
- **Output columns.** The left columns come first in their order, then
  the right non-key columns in their order. The right key column is not
  repeated.
- **Name clashes.** A right non-key column whose name is also a left
  column gets the `_right` suffix. If the suffixed name is itself taken,
  the join fails with `from_pairs: duplicate column name`; rename first.

```chelis
module Coral.BookJoin
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, int_col_of_list)
import Coral.Join (left_join)
export (main)
def main() -> i64 = {
  left = from_pairs([("customer", StringCol(["a", "b", "a"])), ("qty", int_col_of_list([1i64, 2i64, 3i64]))])
  right = from_pairs([("customer", StringCol(["a", "c"])), ("score", FloatCol(to_tensor([10.0f32, 40.0f32])))])
  nrows(left_join(left, right, "customer"))
}
```

`main` returns `3`. The unmatched `b` row has a NaN `score`.

## Unmatched rows and key types

For the missing side of an unmatched row, a float value becomes NaN, a
string becomes `""`, and an integer becomes `0` with a true missing-value
mask.

Inner and left joins keep the key's type. `outer_join` returns the key
column as strings even when the input keys are integers or floats: float
keys `1.0`, `2.5`, `4.0` come back as `"1.0"`, `"2.5"`, `"4.0"`, a NaN
float key comes back as `"NaN"`, and a masked integer key comes back as
`"NULL"`.

All three joins are rejected by `chelis build`; see
[limitations](appendix/limitations.md).
