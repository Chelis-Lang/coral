# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.43 uses Chelis 0.18.11 and Nautilus 0.7.46. Install the
matching Chelis toolchain and Coral release:

```sh
chelisup install 0.18.11
chelis reef install --from-github Chelis-Lang/coral@v0.7.43
```

The release assets currently require GitHub repository access. Sign in with
`gh auth login` or set `GITHUB_TOKEN` before using `--from-github`. The
[Chelis installation guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/install.md)
explains how to install `chelisup`.

In a Reef project whose `reef.toml` pins `compiler = "=0.18.11"`, add:

```toml
[dependencies]
coral = { version = "0.7.43" }
```

Run `chelis reef build` from that project to resolve imports. Reef also
resolves Coral's Nautilus dependency. For the project layout and module
prefix, see the [Chelis Reef guide](https://github.com/Chelis-Lang/chelis/blob/main/docs/book/src/reef.md).
Continue with [your first dataframe](first_dataframe.md).
