# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.47 uses Chelis 0.19.1 and Nautilus 0.7.50. To build
this checkout, install `chelisup`, then run:

```sh
chelisup install 0.19.1
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.50
chelis reef build
```

`chelisup install` provides the compiler pinned by `reef.toml`. Reef uses the
installed Nautilus package; it does not fetch it during build. The
[Chelis installation guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/install.md)
explains how to install `chelisup`.

To use a published Coral 0.7.46 release, install it in a separate Reef project:

```sh
chelisup install 0.19.0
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.49
chelis reef install --from-github Chelis-Lang/coral@v0.7.46
```

Reef authenticates release requests even for public repositories. Sign in with
`gh auth login` or set `GITHUB_TOKEN` before using `--from-github`.
Set `compiler = "=0.19.0"` under `[package]` in that project's
`reef.toml`, and add:

```toml
[dependencies]
coral = { version = "0.7.46" }
```

Run `chelis reef build` from that project to resolve imports. For the project layout and module
prefix, see the [Chelis Reef guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/reef.md).
Continue with [your first dataframe](first_dataframe.md).
