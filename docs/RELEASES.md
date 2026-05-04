# Coral Releases

## What Coral publishes per release

Each Coral release on GitHub ships exactly two artifacts:

- `coral-X.Y.Z.chb` (≈13 KB) — Reef shell package
- `coral-X.Y.Z.tar.zst` (≈13 KB) — source archive

Both are produced by `chelis reef build` + `chelis reef publish`.
Neither is platform-specific.

## Why the artifacts are platform-agnostic

The `.tar.zst` is the source tree (`reef.toml`, `reef.lock`, the nine
`.ch` files under `src/`). Identical bytes regardless of build host.

The `.chb` is a Zstandard-compressed envelope containing
desugared/type-checked AST + module exports + type signatures +
effects + dependency list. No ELF, no Mach-O, no `.o`, no `.a`.
Verified via `strings`: contains UTF-8 names like `"coral"`,
`"Coral.Frame"`, type signatures in IR form. Contains zero platform
references.

Compare to chelis itself, which ships per-platform binaries:

- `chelis-vX.Y.Z-linux-x86_64.tar.gz`
- `chelis-vX.Y.Z-darwin-arm64.tar.gz`

Inside those: `bin/chelis` is a Rust-compiled binary (ELF on Linux,
Mach-O on Darwin); `lib/libchelis_runtime.a` is a platform-specific
static archive. **chelis's tarballs must be platform-specific because
they contain native code. Coral's `.chb` + `.tar.zst` must not be —
the IR is the contract; the consumer compiles to their platform.**

## How a Mac (or any) user consumes Coral

End-to-end, with no platform-specific Coral artifact required:

1. Download the chelis toolchain that matches the consumer's OS:
   ```sh
   gh release download v0.5.0 --repo Chelis-Lang/chelis \
     --pattern 'chelis-v0.5.0-darwin-arm64.tar.gz'
   ```
   (or `linux-x86_64` for Linux consumers).
2. Extract and put `bin/chelis` on PATH.
3. Publish Coral into the consumer's local reef registry from the
   release artifact:
   ```sh
   chelis reef publish coral-0.5.0.tar.zst
   ```
4. In their own Chelis project's `reef.toml`:
   ```toml
   [dependencies]
   coral = { version = "0.5.0" }
   ```
5. `chelis reef build` resolves the platform-agnostic `.chb` +
   sources; the consumer's chelis compiles the result to whatever
   native code that platform requires (Mach-O on Darwin, ELF on
   Linux, etc.).

The same `.chb` and `.tar.zst` we publish today work unchanged for
this flow on every platform the chelis toolchain supports.

## Verification

A `mac-smoke` job in `.github/workflows/ci.yml` (gated on `lint`,
runs on `macos-latest`) downloads the Darwin chelis toolchain,
populates the reef registry with chelis-std + nautilus, and runs
`chelis reef build` against this repo's source. That's enough to
prove the artifacts work end-to-end under Darwin chelis. The full
test suite (`chelis test tests/`, `parity/run_parity.py --strict`,
the documentation validators) runs only on Linux x86_64 — duplicating
it on macOS would be ~10× the runner cost without producing
substantively new evidence, since the underlying Coral source is
identical and the platform boundary is the chelis toolchain.

If the smoke job breaks, the failure mode tells us something
specific:

- chelis missing the darwin-arm64 tarball → upstream release process
  bug.
- Darwin chelis can't resolve chelis-std or nautilus → registry
  setup script has a Linux-only assumption that needs fixing.
- `chelis reef build` produces different-shaped output on Mac → the
  `.chb` format would no longer be platform-agnostic, contradicting
  the premise of this document.

## Non-goal: do NOT add platform suffixes to Coral release artifacts

Future contributors who notice that core chelis ships
`chelis-vX.Y.Z-linux-x86_64.tar.gz` and
`chelis-vX.Y.Z-darwin-arm64.tar.gz` may feel the urge to mirror that
two-tarball pattern in Coral. Don't. The artifacts are intentionally
cross-platform. The reasons are above; if you find yourself disagreeing
with them, re-read this file, then look at what's actually inside a
`.chb` (`zstd -d coral-X.Y.Z.chb -o coral-X.Y.Z.chb.bin && file
coral-X.Y.Z.chb.bin && strings coral-X.Y.Z.chb.bin | head`) before
proposing a change.

The sibling shell `Chelis-Lang/nautilus` follows the same policy in
its own `docs/RELEASES.md`. If you change Coral's policy here,
mirror the change in nautilus or document the divergence with a
recorded reason (per the "Scaffolding Drift Rule" in `CLAUDE.md`).
