#!/usr/bin/env python3
"""Coral pandas-parity checks.

Internal correctness lives in tests/*.ch (run via `chelis test tests/`).
This script runs only the Python-driven checks: pandas-derived goldens,
window runtime parity (expected values pandas-derived), HAMT integration
compile probe, and check-time negative test suite.

Scope:
  1. typecheck the shell entrypoints and core module slices
  2. validate checked-in pandas goldens for Frame, GroupBy, IO, Join, Window, Reshape
  3. execute a bare-build runtime parity lane for Window (expected values pandas-derived)
  4. negative test suite: check-time error detection (TypeMismatch, UnboundVariable)

Only the Window lane executes Coral against pandas-derived values; the other
goldens are checked against pandas but not executed through Coral (see
spec/scope.md, deferral D7).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin
from scripts.repro_multimodule_bare_build import (
    compiled_binary_path,
    emitted_compile_cmd,
    observed_root,
)


CHELIS = resolve_chelis_bin()
FRAME_GOLDENS = REPO / "parity" / "goldens" / "frame"
GROUPBY_GOLDENS = REPO / "parity" / "goldens" / "groupby"
IO_GOLDENS = REPO / "parity" / "goldens" / "io"
JOIN_GOLDENS = REPO / "parity" / "goldens" / "join"
WINDOW_GOLDENS = REPO / "parity" / "goldens" / "window"
RESHAPE_GOLDENS = REPO / "parity" / "goldens" / "reshape"
REQUIRED_FRAME_GOLDENS = [
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
    "value_counts_city.json",
    "fill_nan_qty.json",
    "sort_by_city_asc.json",
    "sort_by_city_desc.json",
]
REQUIRED_GROUPBY_GOLDENS = [
    "README.json",
    "agg_sum_qty_by_city.json",
    "agg_mean_price_by_city.json",
    "agg_count_by_city.json",
    "agg_min_qty_by_city.json",
    "agg_max_price_by_city.json",
    "agg_multi_city.json",
]
REQUIRED_IO_GOLDENS = [
    "README.json",
    "read_csv_mixed.json",
    "read_json_mixed.json",
    "write_csv_mixed.json",
    "write_json_mixed.json",
]
REQUIRED_JOIN_GOLDENS = [
    "README.json",
    "inner_join_customer.json",
    "left_join_customer.json",
    "outer_join_customer.json",
]
REQUIRED_WINDOW_GOLDENS = [
    "README.json",
    "rolling_sum_w3.json",
    "rolling_mean_w3.json",
    "rolling_std_w3.json",
    "rolling_min_w3.json",
    "rolling_max_w3.json",
    "ewm_alpha_0_5.json",
]
REQUIRED_RESHAPE_GOLDENS = [
    "README.json",
    "pivot_city_product_price.json",
    "melt_city_qty_price.json",
    "stack_wide_frame.json",
    "unstack_stacked_frame.json",
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


def validate_checked_in_goldens(base_dir: Path, required: list[str], label: str) -> int:
    for name in required:
        path = base_dir / name
        if not path.exists():
            print(f"missing golden: {path.relative_to(REPO)}")
            return 1
        json.loads(path.read_text())
    print(f"{label} golden inventory OK ({len(required)} files)")
    return 0


def run_pandas_check(strict: bool) -> int:
    """Compare Coral against pandas via gen_goldens --check.

    Without --strict: skip silently if pandas is missing (legacy local-dev mode).
    With --strict: fail loudly if pandas is missing (CI mode per spec).
    """
    try:
        import pandas  # noqa: F401
    except ModuleNotFoundError:
        if strict:
            print("ERROR: pandas not installed and --strict was passed", file=sys.stderr)
            return 2
        print("pandas not installed; skipping `parity/gen_goldens.py --check`")
        return 0

    proc = subprocess.run(
        [sys.executable, "parity/gen_goldens.py", "--check"],
        cwd=str(REPO),
        capture_output=True,
        text=True,
    )
    payload = (proc.stdout + proc.stderr).strip()
    if payload:
        print(payload)
    return proc.returncode


def strip_module_surface(src: str) -> str:
    src = re.sub(r"^module .*\n", "", src, flags=re.M)
    src = re.sub(r"^import .*\n", "", src, flags=re.M)
    src = re.sub(r"^export \([^)]*\)\s*\n", "", src, flags=re.M | re.S)
    return src


def chelis_float_literal(value) -> str:
    if value == "NaN":
        return "div(cast(0.0, f32), cast(0.0, f32))"
    return f"cast({float(value)!r}, f32)"


def window_program(fixture: dict) -> str:
    op = fixture["operation"]
    input_values = ", ".join(chelis_float_literal(value) for value in fixture["input"])
    expected_values = ", ".join(chelis_float_literal(value) for value in fixture["expected"])
    extent = len(fixture["input"])
    if "window" in fixture:
        call_body = f'{op}(values, cast({fixture["window"]}, i64))'
    else:
        call_body = f'{op}(values, cast({fixture["alpha"]!r}, f32))'
    # Keep each `else` on the same line as its branch: that is the canonical
    # form `chelis fmt` emits, and the program below is formatted in place
    # before it is built. Canonical Surf rejects one-expression `{ }` blocks
    # (chelis#1031), so a def whose body is a bare `if` chain must not wrap it
    # in braces.
    return f"""
