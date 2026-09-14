# Chelis 0.18.8 migration

Coral advances with the C Note dependency chain. The final package requires
published Chelis 0.18.8 and Nautilus 0.7.44, with the canonical compiler bump
and fresh compiler-bound artifacts.

Explicit export enforcement exposes two existing cross-module dependencies:
Frame uses Hamt's `char_code`, and Reshape uses Frame's `column_len`. The
owners export those helpers and the consumers import them. The column-length
regressions cover all four variants, both empty and populated, and retain
scalar rejection.

The threshold example maps its scalar comparison over the price values and
converts the boolean list to a tensor mask. The same three rows and sum 600
remain the oracle. Tensor/scalar comparison remains a compile-time rejection.

## Validation status

An isolated provisional Nautilus registry supports migration probes only.
The repaired compiler candidate passes all 80 native tests in 76.70 s.
Published Chelis 0.18.7 passes the strict Pandas comparison, focused column
and threshold cases, and their negative controls. Sonar records these under
`landing/runs/g5-coral-combined-native-suite/`,
`landing/runs/g5-coral-provisional-strict-parity/` and the focused
`g5-coral-column-length-*` / `g5-coral-threshold-*` receipts.

The earlier full suite on published 0.18.7 timed out. It is not acceptance.
The final published 0.18.8 / Nautilus 0.7.44 full gate and release hashes are
pending. Do not publish until this pending marker is replaced by that record.
