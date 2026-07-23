# Draft: `Std.Io.Parquet` exports signatures with no runtime backing (`read_parquet` / `write_parquet` unimplemented)

**Target:** `Chelis-Lang/chelis`
**Filing condition:** this is a missing-feature request, not a regression.
File once Coral (or another shell) has a concrete Parquet use case worth
prioritizing the runtime work for, or when upstream signals movement on the
`Std.Io` runtime surface. Search the tracker for an existing `Std.Io.Parquet`
feature request before filing.

## Observed (re-probed through chelis 0.16.1, macOS arm64)

`chelis-std`'s `io/parquet.ch` exports the `read_parquet` / `write_parquet`
signatures only — there are no callable function bodies behind them, so the
symbols resolve at check time but have no runtime backing:

- `import Std.Io.Parquet (read_parquet)` checks at score 1.0 on every release
  probed (v0.4.0, v0.5.0, v0.7.6, and the 0.16.1 pin bump).
- `libchelis_runtime.a` contains no `Parquet` / `read_parquet` symbol at any of
  those pins.
- The C build reaches the native-link failure because the runtime symbol is
  absent (v0.5.0); at v0.7.6 the C build stops earlier with `range start index
  2 out of range for slice of length 1`.

The user-visible conclusion is unchanged across every probe: Parquet I/O is
unavailable at runtime.

## Expected

Either a callable runtime implementation behind `read_parquet` / `write_parquet`,
or an honest check-time diagnostic when a program imports an export that has no
runtime backing (rather than a score-1.0 check followed by a link failure or an
out-of-range panic in the C build).

## Coral's current handling

Coral ships `read_parquet_frame` / `write_parquet_frame` as `fail(...)` stubs in
`src/io.ch` so the unavailable surface fails loudly rather than mis-compiling.
Restore real Parquet-backed frame I/O once the upstream runtime exists.
