# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. The project manifest pins its compiler and package dependencies.

## Use Coral in a project

Install the compiler, then create a project and declare Coral in its `reef.toml`:

```sh
chelisup install 0.21.0
chelis +0.21.0 reef init demo --module-prefix Demo --output demo
cd demo
```

Set the compiler pin and Coral dependency:

```toml
[package]
name = "demo"
version = "0.1.0"
compiler = "=0.21.0"
module_prefix = "Demo"

[dependencies]
coral = { version = "0.7.51" }
```

To have Reef fetch missing dependencies by name, build the project. This route
needs `GITHUB_TOKEN` or an authenticated `gh` token for GitHub remote
discovery:

```sh
chelis reef build
```

To install these public releases without GitHub authentication, install the
known tags directly, then build:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.57
chelis reef install --from-github Chelis-Lang/coral@v0.7.51
chelis reef build
```

Reef records the resolved versions and hashes in `reef.lock`. For a project
that already has a lockfile, install its compiler, then run `chelis reef
setup` and `chelis reef build` to restore and build the locked package graph.
A lockfile that names public GitHub releases can be replayed without GitHub
authentication.

Continue with [your first dataframe](first-dataframe.md).
