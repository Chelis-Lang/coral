# Installation

Coral is a Reef package, separate from the standard library bundled with
Chelis. Coral 0.7.47 uses Chelis 0.19.1 and Nautilus 0.7.50.

## Use Coral in a project

Add Coral to a Reef project's `[dependencies]` table in `reef.toml`:

```toml
[dependencies]
coral = { version = "0.7.47" }
```

Set the project's `compiler` pin to `"=0.19.1"`, then run
`chelis reef setup` and `chelis reef build`. Reef downloads Coral and its
Nautilus dependency from their releases, so a source checkout of either
library is not required. See [Reef and packages](https://chelis.ch/docs/chelis/reef/) for
details. To build or modify Coral itself, clone its source repository.
Continue with [your first dataframe](first-dataframe.md).
