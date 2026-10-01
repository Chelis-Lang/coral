# Coral

Coral is a [Chelis](https://github.com/Chelis-Lang/chelis) Reef package for
typed dataframes. A `Frame` holds float, integer, boolean, or string columns.
Float and integer columns store Chelis tensors, so a column retrieved from a
frame can be passed to ordinary tensor operations. Filtering, grouping, and
joining use host values around those tensor columns.

Start with the [Coral guide](docs/src/SUMMARY.md), especially
[installation](docs/src/getting-started/installation.md) and
[your first dataframe](docs/src/getting-started/first_dataframe.md).
The [Chelis installation guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/install.md)
explains `chelisup`; the [Reef guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/reef.md)
explains packages and imports.

## Install

Coral 0.7.44 uses Chelis 0.18.12 and Nautilus 0.7.47. To build this
checkout, install `chelisup`, then run:

```sh
chelis reef setup
chelis reef build
```

To consume the published release in a Reef project, install its toolchain
and package:

```sh
chelisup install 0.18.12
chelis reef install --from-github Chelis-Lang/coral@v0.7.44
```

In that project's `reef.toml`, pin `compiler = "=0.18.12"` and declare:

```toml
[dependencies]
coral = { version = "0.7.44" }
```

The GitHub release assets require repository access; authenticate with
`gh auth login` or set `GITHUB_TOKEN` before installing. Run
`chelis reef build` in your project to resolve imports. The
[first dataframe](docs/src/getting-started/first_dataframe.md) shows a
complete program. See [installation](docs/src/getting-started/installation.md)
for the source and release workflows.

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

`Coral.Core.version()` returns `1` as a package smoke check. The [API overview](docs/src/appendix/api.md)
links the user-facing modules to their chapters.

## Availability

Coral's dataframe operations run through `chelis eval` and `chelis test`.
With Chelis 0.18.12, native probes pass for frame construction, `nrows`,
and matching a retrieved column. An invoked `drop_nan` still fails to
build; other dataframe operations need their own native checks. Tensor
payloads do not establish GPU support. Parquet
frame functions are exported but fail when called. CSV and JSON writers do
not preserve integer missing-value masks, and the JSON writer requires
simple text without characters needing JSON escaping. See the
[I/O chapter](docs/src/io.md) and [limitations](docs/src/appendix/limitations.md)
before exchanging data.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) describes setup and checks for library
changes. The public behavior and planned boundaries are recorded in
[spec/scope.md](spec/scope.md).

## License

MIT. See [LICENSE](LICENSE).
