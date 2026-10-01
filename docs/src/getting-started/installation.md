# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. This source checkout declares Coral 0.7.44, pinned to Chelis
0.18.12 and Nautilus 0.7.47. To build the checkout, install `chelisup`,
then run:

```sh
chelis reef setup
chelis reef build
```

`chelis reef setup` installs the compiler pinned in `reef.toml` when
needed; `chelis reef build` resolves the Nautilus dependency. The
[Chelis installation guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/install.md)
explains how to install `chelisup`.

Coral 0.7.44 is not yet published. The current published Coral 0.7.43
release uses Chelis 0.18.11 and Nautilus 0.7.46. To consume that release
in a separate Reef project:

```sh
chelisup install 0.18.11
chelis reef install --from-github Chelis-Lang/coral@v0.7.43
```

The release assets require GitHub repository access. Sign in with
`gh auth login` or set `GITHUB_TOKEN` before using `--from-github`.
Set `compiler = "=0.18.11"` under `[package]` in that project's
`reef.toml`, and add:

```toml
[dependencies]
coral = { version = "0.7.43" }
```

Run `chelis reef build` from that project to resolve imports. Reef also
resolves Coral's Nautilus dependency. For the project layout and module
prefix, see the [Chelis Reef guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/reef.md).
Continue with [your first dataframe](first_dataframe.md).
