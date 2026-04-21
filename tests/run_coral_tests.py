#!/usr/bin/env python3
"""Coral repo checks.

Current scope:
  1. typecheck the shell entrypoints and frame/HAMT core
  2. validate that checked-in frame goldens exist and match pandas when available
  3. keep a compile-level probe for HAMT-backed Frame operations while the
     v0.1.13 runtime path remains partially blocked upstream
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()
FRAME_GOLDENS = REPO / "tests" / "goldens" / "frame"
REQUIRED_GOLDENS = [
    "README.json",
    "base.json",
    "filter_flag_true.json",
    "head_2.json",
    "tail_2.json",
    "slice_1_3.json",
    "rename_price_to_cost.json",
    "with_column_total.json",
    "drop_city.json",
    "fill_nan_price.json",
    "drop_nan_price.json",
    "concat_base_parts.json",
    "describe_numeric.json",
]


def run(*args: str) -> int:
    proc = subprocess.run(args, cwd=str(REPO), capture_output=True, text=True)
    payload = (proc.stdout + proc.stderr).strip()
    if payload:
        print(payload)
    if proc.returncode != 0:
        return proc.returncode
    if not payload:
        return 0
    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return 0
    return 1 if data.get("errors") else 0


def run_phase1_compile_probe() -> int:
    code = """module Coral.Phase1Probe
import Coral.Internal.HAMT (hamt_from_pairs, hamt_put, hamt_get, hamt_remove, hamt_contains, hamt_size)
import Coral.Frame (from_pairs, columns, with_column, rename, drop_column, concat, describe, get_float_col, nrows, ncols)

def string_list_eq(lhs: List[string], rhs: List[string]) -> bool = {
  if neq(len(lhs), len(rhs)) then false else string_list_eq_rec(lhs, rhs)
}

def string_list_eq_rec(lhs: List[string], rhs: List[string]) -> bool = {
  if eq(len(lhs), cast(0, int64)) then true
  else if neq(index(lhs, cast(0, int64)), index(rhs, cast(0, int64))) then false
  else string_list_eq_rec(drop(lhs, cast(1, int64)), drop(rhs, cast(1, int64)))
}

def option_int_eq(value: Option[int64], expected: int64) -> bool = {
  match value with {
    | Some(found) => eq(found, expected)
    | None => false
  }
}

def main() -> f32 = {
  base = hamt_from_pairs([("price", cast(1, int64)), ("qty", cast(2, int64))])
  next = hamt_put(base, "flag", cast(3, int64))
  final = hamt_remove(next, "qty")
  frame = from_pairs([
    ("a", IntCol(to_tensor([cast(1, int64), cast(2, int64)]))),
    ("b", FloatCol(to_tensor([cast(1.0, f32), div(cast(0.0, f32), cast(0.0, f32))]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)]))))
  ])
  renamed = rename(frame, "a", "z")
  extended = with_column(renamed, "c", IntCol(to_tensor([cast(3, int64), cast(4, int64)])))
  dropped = drop_column(extended, "b")
  stacked = concat([dropped, dropped])
  desc = describe(frame)
  ok_hamt =
    and(eq(hamt_size(final), cast(2, int64)),
      and(hamt_contains(final, "price"),
        and(not(hamt_contains(final, "qty")),
          and(option_int_eq(hamt_get(final, "price"), cast(1, int64)), option_int_eq(hamt_get(final, "flag"), cast(3, int64))))))
  ok_order =
    and(string_list_eq(columns(renamed), ["z", "b", "flag"]),
      and(string_list_eq(columns(extended), ["z", "b", "flag", "c"]), string_list_eq(columns(dropped), ["z", "flag", "c"])))
  ok_more =
    and(eq(nrows(stacked), cast(4, int64)),
      and(eq(ncols(desc), cast(3, int64)), neq(index(to_list(get_float_col(desc, "b")), cast(0, int64)), cast(0.0, f32))))
  if and(ok_hamt, and(ok_order, ok_more)) then cast(1.0, f32) else cast(0.0, f32)
}
"""
    tmp = REPO / "src" / "phase1probe.ch"
    try:
        tmp.write_text(code)
        return run(CHELIS, "check", str(tmp))
    finally:
        tmp.unlink(missing_ok=True)


def validate_checked_in_goldens() -> int:
    for name in REQUIRED_GOLDENS:
        path = FRAME_GOLDENS / name
        if not path.exists():
            print(f"missing golden: {path.relative_to(REPO)}")
            return 1
        json.loads(path.read_text())
    print(f"frame golden inventory OK ({len(REQUIRED_GOLDENS)} files)")
    return 0


def run_pandas_check_if_available() -> int:
    try:
        import pandas  # noqa: F401
    except ModuleNotFoundError:
        print("pandas not installed; skipping `scripts/gen_goldens.py --check`")
        return 0

    proc = subprocess.run(
        [sys.executable, "scripts/gen_goldens.py", "--check"],
        cwd=str(REPO),
        capture_output=True,
        text=True,
    )
    payload = (proc.stdout + proc.stderr).strip()
    if payload:
        print(payload)
    return proc.returncode


def main() -> int:
    steps = [
        (CHELIS, "check", "src/core.ch"),
        (CHELIS, "check", "src/apismoke.ch"),
        (CHELIS, "check", "src/internal/hamt.ch"),
        (CHELIS, "check", "src/frame.ch"),
    ]
    for step in steps:
        if run(*step) != 0:
            return 1
    if validate_checked_in_goldens() != 0:
        return 1
    if run_pandas_check_if_available() != 0:
        return 1
    if run_phase1_compile_probe() != 0:
        return 1
    print("phase1 runtime smoke skipped: `chelis build` currently hangs on a HAMT-backed Coral probe under v0.1.13; see docs/UPSTREAM_BUGS.md")
    print("coral repo checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
