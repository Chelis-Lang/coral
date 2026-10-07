# Coral

Coral is a [Chelis](https://github.com/Chelis-Lang/chelis) Reef package for
typed dataframes. A `Frame` holds float, integer, boolean, or string columns.
Float and integer columns store Chelis tensors, so a column retrieved from a
frame can be passed to ordinary tensor operations. Filtering, grouping,
joining, reshaping, windowing, and CSV and JSON I/O work on frames.

The [Coral guide](https://chelis.ch/docs/coral/) teaches the API with
runnable examples; its source is the mdBook in [`docs/book/`](docs/book/).

## Install

Coral 0.7.47 uses Chelis 0.19.1 and Nautilus 0.7.50. Install Chelis with
`chelisup` ([installation guide](https://chelis.ch/docs/chelis/install/)),
then install the Coral release and its Nautilus dependency into your local
Reef registry. Both releases are public, so no token is needed:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.50
chelis reef install --from-github Chelis-Lang/coral@v0.7.47
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

In the project's `reef.toml`, check that `compiler` is `"=0.19.1"` and add Coral:

```toml
[dependencies]
coral = { version = "0.7.47" }
```

Run `chelis reef build`; it resolves Coral and Nautilus from the local
registry and writes `reef.lock`. On another machine,
`chelis reef install --from-lockfile` reinstalls the locked dependencies.
With `GITHUB_TOKEN` set or `gh` signed in, `chelis reef build` fetches
missing packages itself. The [installation page](https://chelis.ch/docs/coral/getting-started/installation/)
and [first dataframe](https://chelis.ch/docs/coral/getting-started/first-dataframe/)
continue from there.

## Modules

| Module | What it provides |
|---|---|
| `Coral.Frame` | Typed columns, construction, accessors, filtering, sorting, mutation, missing-value helpers, concatenation, and summaries |
| `Coral.GroupBy` | Single-key grouping and aggregation |
| `Coral.Join` | Inner, left, and outer joins on a named key column |
| `Coral.Reshape` | `pivot`, `melt`, `stack`, and `unstack` |
| `Coral.Window` | Rolling statistics and exponentially weighted values on `f32` tensors |
| `Coral.Io` | CSV and JSON frame readers and writers |
| `Coral.AsOf` | Prior-or-equal lookup and alignment on sorted `i64` key tensors or lists |
| `Coral.Core` | `version()`, a package smoke check that returns `1` (not the release version) |

Read the [limitations](https://chelis.ch/docs/coral/appendix/limitations/)
before exchanging data through files.

## License

MIT. See [LICENSE](LICENSE).
