# Coral Status

Coral 0.7.43 targets official Chelis 0.18.11 and published Nautilus 0.7.46.
The package build, 80 positive tests, six negative cases, one blocked parser
probe, eleven SKILL examples, eight book examples, and strict pandas parity
pass locally. This is not a hosted-CI, review or publication claim. The receipt is
[the 0.18.11 migration note](chelis_0_18_11_migration.md); the preceding complete
local gate is recorded in [the 0.18.10 receipt](chelis_0_18_10_migration.md).

The maintained implementation covers persistent HAMT-backed typed frames,
column selection and mutation, filtering, grouping, joins, reshaping, rolling
windows, and CSV/JSON input and output. `Frame.columns` has no plain `Dict`
fallback. The native test suite owns internal correctness; pandas-derived
goldens and native window checks remain a separate parity oracle.

At 0.18.11, dependency-independent validation passes source formatting,
executable-doc formatting, workflow/parity contract tests, the pandas golden
comparison, native rolling-mean/EWM checks, and native NaN mask/drop-core/
count/any execution. Tensor `neq` now passes the NaN IEEE probe in both eval
and native C, so `is_nan` no longer uses a scalar host-map. The parser's
one-expression-block rejection remains verified with an isolated probe.
The full bare-C module smokes still reproduce the documented function-value
ownership-signature limitation (chelis#2097).

Remaining scope limits:

- Parquet runtime support remains deferred.
- Direct tensor/scalar comparisons are rejected; threshold masks map an
  explicit scalar predicate before conversion to a tensor.
- Full Frame-read native lowering remains separate from package/evaluator
  correctness. Standalone helper success does not prove those paths; the
  migration receipt records the package-frame and bare-module re-probes.
- AD through Coral's host-list algorithms and GPU phase acceptance are not
  claimed by these checks.
- GroupBy, Join and IO pandas runtime parity, NaN-bearing sort semantics,
  and broader error-surface coverage are not certified by window parity.

`docs/UPSTREAM_BUGS.md` owns retained limitations and their re-probe triggers;
`spec/phase3k.md` owns the broader phase target rather than current completion.
