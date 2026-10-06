# Coral Releases

## What Coral publishes per release

Each Coral release on GitHub ships exactly three artifacts:

- `coral-X.Y.Z.chb` (about 20 KB) — Reef shell package
- `coral-X.Y.Z.tar.zst` (about 15 KB) — source archive
- `coral-X.Y.Z.sha256` — publisher checksum manifest sealing both payloads

The payload pair is produced by `chelis reef build`; the release gate validates
it with the compiler's canonical artifact verifier, seals both files, rebuilds,
and requires byte-identical checksums before publication. None is
platform-specific.

## Why the artifacts are platform-agnostic

The `.tar.zst` is the source tree (`reef.toml`, the `.ch` files under
`src/`, and packaging metadata). The payload is platform-neutral. The release
workflow requires its second unchanged build to be byte-identical to the sealed
first build.

The `.chb` is a Zstandard-compressed envelope containing
desugared/type-checked AST + module exports + type signatures +
effects + dependency list. No ELF, no Mach-O, no `.o`, no
`.a`. Verified via `strings`: contains UTF-8 names like `"coral"`,
`"Coral.Frame"`, type signatures in IR form. Contains zero platform
references.

Compare to chelis itself, which ships per-platform binaries:

- `chelis-vX.Y.Z-linux-x86_64-glibc2.31.tar.gz`
- `chelis-vX.Y.Z-darwin-arm64.tar.gz`

Inside those: `bin/chelis` is a Rust-compiled binary (ELF on Linux,
Mach-O on Darwin); `lib/libchelis_runtime.a` is a platform-specific
static archive. **chelis's tarballs must be platform-specific because
they contain native code. Coral's `.chb` + `.tar.zst` must not be —
the IR is the contract; the consumer compiles to their platform.**

## How a Mac (or any) user consumes Coral

No platform-specific Coral artifact is needed:

1. Install the Chelis toolchain for the consumer's platform with `chelisup`,
   at the compiler version in that release's `reef.toml`.
2. Install the Coral release into the local Reef registry with
   `chelis reef install --from-github Chelis-Lang/coral@vX.Y.Z`, substituting
   the published tag.
3. Declare `coral = { version = "X.Y.Z" }` under `[dependencies]` in the
   consumer project's `reef.toml`, using the same published version.
4. `chelis reef build` fetches Coral's own dependency (Nautilus) if it is
   missing, resolves the platform-agnostic `.chb` and sources, and the
   consumer's compiler produces whatever native code that platform needs
   (Mach-O on Darwin, ELF on Linux).

## Verification

A `mac-smoke` job in `.github/workflows/ci.yml` (gated on `lint`,
runs on `macos-latest` for pushes to `main`) downloads the Darwin chelis
toolchain, installs Nautilus into the Reef registry, and runs
`chelis reef build` against this repo's source. That's enough to
prove the artifacts work end-to-end under Darwin chelis. The full
test suite (`chelis test tests/ --jobs auto`,
`parity/run_parity.py --strict`, the documentation validators) runs
only on Linux x86_64 — duplicating
it on macOS would be ~10× the runner cost without producing
substantively new evidence, since the underlying Coral source is
identical and the platform boundary is the chelis toolchain.

If the smoke job breaks, the failure mode tells us something
specific:

- chelis missing the darwin-arm64 tarball → upstream release process
  bug.
- Darwin chelis can't resolve Nautilus → the registry setup has a
  Linux-only assumption that needs fixing.
- `chelis reef build` produces different-shaped output on Mac → the
  `.chb` format would no longer be platform-agnostic, contradicting
  the premise of this document.

## Non-goal: do NOT add platform suffixes to Coral release artifacts

Future contributors who notice that core chelis ships
`chelis-vX.Y.Z-linux-x86_64-glibc2.31.tar.gz` and
`chelis-vX.Y.Z-darwin-arm64.tar.gz` may feel the urge to mirror that
two-tarball pattern in Coral. Don't. The artifacts are intentionally
cross-platform. The reasons are above; if you find yourself disagreeing
with them, re-read this file, then look at what's actually inside a
`.chb` (`zstd -d coral-X.Y.Z.chb -o coral-X.Y.Z.chb.bin && file
coral-X.Y.Z.chb.bin && strings coral-X.Y.Z.chb.bin | head`) before
proposing a change.

The sibling shell `Chelis-Lang/nautilus` follows the same policy in
its own `docs/releases.md`. If you change Coral's policy here,
mirror the change in nautilus or document the divergence with a
recorded reason (per the "Scaffolding Drift Rule" in `AGENTS.md`).
