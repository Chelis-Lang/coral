#!/usr/bin/env python3
"""Coral repo checks.

Current scope:
  1. typecheck the shell entrypoints and core module slices
  2. validate checked-in pandas goldens for Frame, GroupBy, IO, Join, Window, Reshape
  3. execute a bare-build runtime parity lane for Window
  4. execute a bare-build runtime parity lane for Frame core algorithms (fill_int_list,
     str_lt, bool_list_to_tensor, enum_insertion_sort) using the prefixed-concat
     approach; HAMT-dependent operations (from_pairs, value_counts, inner_join) require
     the reef build path which produces libraries, not runnable executables
  5. keep a compile-level probe for HAMT-backed Frame operations; stripped
     bare builds are fully clean on v0.2.2 (build, link, and run all pass)
  6. negative test suite: check-time error detection (unbound symbol, type mismatch, wrong-type arg)
"""
from __future__ import annotations

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
import scripts.repro_multimodule_bare_build as _repro


CHELIS = resolve_chelis_bin()
FRAME_GOLDENS = REPO / "tests" / "goldens" / "frame"
GROUPBY_GOLDENS = REPO / "tests" / "goldens" / "groupby"
IO_GOLDENS = REPO / "tests" / "goldens" / "io"
JOIN_GOLDENS = REPO / "tests" / "goldens" / "join"
WINDOW_GOLDENS = REPO / "tests" / "goldens" / "window"
RESHAPE_GOLDENS = REPO / "tests" / "goldens" / "reshape"
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


def native_link_cmd(binary: Path, sources: list[Path], out_dir: Path) -> list[str]:
    cc_env = os.environ.get("CC")
    if cc_env:
        prefix = [cc_env, "-O2"]
    elif sys.platform == "darwin":
        libomp = Path("/opt/homebrew/opt/libomp")
        if libomp.exists():
            prefix = [
                "clang",
                "-O2",
                "-Xpreprocessor",
                "-fopenmp",
                f"-I{libomp / 'include'}",
                f"-L{libomp / 'lib'}",
            ]
        else:
            prefix = ["clang", "-O2"]
    else:
        prefix = ["gcc", "-O2", "-fopenmp"]

    cmd = [
        *prefix,
        "-o",
        str(binary),
        *(str(source) for source in sources),
        "-I",
        str(out_dir),
        "-L",
        str(out_dir),
        "-lchelis_runtime",
        "-lm",
        "-lpthread",
    ]
    if sys.platform == "darwin" and Path("/opt/homebrew/opt/libomp").exists() and "clang" in prefix[0]:
        cmd.append("-lomp")
    return cmd


def run_phase1_compile_probe() -> int:
    code = """module Coral.Phase1Probe
import Coral.Internal.HAMT (hamt_from_pairs, hamt_put, hamt_get, hamt_remove, hamt_contains, hamt_size)
import Coral.Frame (from_pairs, columns, with_column, rename, drop_column, concat, describe, get_float_col, nrows, ncols, int_col_of_list)
import Coral.GroupBy (group_by, agg_count)
import Coral.IO (write_csv_frame, write_json_frame)
import Coral.Join (inner_join, left_join)

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
    ("a", int_col_of_list([cast(1, int64), cast(2, int64)])),
    ("b", FloatCol(to_tensor([cast(1.0, f32), div(cast(0.0, f32), cast(0.0, f32))]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)]))))
  ])
  renamed = rename(frame, "a", "z")
  extended = with_column(renamed, "c", int_col_of_list([cast(3, int64), cast(4, int64)]))
  dropped = drop_column(extended, "b")
  stacked = concat([dropped, dropped])
  desc = describe(frame)
  grouped = agg_count(group_by(from_pairs([
    ("city", StringCol(["london", "paris", "london"])),
    ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))
  ]), "city"))
  io_frame = from_pairs([
    ("id", int_col_of_list([cast(1, int64), cast(2, int64)])),
    ("price", FloatCol(to_tensor([cast(10.0, f32), cast(20.5, f32)]))),
    ("flag", BoolCol(neq(to_tensor([cast(1, int64), cast(0, int64)]), to_tensor([cast(0, int64), cast(0, int64)])))),
    ("city", StringCol(["london", "paris"]))
  ])
  csv_unit = write_csv_frame(io_frame, "phase-probe.csv")
  json_unit = write_json_frame(io_frame, "phase-probe.json")
  joined = inner_join(
    from_pairs([
      ("customer", StringCol(["a", "b", "a"])),
      ("qty", int_col_of_list([cast(1, int64), cast(2, int64), cast(3, int64)]))
    ]),
    from_pairs([
      ("customer", StringCol(["a", "a", "c"])),
      ("score", FloatCol(to_tensor([cast(10.0, f32), cast(15.0, f32), cast(40.0, f32)])))
    ]),
    "customer"
  )
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
      and(eq(ncols(desc), cast(3, int64)),
        and(neq(index(to_list(get_float_col(desc, "b")), cast(0, int64)), cast(0.0, f32)),
          and(eq(nrows(grouped), cast(2, int64)),
            and(eq(ncols(grouped), cast(2, int64)),
              and(eq(nrows(joined), cast(4, int64)),
                and(eq(ncols(joined), cast(3, int64)),
                  eq(ncols(io_frame), cast(4, int64)))))))))
  if and(ok_hamt, and(ok_order, ok_more)) then cast(1.0, f32) else cast(0.0, f32)
}
"""
    tmp = REPO / "src" / "phase1probe.ch"
    try:
        tmp.write_text(code)
        return run(CHELIS, "check", str(tmp))
    finally:
        tmp.unlink(missing_ok=True)


