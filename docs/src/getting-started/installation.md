# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.46 uses Chelis 0.19.0 and the Nautilus release named in
`reef.toml`. To build
this checkout, install `chelisup`, then run:

```sh
chelisup install 0.19.0
chelis reef build
```

`chelisup install` provides the compiler pinned by `reef.toml`.
`reef build` resolves the Nautilus dependency and builds Coral. The
[Chelis installation guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/install.md)
explains how to install `chelisup`.

To use a published Coral 0.7.45 release, install it in a separate Reef project:

```sh
chelisup install 0.18.13
chelis reef install --from-github Chelis-Lang/coral@v0.7.45
```

The release assets require GitHub repository access. Sign in with
`gh auth login` or set `GITHUB_TOKEN` before using `--from-github`.
Set `compiler = "=0.18.13"` under `[package]` in that project's
`reef.toml`, and add:

```toml
[dependencies]
coral = { version = "0.7.45" }
```

Run `chelis reef build` from that project to resolve imports. Reef also
resolves Coral's Nautilus dependency. For the project layout and module
prefix, see the [Chelis Reef guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/reef.md).
Continue with [your first dataframe](first_dataframe.md).
