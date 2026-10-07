# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.47 uses Chelis 0.19.1 and Nautilus 0.7.50.

## Use Coral in a project

Install the Coral release and its Nautilus dependency into your local Reef
registry. Both releases are public, so no token is needed:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.50
chelis reef install --from-github Chelis-Lang/coral@v0.7.47
```

Each command prints `Installed <name> <version>` and stores the package
under `~/.chelis/reef/packages/`. Then create a project:

```sh
chelis reef init demo --module-prefix Demo --output demo
cd demo
```

Edit its `reef.toml`: check that the `compiler` field in the `[package]`
table is `"=0.19.1"`, and add Coral to the `[dependencies]` table. The
edited parts of the manifest:

```toml
[package]
name = "demo"
version = "0.1.0"
compiler = "=0.19.1"
module_prefix = "Demo"

[dependencies]
coral = { version = "0.7.47" }
```

From the project directory, run:

```sh
chelis reef build
```

The build resolves Coral and Nautilus from the local registry, writes
`reef.lock` with the pinned versions and hashes, and prints
`Built demo 0.1.0`. With `GITHUB_TOKEN` set or `gh` signed in,
`reef build` also fetches a missing package from its GitHub release
itself; without either, it stops with an error naming `GITHUB_TOKEN`, so
run the two install commands first. On another machine, run
`chelis reef install --from-lockfile` in the project to reinstall every
dependency recorded in `reef.lock`; it needs no token either. See
[Reef and packages](https://chelis.ch/docs/chelis/reef/) for details.

Continue with [your first dataframe](first-dataframe.md).