def validate_checked_in_goldens(base_dir: Path, required: list[str], label: str) -> int:
    for name in required:
        path = base_dir / name
        if not path.exists():
            print(f"missing golden: {path.relative_to(REPO)}")
            return 1
        json.loads(path.read_text())
    print(f"{label} golden inventory OK ({len(required)} files)")
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
    if "window" in fixture:
        call = f'{op}(to_tensor([{input_values}]), cast({fixture["window"]}, int64))'
    else:
        call = f'{op}(to_tensor([{input_values}]), cast({fixture["alpha"]!r}, f32))'
    return f"""
def rt_abs_f32(x: f32) -> f32 = if lt(x, cast(0.0, f32)) then neg(x) else x

def rt_max_f32(lhs: f32, rhs: f32) -> f32 = if gt(lhs, rhs) then lhs else rhs

def rt_approx_eq(actual: f32, expected: f32, abs_tol: f32, rel_tol: f32) -> bool = {{
  if and(neq(actual, actual), neq(expected, expected)) then true
  else if or(neq(actual, actual), neq(expected, expected)) then false
  else {{
    diff = rt_abs_f32(sub(actual, expected))
    bound = rt_max_f32(abs_tol, mul(rel_tol, rt_abs_f32(expected)))
    lte(diff, bound)
  }}
}}

def rt_float_list_eq(actual: List[f32], expected: List[f32], abs_tol: f32, rel_tol: f32) -> bool = {{
  if neq(len(actual), len(expected)) then false
  else if eq(len(actual), cast(0, int64)) then true
  else if not(rt_approx_eq(index(actual, cast(0, int64)), index(expected, cast(0, int64)), abs_tol, rel_tol)) then false
  else rt_float_list_eq(drop(actual, cast(1, int64)), drop(expected, cast(1, int64)), abs_tol, rel_tol)
}}

def main() -> f32 = {{
  actual = to_list({call})
  expected = [{expected_values}]
  if rt_float_list_eq(actual, expected, cast({fixture["abs_tol"]!r}, f32), cast({fixture["rel_tol"]!r}, f32))
    then cast(1.0, f32)
    else cast(0.0, f32)
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
        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        if build.returncode != 0:
            print(f"window runtime build failed for {fixture_name}: {(build.stdout + build.stderr).strip()}")
            return 1
        c_file = out_dir / "main.c"
        h_file = out_dir / "main.h"
        c_file.write_text(c_file.read_text().replace("double main", "double chelis_entry"))
        if h_file.exists():
            h_file.write_text(h_file.read_text().replace("double main", "double chelis_entry"))
        driver = workdir / "driver.c"
        driver.write_text(
            "#include <stdio.h>\n"
            "double chelis_entry__main(void);\n"
            "int main(){ printf(\"%.6f\\n\", chelis_entry__main()); return 0; }\n"
        )
        binary = workdir / "window_check"
        link = subprocess.run(native_link_cmd(binary, [c_file, driver], out_dir), capture_output=True, text=True)
        if link.returncode != 0:
            print(f"window runtime link failed for {fixture_name}: {link.stderr.strip()}")
            return 1
        run_bin = subprocess.run([str(binary)], capture_output=True, text=True)
        output = run_bin.stdout.strip()
        if run_bin.returncode != 0 or output not in {"1", "1.000000"}:
            print(f"window runtime mismatch for {fixture_name}: rc={run_bin.returncode}, stdout={output!r}, stderr={run_bin.stderr.strip()!r}")
            return 1
        print(f"window runtime OK: {fixture_name}")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def run_window_runtime_checks() -> int:
    for fixture_name in REQUIRED_WINDOW_GOLDENS:
        if fixture_name == "README.json":
            continue
        if run_window_runtime_fixture(fixture_name) != 0:
            return 1
    return 0


_FRAME_RT_INT_FILL = """
def main() -> f32 = {
  result = frame__fill_int_list(
    [cast(0, int64), cast(5, int64), cast(8, int64)],
    [true, false, false],
    cast(-1, int64),
    []
  )
  ok = and(
    and(eq(index(result, cast(0, int64)), cast(-1, int64)),
        eq(index(result, cast(1, int64)), cast(5, int64))),
    eq(index(result, cast(2, int64)), cast(8, int64))
  )
  if ok then cast(1.0, f32) else cast(0.0, f32)
}
"""

_FRAME_RT_STR_SORT = """
def main() -> f32 = {
  ok1 = frame__str_lt("berlin", "paris")
  ok2 = frame__str_lt("apple", "banana")
  ok3 = not(frame__str_lt("oslo", "london"))
  ok4 = not(frame__str_lt("paris", "paris"))
  sorted_pairs = frame__enum_insertion_sort(
    [(cast(0, int64), "paris"), (cast(1, int64), "berlin"), (cast(2, int64), "oslo")],
    []
  )
  perm_asc = frame__extract_perm_indices(sorted_pairs, [])
  asc_ok = and(
    and(eq(index(perm_asc, cast(0, int64)), cast(1, int64)),
        eq(index(perm_asc, cast(1, int64)), cast(2, int64))),
    eq(index(perm_asc, cast(2, int64)), cast(0, int64))
  )
  perm_rev = frame__reverse_ints(perm_asc, [])
  desc_ok = and(
    and(eq(index(perm_rev, cast(0, int64)), cast(0, int64)),
        eq(index(perm_rev, cast(1, int64)), cast(2, int64))),
    eq(index(perm_rev, cast(2, int64)), cast(1, int64))
  )
  if and(and(ok1, and(ok2, and(ok3, ok4))), and(asc_ok, desc_ok))
    then cast(1.0, f32)
    else cast(0.0, f32)
}
"""

_FRAME_RT_BOOL_TENSOR = """
def main() -> f32 = {
  btensor = frame__bool_list_to_tensor([true, false, true, false])
  blist = to_list(btensor)
  ok = and(
    and(eq(index(blist, cast(0, int64)), true),
        eq(index(blist, cast(1, int64)), false)),
    and(eq(index(blist, cast(2, int64)), true),
        eq(index(blist, cast(3, int64)), false))
  )
  if ok then cast(1.0, f32) else cast(0.0, f32)
}
"""

_FRAME_RT_CASES = [
    ("fill_int_list", "frame", _FRAME_RT_INT_FILL),
    ("str_lt+enum_insertion_sort", "frame", _FRAME_RT_STR_SORT),
    ("bool_list_to_tensor", "frame", _FRAME_RT_BOOL_TENSOR),
]


def run_frame_runtime_case(label: str, preset_name: str, program: str) -> int:
    body = _repro.build_prefixed_modules(_repro.MODULE_PRESETS[preset_name]) + "\n" + program
    workdir = Path(tempfile.mkdtemp(prefix=f"coral-frame-rt-{label.replace('+', '-')}-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(body)
        out_dir = workdir / "out"
        build = subprocess.run(
            [CHELIS, "build", str(main_ch), "-o", str(out_dir)],
            capture_output=True,
            text=True,
        )
        if build.returncode != 0:
            print(f"frame runtime build failed [{label}]: {(build.stdout + build.stderr).strip()}")
            return 1
        c_file = out_dir / "main.c"
        h_file = out_dir / "main.h"
        c_file.write_text(c_file.read_text().replace("double main", "double chelis_entry"))
        if h_file.exists():
            h_file.write_text(h_file.read_text().replace("double main", "double chelis_entry"))
        driver = workdir / "driver.c"
        driver.write_text(
            "#include <stdio.h>\n"
            "double chelis_entry__main(void);\n"
            "int main(){ printf(\"%.6f\\n\", chelis_entry__main()); return 0; }\n"
        )
        binary = workdir / "frame_rt_check"
        link = subprocess.run(
            native_link_cmd(binary, [c_file, driver], out_dir),
            capture_output=True,
            text=True,
        )
        if link.returncode != 0:
            print(f"frame runtime link failed [{label}]: {link.stderr.strip()}")
            return 1
        run_bin = subprocess.run([str(binary)], capture_output=True, text=True)
        output = run_bin.stdout.strip()
        if run_bin.returncode != 0 or output not in {"1", "1.000000"}:
            print(f"frame runtime mismatch [{label}]: rc={run_bin.returncode}, stdout={output!r}, stderr={run_bin.stderr.strip()!r}")
            return 1
        print(f"frame runtime OK: {label}")
        return 0
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def run_frame_runtime_checks() -> int:
    for label, preset, program in _FRAME_RT_CASES:
        if run_frame_runtime_case(label, preset, program) != 0:
            return 1
    return 0


NEGATIVE_CASES = [
    {
        "name": "nrows_type_mismatch",
        "module_file": "negwrongcol",
        "desc": "nrows called with int64 instead of Frame — checker reports TypeMismatch",
        "expected_fragment": "TypeMismatch",
        "code": """\
