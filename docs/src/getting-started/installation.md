# Installation

Coral 0.7.34 pins the published, publisher-checksummed Chelis 0.17.5 and
Nautilus 0.7.37 releases. Populate a fresh Reef registry with the matching
Nautilus release before building:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.37
chelis check src/frame.ch
chelis reef build
```

Private-repository access uses `GITHUB_TOKEN`, falling back to the authenticated
`gh` token. The build does not silently substitute a local path checkout.
