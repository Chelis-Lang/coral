#!/usr/bin/env python3
"""Lightweight Coral repo checks.

This is the first-pass harness surface. It focuses on package-level
checks plus a Phase 1 compile probe for Frame/HAMT invariants.
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
import Coral.Frame (from_pairs, columns, with_column, rename, drop_column)

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
  frame = from_pairs([("a", IntCol(to_tensor([cast(1, int64)]))), ("b", IntCol(to_tensor([cast(2, int64)])))])
  renamed = rename(frame, "a", "z")
  extended = with_column(renamed, "c", IntCol(to_tensor([cast(3, int64)])))
  dropped = drop_column(extended, "b")
  ok_hamt =
    and(eq(hamt_size(final), cast(2, int64)),
      and(hamt_contains(final, "price"),
        and(not(hamt_contains(final, "qty")),
          and(option_int_eq(hamt_get(final, "price"), cast(1, int64)), option_int_eq(hamt_get(final, "flag"), cast(3, int64))))))
  ok_order =
    and(string_list_eq(columns(renamed), ["z", "b"]),
      and(string_list_eq(columns(extended), ["z", "b", "c"]), string_list_eq(columns(dropped), ["z", "c"])))
  if and(ok_hamt, ok_order) then cast(1.0, f32) else cast(0.0, f32)
}
"""
    tmp = REPO / "src" / "phase1probe.ch"
    try:
        tmp.write_text(code)
        return run(CHELIS, "check", str(tmp))
    finally:
        tmp.unlink(missing_ok=True)


def main() -> int:
    steps = [
        (CHELIS, "check", "src/core.ch"),
        (CHELIS, "check", "src/apismoke.ch"),
    ]
    for step in steps:
        if run(*step) != 0:
            return 1
    if run_phase1_compile_probe() != 0:
        return 1
    print("phase1 runtime smoke skipped: `chelis build` currently hangs on a HAMT-backed Coral probe under v0.1.13; see docs/UPSTREAM_BUGS.md")
    print("coral repo checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
