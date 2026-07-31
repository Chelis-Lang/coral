# Installation

Coral pins the published Nautilus 0.7.36 Reef package. With the official
Chelis 0.17.4 release binary on `PATH`, populate a fresh Reef registry before
building:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.36
chelis check src/frame.ch
chelis reef build
```

Private-repository access uses `GITHUB_TOKEN`, falling back to the authenticated
`gh` token. The build does not silently substitute a local path checkout.
