# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.47 uses Chelis 0.19.1 and Nautilus 0.7.50.

## Use Coral in a project

Create a project with
`chelis reef init demo --module-prefix Demo --output demo`, then edit its
`reef.toml`: set
the `compiler` field in the `[package]` table to `"=0.19.1"` and add Coral
to the `[dependencies]` table. The edited parts of the manifest:

```toml
[package]
name = "demo"
version = "0.1.0"
compiler = "=0.19.1"
module_prefix = "Demo"

[dependencies]
coral = { version = "0.7.47" }
```

Then run `chelis reef setup` and `chelis reef build`. Reef downloads Coral and its
Nautilus dependency from their releases, so a source checkout of either
library is not required. See [Reef and packages](https://chelis.ch/docs/chelis/reef/) for
details.
Continue with [your first dataframe](first-dataframe.md).
