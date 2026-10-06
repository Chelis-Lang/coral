# Resolved upstream bug records


- **chelis#849**, a newline before `else` inside a `{ }` block rejected at
  parse time. Fixed upstream and verified on 0.18.11: the form parses and
  evaluates. The former blocked probe no longer tested this bug (it failed on
  the intended one-expression-block rule instead) and was retired. It cannot
  become a regression test because `chelis fmt` rewrites the form onto one
  line, which is also the layout `parity/run_parity.py` generates.
- **chelis#630**, native tensor `neq` not IEEE-correct at NaN. Fixed at
  0.18.11. `Coral.Frame.is_nan` uses `neq(col, col)` directly, and
  `scripts/repro_native_neq.py` and `scripts/repro_native_nan.py` are the
  native regressions; `tests/types.ch` covers the borrowed-operand typing.
- **chelis#405**, scalar `grad` in the C backend. Verified on 0.18.11:
  `grad` of a scalar function builds and runs natively. Coral never depended
  on it; gradients through Coral remain deferral D5 in `spec/scope.md`.
- **chelis#2068**, a native C liveness error on a by-value scalar passed to
  several argument slots of a tail call. It surfaced through Nautilus code in
  Coral's native probes and was verified fixed on 0.18.10; Coral never
  narrowed for it. The upstream issue remains open.
- **chelis#1200**, `_ = f(x)` marking `x` consumed. Fixed at 0.18.5;
  `tests/linearity.ch` is the regression.
- **chelis#646** (empty-tensor `numel`) and **chelis#647** (`not` on a bool
  tensor). Fixed at 0.18.1; Coral uses both directly, and the empty-column
  and NaN-drop tests cover them.
- **chelis#941** and its successor **chelis#1158**, recursive generic host
  calls rejected in native builds, which made `Frame` construction
  impossible there. Fixed at 0.18.5; the remaining Frame-read boundary is
  chelis#1226 above.
- **chelis#935**, nullary generic constructors losing their type arguments in
  C lowering. Fixed at 0.17.4.
- **Unbound `|>` pipe targets accepted in large native builds** (a parked,
  never-filed draft). The original reproducer is correctly rejected with
  `UnboundVariable` on 0.17.1 and on 0.18.11, so the draft was retired
  without filing. `tests_neg/frame/unbound_function_neg.ch` pins the
  rejection of a single unbound direct call.