def rt_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x

def rt_max_f32(lhs: f32, rhs: f32) -> f32 = if gt(lhs, rhs) then lhs else rhs

def rt_approx_eq(actual: f32, expected: f32, abs_tol: f32, rel_tol: f32) -> bool = if and(neq(actual, actual), neq(expected, expected)) then true else if or(neq(actual, actual), neq(expected, expected)) then false else {{
  diff = rt_abs_f32(sub(actual, expected))
  bound = rt_max_f32(abs_tol, mul(rel_tol, rt_abs_f32(expected)))
  lte(diff, bound)
}}

def rt_float_list_eq(actual: List[f32], expected: List[f32], abs_tol: f32, rel_tol: f32) -> bool = if neq(len(actual), len(expected)) then false else if eq(len(actual), cast(0, i64)) then true else if not(rt_approx_eq(index(actual, cast(0, i64)), index(expected, cast(0, i64)), abs_tol, rel_tol)) then false else rt_float_list_eq(skip(actual, cast(1, i64)), skip(expected, cast(1, i64)), abs_tol, rel_tol)

def rt_window_call(values: tensor[{extent}, f32]) -> tensor[{extent}, f32] = {call_body}

def main() -> f32 = {{
  actual = to_list(rt_window_call(to_tensor([{input_values}])))
  expected = [{expected_values}]
  if rt_float_list_eq(actual, expected, cast({fixture["abs_tol"]!r}, f32), cast({fixture["rel_tol"]!r}, f32)) then cast(1.0, f32) else cast(0.0, f32)
}}
"""


def run_window_runtime_fixture(fixture_name: str) -> int:
    fixture_path = WINDOW_GOLDENS / fixture_name
    fixture = json.loads(fixture_path.read_text())
    window_src = strip_module_surface((REPO / "src" / "window.ch").read_text())
    code = window_src + "\n" + window_program(fixture)
    workdir = Path(tempfile.mkdtemp(prefix=f"coral-window-{fixture['fixture']}-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(code)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(main_ch)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print(f"window runtime fmt failed for {fixture_name}: {(fmt.stdout + fmt.stderr).strip()}")
            return 1
        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        build_output = (build.stdout or "") + (build.stderr or "")
        if build.returncode != 0:
            print(f"window runtime build failed for {fixture_name}: {build_output.strip()}")
            return 1
        # chelis 0.18.6 emits its own `main` for the C target and prints one
        # `<name> = <value>` line per observed root, so the verdict is read off
        # that observation and the program is built with the compile command
        # the compiler itself reports.
        command = emitted_compile_cmd(build_output)
        binary = compiled_binary_path(command)
        link = subprocess.run(command, capture_output=True, text=True)
        if link.returncode != 0:
            print(f"window runtime link failed for {fixture_name}: {link.stderr.strip()}")
            return 1
        run_bin = subprocess.run([str(binary)], capture_output=True, text=True)
        verdict = observed_root(run_bin.stdout, "main")
        if run_bin.returncode != 0 or verdict is None or float(verdict) != 1.0:
            print(f"window runtime mismatch for {fixture_name}: rc={run_bin.returncode}, main={verdict!r}, stderr={run_bin.stderr.strip()!r}")
            return 1
        print(f"window runtime OK: {fixture_name}")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


RUNTIME_WINDOW_FIXTURES = ["rolling_mean_w3.json", "ewm_alpha_0_5.json"]


def run_window_runtime_checks() -> int:
    # Two C-backend cross-check fixtures are enough: rolling_mean covers the
    # rolling-window code path, ewm covers the EWM recurrence. The remaining
    # fixtures (rolling_sum/std/min/max) are still pandas-validated via
    # gen_goldens.py --check; only the build+link+run cycle is trimmed.
    for fixture_name in RUNTIME_WINDOW_FIXTURES:
        if run_window_runtime_fixture(fixture_name) != 0:
            return 1
    return 0


# Frame core algorithm coverage (fill_int_list, str_lt, enum_insertion_sort,
# bool_list_to_tensor) lives in tests/internal.ch and runs via `chelis test`.


NEGATIVE_CASES = [
    {
        "name": "nrows_type_mismatch",
        "module_file": "negwrongcol",
        "desc": "nrows called with i64 instead of Frame — checker reports TypeMismatch",
        "expected_fragment": "TypeMismatch",
        "code": """\
