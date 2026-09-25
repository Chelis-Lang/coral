# Installation

Coral is a Reef package. Install the Chelis toolchain with `chelisup`, then
install a Coral release into your local Reef registry. Coral 0.7.43 is built
for Chelis 0.18.11:

```sh
chelisup install 0.18.11
chelis reef install --from-github Chelis-Lang/coral@v0.7.43
```

Declare the dependency in your project's `reef.toml`:

```toml
[dependencies]
coral = { version = "0.7.43" }
```

`chelis reef build` fetches Coral's dependency, Nautilus, into the registry if
it is missing. `--from-github` authenticates with `GITHUB_TOKEN`, falling back
to `gh auth token`.

To work on Coral itself, see
[`CONTRIBUTING.md`](https://github.com/Chelis-Lang/coral/blob/main/CONTRIBUTING.md).
