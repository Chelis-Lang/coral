# Coral

Coral is a [Chelis](https://github.com/Chelis-Lang/chelis) Reef package for
typed dataframes. A `Frame` holds float, integer, boolean, or string columns.
Float and integer columns store Chelis tensors, so a column retrieved from a
frame can be passed to ordinary tensor operations. Filtering, grouping,
joining, reshaping, windowing, and CSV and JSON I/O work on frames.

The [Coral guide](https://chelis.ch/docs/coral/) teaches the API with
runnable examples; its source is the mdBook in [`docs/book/`](docs/book/).

## Install

Coral 0.7.48 uses Chelis 0.19.2 and Nautilus 0.7.51. Initialize a Reef
project and add Coral to its `reef.toml`:

```sh
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

Set the project's compiler pin and dependency:

```toml
[package]
name = "demo"
version = "0.1.0"
compiler = "=0.19.2"
module_prefix = "Demo"

[dependencies]
coral = { version = "0.7.48" }
```

Install the compiler, then let Reef retrieve the dependencies by name. This
route requires `GITHUB_TOKEN` or an authenticated `gh` token:

```sh
chelisup install 0.19.2
chelis reef build
```

For anonymous access to the public release assets, install the known tags
directly before building:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.51
chelis reef install --from-github Chelis-Lang/coral@v0.7.48
chelis reef build
```

Reef records the versions and hashes in `reef.lock`. The
[installation page](https://chelis.ch/docs/coral/getting-started/installation/)
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
