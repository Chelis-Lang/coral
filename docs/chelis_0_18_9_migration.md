# Chelis 0.18.9 migration

Coral advances with the C Note dependency chain. This release requires the
published Chelis 0.18.9 and Nautilus 0.7.44, with the canonical compiler bump
and fresh compiler-bound artifacts.

Explicit export enforcement exposes two existing cross-module dependencies:
Frame uses Hamt's `char_code`, and Reshape uses Frame's `column_len`. The
owners export those helpers and the consumers import them. The column-length
regressions cover all four variants, both empty and populated, and retain
scalar rejection.

The threshold example maps its scalar comparison over the price values and
converts the boolean list to a tensor mask. The same three rows and sum 600
remain the oracle. Tensor/scalar comparison remains a compile-time rejection.

0.18.9 also tracks each Frame's row count as a type-level literal. The
`Coral.Frame.concat` book example previously stacked a two-row and a one-row
frame, which the tightened checker rejects because `concat[n, k](frames:
List[Frame[n]])` requires one shared row count `n`; the example now stacks two
two-row frames into a four-row result. The `if`/`else`-newline parser probe
(`tests_blocked/parser/if_else_newline.ch`) stays blocked, and its pinned
diagnostic was re-cited from `expected Else, found Eof` to the 0.18.9 wording
`expected binding before the tail expression; use `do` for sequencing`
(chelis#849 with chelis#1031's one-expression-block rule).

## Published toolchain identity

Chelis 0.18.9, tag `v0.18.9`, tag commit
`abff07b47eadc8d2be633e3a7d21220089befb6f`.

- Darwin arm64 archive SHA-256
  `44e12cf187b37cb6d2a617e1573832a1bdcaa0e1564f59c4029e24081a84905d`;
  extracted `bin/chelis` SHA-256
  `68e460df6e796891fb30c42904b0309b4d5e83d187944222faaaae63241101c7`. The gate
  ran on this installed Darwin payload.
- Linux glibc-2.31 archive SHA-256
  `9aed0afbfc93a96a6804b4c82664869d74815bd27ca824dfeab02088b00ddb63`;
  compiler payload SHA-256
  `efe99c09f5d7d7372065206a332a2fd86b8aee77412262b0028cfbdbc98a19f2`. This is
  the CI toolchain default; its gate run is CI's.

Nautilus 0.7.44, tag `v0.7.44`, source commit
`aa50d1c7c911dbebb3f379c0a86b6690b139b9af`. Release assets verified against the
sidecar: CHB SHA-256
`58a02e90957bf36cdfa0e995a7c14c397790956b6e6d0bbb060caea2d4b399c1`, archive
SHA-256 `8c7a9d79a4fad87340e58bce06525cb2210c3344acf09bca03efe489a16d2bb0`.
Installed with `chelis reef install --from-github Chelis-Lang/nautilus@v0.7.44`,
the path CI uses. The regenerated local `reef.lock` binds both `nautilus` and
`chelis-std 0.4.0` to compiler `=0.18.9`.

Coral 0.7.41 `chelis reef build` outputs, pending publication of the `v0.7.41`
release assets: CHB SHA-256
`cafd7fac4d66a4b8a1302cbdee63b2c9d711355f2fc42619947a69f7e0cea010`, archive
SHA-256 `50c8a61c3a7b0d3a87c979566ec3e38fc14c5d35a38bcf7a4b116249ce5470ee`.

## Validation status

The gate ran on the published Chelis 0.18.9 Darwin arm64 binary against
Nautilus 0.7.44. Every shipping and CI-gated lane passes: per-file
`fmt --check`, `lint --check .`, `reef build`, the native suite
`test tests/ --timeout 600 --jobs auto` (80 of 80 tests, 50.16 s),
`test tests_neg/ --expect neg`, `test tests_blocked/ --expect blocked` (1 ok),
the strict pandas parity gate, the parity generator contract,
`run_static_checks.py`, `run_skill_checks.py` (11 of 11),
`validate_book_examples.py` (8 of 8), a second `reef build`,
`reef conform audit --explain` (conformant, no MUST failures), and
`reef conform bump-check --base origin/main` (pin change 0.18.6 to 0.18.9,
audit green).

The one lane that does not pass locally is the native bare-build multimodule
probe `scripts/repro_multimodule_bare_build.py`, which fails while native-C
lowering Nautilus's `special__airy_gg` with `owner %1 ... is not live` under
the 0.18.9 checker. That probe is a native bare-build lane, documented as not a
shipping lane, and it is not run by CI. Coral ships as a Reef package consumed
through `chelis eval` and `reef build`, neither of which is affected. Coral
source does not reference the Nautilus special functions.

Sonar records the gate under `landing/runs/g8-coral-local-gate-0189-v5/` (and
the earlier `-v3` and `-v4` runs that isolated the book-example and bare-build
findings).
