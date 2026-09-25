# Coral

Typed dataframes for the [Chelis](https://github.com/Chelis-Lang/chelis)
programming language. Coral is a Reef package (Chelis's package format)
published under the `Coral` module prefix.

A Coral `Frame` holds typed columns. Numeric columns are Chelis tensors: a
float column retrieved with `get_float_col` is a `tensor[n, f32]` that can be
passed straight into the rest of a tensor program. String columns are host
lists. Behavior follows pandas unless a difference is documented. See
[`spec/scope.md`](spec/scope.md) for the design, the acceptance rules, the
known limitations, and what is deliberately out of scope.

## Modules

| Module | What it provides |
|---|---|
| `Coral.Frame` | Typed columns, construction, accessors, mask filtering, `head` / `tail` / `slice`, `sort_by`, `with_column` / `mutate` / `rename` / `drop_column`, float and integer NaN helpers, vertical `concat`, `describe` |
| `Coral.GroupBy` | Single-key `group_by` with `sum`, `mean`, `count`, `min`, `max`, multi-aggregation `agg`, and `value_counts` |
| `Coral.Join` | `inner_join`, `left_join`, `outer_join` on a named key column |
| `Coral.Reshape` | `pivot`, `melt`, `stack`, `unstack` |
| `Coral.Window` | Rolling `sum`, `mean`, `std`, `min`, `max`, and exponentially weighted `ewm` |
| `Coral.Io` | CSV and JSON read and write with column type inference |
| `Coral.AsOf` | As-of lookup and join over sorted `i64` keys with `f32` values |
| `Coral.Core` | Package smoke anchor (`version`) |

[`SKILL.md`](SKILL.md) has the full API inventory and compact examples, and
the [book](docs/src/SUMMARY.md) has a chapter per module.

## Using Coral

Install the Chelis toolchain with `chelisup` (see the
[Chelis installation guide](https://github.com/Chelis-Lang/chelis)). Coral
0.7.43 is built for Chelis 0.18.11. Install the Coral release into your local
Reef registry and declare it as a dependency:

```sh
chelisup install 0.18.11
chelis reef install --from-github Chelis-Lang/coral@v0.7.43
```

```toml
# your project's reef.toml
[dependencies]
coral = { version = "0.7.43" }
```

`chelis reef build` fetches Coral's own dependency, Nautilus, if it is not
already installed.

```chelis
module MyProject.Demo
import Coral.Frame (FloatCol, StringCol, from_pairs, nrows)
import Coral.GroupBy (group_by, agg_sum)
export (main)
def main() -> i64 = {
  sales = from_pairs([("city", StringCol(["london", "paris", "london"])), ("revenue", FloatCol(to_tensor([cast(10.0, f32), cast(20.0, f32), cast(30.0, f32)])))])
  totals = agg_sum(group_by(sales, "city"), "revenue")
  nrows(totals)
}
```

`main` returns 2, one row per city.

## Limitations

- Parquet I/O is not available: `read_parquet_frame` and
  `write_parquet_frame` fail at runtime until the Chelis standard library
  provides a Parquet runtime (chelis#850).
- Coral runs as a Reef package and in the Chelis evaluator. Compiling a
  program that reads `Frame` columns to native code with `chelis build` is not
  yet supported by the compiler (chelis#1226).
- Missing values follow a narrower model than pandas: float columns use NaN,
  integer columns carry a separate missing-value mask, and string and bool
  columns have no missing-value marker (joins pad unmatched string cells with
  the empty string).
- Bool columns are not supported as group keys or as non-key join columns,
  and `pivot` and `melt` take float value columns only.
- Frames with 100 or more columns are slow in the evaluator (chelis#828).

[`docs/UPSTREAM_BUGS.md`](docs/UPSTREAM_BUGS.md) tracks every compiler issue
that affects Coral, and [`spec/scope.md`](spec/scope.md#deferrals) lists the
deliberate deferrals.

## Contributing

[`CONTRIBUTING.md`](CONTRIBUTING.md) covers setup, the test suites, the local
gate, and how CI is organized. Agent-facing repository rules are in
[`AGENTS.md`](AGENTS.md).

## License

MIT. See [`LICENSE`](LICENSE).