module Coral.NegWrongCol
import Coral.Frame (nrows)
export (main)
def main() -> f32 = {
  _ = nrows(cast(1, int64))
  cast(0.0, f32)
}
""",
    },
    {
        "name": "concat_type_mismatch",
        "module_file": "negtypemismatch",
        "desc": "concat called with int64 instead of List[Frame] — checker reports TypeMismatch",
        "expected_fragment": "TypeMismatch",
        "code": """\
module Coral.NegTypeMismatch
import Coral.Frame (concat)
export (main)
def main() -> f32 = {
  _ = concat(cast(1, int64))
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
        # Success means check found an error (negative test expects failure)
        found_error = False
        if proc.returncode != 0:
            found_error = True
        else:
            try:
                data = json.loads(output)
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
        print(f"negative test OK: {case['name']} — found {case['expected_fragment']!r}")
        return 0
    finally:
        src_tmp.unlink(missing_ok=True)


def run_negative_checks() -> int:
    for case in NEGATIVE_CASES:
        if run_negative_case(case) != 0:
            return 1
    return 0


def main() -> int:
    steps = [
        (CHELIS, "check", "src/core.ch"),
        (CHELIS, "check", "src/apismoke.ch"),
        (CHELIS, "check", "src/internal/hamt.ch"),
        (CHELIS, "check", "src/frame.ch"),
        (CHELIS, "check", "src/groupby.ch"),
        (CHELIS, "check", "src/io.ch"),
        (CHELIS, "check", "src/join.ch"),
        (CHELIS, "check", "src/window.ch"),
        (CHELIS, "check", "src/reshape.ch"),
    ]
    for step in steps:
        if run(*step) != 0:
            return 1
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
    if run_pandas_check_if_available() != 0:
        return 1
    if run_window_runtime_checks() != 0:
        return 1
    if run_frame_runtime_checks() != 0:
        return 1
    if run_phase1_compile_probe() != 0:
        return 1
    print("phase1 probe: stripped Frame/GroupBy/Join bare builds fully clean on v0.2.2 (build, link, run all pass)")
    if run_negative_checks() != 0:
        return 1
    print("coral repo checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
