# Coral

Coral adds typed dataframes to Chelis as a Reef package. A `Frame` holds
named columns with one row count. Columns are `FloatCol` (`f32` tensor),
`IntCol` (`i64` tensor plus a missing-value mask), `BoolCol` (bool tensor),
or `StringCol` (list of strings).

Extract a numeric column with an accessor such as `get_float_col` to use its
tensor in a Chelis calculation. Coral's dataframe operations also use host
lists for grouping, joining, and other row work. Run the value-returning
examples with `chelis eval`; the file I/O example uses `chelis test`.

The [first dataframe](getting-started/first-dataframe.md) builds a frame
and reads its row count. The [limitations](appendix/limitations.md)
page collects input and output constraints.
