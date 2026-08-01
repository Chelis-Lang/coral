# Installation

Coral 0.7.35 pins the published, publisher-checksummed Chelis 0.18.1 and
Nautilus 0.7.38 releases. Populate a fresh Reef registry with the matching
Nautilus release before building:

```sh
chelis reef install --from-github Chelis-Lang/nautilus@v0.7.38
chelis check src/frame.ch
chelis reef build
```

Private-repository access uses `GITHUB_TOKEN`, falling back to the authenticated
`gh` token. The build does not silently substitute a local path checkout.