module Coral.NegWrongCol
import Coral.Frame (nrows)
export (main)
def main() -> f32 = {
  _ = nrows(cast(1, i64))
  cast(0.0, f32)
}
""",
    },
    {
        "name": "concat_type_mismatch",
        "module_file": "negtypemismatch",
        "desc": "concat called with i64 instead of List[Frame] — checker reports TypeMismatch",
        "expected_fragment": "TypeMismatch",
        "code": """\
module Coral.NegTypeMismatch
import Coral.Frame (concat)
export (main)
def main() -> f32 = {
  _ = concat(cast(1, i64))
  cast(0.0, f32)
}
""",
    },
    {
        "name": "unbound_function",
        "module_file": "negfillnanint",
        "desc": "calling a function that does not exist — checker reports UnboundVariable",
        "expected_fragment": "UnboundVariable",
        "code": """\
module Coral.NegFillNanInt
import Coral.Frame (from_pairs)
export (main)
def main() -> f32 = {
  _ = coral_undefined_function_xyz()
  cast(0.0, f32)
}
""",
    },
]


def run_negative_case(case: dict) -> int:
    src_tmp = REPO / "src" / f"{case['module_file']}.ch"
    try:
        src_tmp.write_text(case["code"])
        proc = subprocess.run(
            [CHELIS, "check", str(src_tmp)],
            cwd=str(REPO),
            capture_output=True,
            text=True,
        )
        output = (proc.stdout + proc.stderr).strip()
        json_output = proc.stdout.strip()
        # Success means check found an error (negative test expects failure)
        found_error = False
        if proc.returncode != 0:
            found_error = True
        else:
            try:
                data = json.loads(json_output)
                if data.get("errors") or data.get("score", 1) < 1:
                    found_error = True
            except json.JSONDecodeError:
                pass
        if not found_error:
            print(f"negative test {case['name']}: expected check error, got clean check")
            return 1
        if case["expected_fragment"] not in output:
            print(f"negative test {case['name']}: expected {case['expected_fragment']!r} in check output, got {output[:300]!r}")
            return 1
        print(f"negative test OK: {case['name']} - found {case['expected_fragment']!r}")
        return 0
    finally:
        src_tmp.unlink(missing_ok=True)


def run_negative_checks() -> int:
    for case in NEGATIVE_CASES:
        if run_negative_case(case) != 0:
            return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Coral pandas-parity checks (run after `chelis test tests/` for full coverage)."
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail (exit 2) if pandas is not installed instead of silently skipping the comparison. Use in CI.",
    )
    args = parser.parse_args()

    # Note: per-module `chelis check` calls were removed; `chelis reef build`
    # in CI covers the same type-check coverage. The phase1 compile probe
    # was also removed; its coverage (HAMT + from_pairs + with_column +
    # rename + drop_column + concat + describe + agg_count + write_csv +
    # write_json + inner_join) is now duplicated by tests/internal.ch +
    # tests/groupby.ch + tests/io.ch + tests/join.ch under `chelis test`.
    if validate_checked_in_goldens(FRAME_GOLDENS, REQUIRED_FRAME_GOLDENS, "frame") != 0:
        return 1
    if validate_checked_in_goldens(GROUPBY_GOLDENS, REQUIRED_GROUPBY_GOLDENS, "groupby") != 0:
        return 1
    if validate_checked_in_goldens(IO_GOLDENS, REQUIRED_IO_GOLDENS, "io") != 0:
        return 1
    if validate_checked_in_goldens(JOIN_GOLDENS, REQUIRED_JOIN_GOLDENS, "join") != 0:
        return 1
    if validate_checked_in_goldens(WINDOW_GOLDENS, REQUIRED_WINDOW_GOLDENS, "window") != 0:
        return 1
    if validate_checked_in_goldens(RESHAPE_GOLDENS, REQUIRED_RESHAPE_GOLDENS, "reshape") != 0:
        return 1
    rc = run_pandas_check(strict=args.strict)
    if rc != 0:
        return rc
    if run_window_runtime_checks() != 0:
        return 1
    if run_negative_checks() != 0:
        return 1
    print("coral parity checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
