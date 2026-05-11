# Changelog

All notable changes to this project are documented here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [0.7.6] — 2026-05-11

Compiler and dependency alignment release. Tracks chelis 0.7.6 and
nautilus 0.7.6, consumes released Chelis binaries in CI, and cuts the
native Chelis test lane over from per-file matrix sharding to
`chelis test tests/ --jobs auto`.

Validation recorded in `docs/testing_cutover_0.7.6.json`:

- `chelis test tests/ --jobs auto`: 65 passed, 0 failed, 0:34.06
- `chelis test tests/ --jobs 1`: 65 passed, 0 failed, 0:38.72

## [0.6.1] — 2026-05-06

Compiler-pin alignment release. Tracks chelis 0.6.0 → 0.6.1
(bootstrap-list patch) and nautilus 0.6.0 → 0.6.1 (companion
alignment). No source changes from 0.6.0 — only version + pin
bumps to align with chelis 0.6.1.

## [0.6.0] — 2026-05-06

Naming-convention release. Aligns coral with the recorded style
guide in `chelis/spec/01-nomenclature.md`. Track-forward for chelis
0.6.0 / chelis-std 0.2.0 / nautilus 0.6.0.

### Changed (breaking) — `Coral.Frame` `_int → _col` family per §7.2

Five paired NaN-handling functions renamed:

| Old              | New              |
|------------------|------------------|
| `is_nan_int`     | `is_nan_col`     |
| `any_nan_int`    | `any_nan_col`    |
| `count_nan_int`  | `count_nan_col`  |
| `fill_nan_int`   | `fill_nan_col`   |
| `drop_nan_int`   | `drop_nan_col`   |

The `_int` suffix in the old names was misleading: it didn't
describe the element type of the principal argument (which is a
`Frame`, not int data) — it meant "Frame-form variant accepting an
int column name." The §7.2 type-suffix policy reserves element-type
suffixes for monomorphizing element types; container-form
distinction goes through a distinct verb instead. The `_col` suffix
unambiguously names "column-form variant of the same operation,"
with column dtype inferred when the column is fetched.

### Changed (breaking) — module renames per §6.2

| Old                       | New                       |
|---------------------------|---------------------------|
| `Coral.Internal.HAMT`     | `Coral.Internal.Hamt`     |
| `Coral.IO`                | `Coral.Io`                |
| `Coral.Tests.IO`          | `Coral.Tests.Io`          |

Per §6.2 (Title-case compounds, never ALL-CAPS abbreviations).
Within-pair alignment: `Coral.Internal.Hamt` exports the `Hamt`
type constructor, matching the new module name.

### Changed — `Std.IO` → `Std.Io` import-side updates

Coral source modules now import `Std.Io` (and `Std.Io.Csv`,
`Std.Io.Json`) instead of `Std.IO`. Track-forward for the chelis-std
0.2.0 rename.

### Changed — compiler pin bumped to `=0.6.0`

`reef.toml` now requires:
- chelis-std 0.2.0 (was 0.1.0)
- nautilus 0.6.0 (was 0.5.0)
- compiler =0.6.0 (was =0.5.0)

Downstream consumers (e.g., shoals) must bump their pins to match.

### Style guide

Adheres to `chelis/spec/01-nomenclature.md`. Local `STYLE.md` is a
one-line pointer at the central guide. Coral.Frame's data-domain
prefixes (`agg_/list_/key_/hash_/enum_/char_/ints_/melt_/csv_/json_/
left_/join_/...`) are recognized as common-verb idioms by the
chelis-lint allowlist.
