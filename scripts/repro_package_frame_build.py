#!/usr/bin/env python3
"""Re-probe real `Coral.Frame` entrypoints through the Reef package lane.

Construction, `nrows`, and a match on a column returned from the HAMT build,
link, run, and agree with `chelis eval` on the pinned compiler. The `nrows`
path was blocked by chelis#1226 before 0.18.12; the match is a separate
positive guard and does not establish a chelis#1260 class-wide fix.
This lane imports `Coral.Frame`; the stripped module smokes have a separate
probe in `repro_multimodule_bare_build.py`.

Nine baseline Frame entries guard the existing construction, access, and
mutation paths. Two configurations each for describe, agg, inner_join,
left_join, outer_join, read_csv_frame, and read_json_frame assert selected
numeric values, column order, and row counts against evaluation. These are
bounded witnesses, not a promise that every type and shape lowers natively.
The drop_column entry must still reject at the exact chelis#879 boundary.

Exit codes:
- 0: every selected target matched its expected outcome
- 1: an outcome changed (either lane) or the probe could not run
"""
from __future__ import annotations

import argparse
import json
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
    built_executable_path,
    observed_root,
)


CHELIS = resolve_chelis_bin()

# The module name must lowercase to the file stem, so the stem carries no
# separator: `Coral.ProbeFrameBuild` -> `coral.probeframebuild`.
ENTRY_STEM = "probeframebuild"
ENTRY_MODULE = "Coral.ProbeFrameBuild"

TWO_COLUMNS = (
    '[("a", FloatCol(to_tensor([cast(1.0, f32), cast(2.0, f32), cast(3.0, f32)])))'
    ', ("b", FloatCol(to_tensor([cast(4.0, f32), cast(5.0, f32), cast(6.0, f32)])))]'
)

TARGETS = {
    "construct": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, ncols)\n"
            f"def main() -> i64 = ncols(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": True,
        "expect_value": 2,
    },
    "nrows": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, nrows)\n"
            f"def main() -> i64 = nrows(from_pairs({TWO_COLUMNS}))\n"
        ),
        "expect_build": True,
        "expect_value": 3,
    },
    "match_column": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_column)\n"
            "def main() -> i64 =\n"
            f'  match get_column(from_pairs({TWO_COLUMNS}), "a") with {{\n'
            "    | FloatCol(xs) => numel(xs)\n"
            "    | _ => cast(-1, i64)\n"
            "  }\n"
        ),
        "expect_build": True,
        "expect_value": 3,
    },
    "drop_nan": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, drop_nan, get_float_col, nrows)\n"
            "def nan_f32() -> f32 = div(cast(0.0, f32), cast(0.0, f32))\n"
            'def main() -> i64 = {\n'
            '  kept = drop_nan(from_pairs([("value", FloatCol(to_tensor([nan_f32(), cast(2.0, f32)])))]), "value")\n'
            '  values = to_list(get_float_col(kept, "value"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(0, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 102,
    },
    "filter": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, filter, get_float_col, nrows)\n"
            "def main() -> i64 = {\n"
            f"  kept = filter(from_pairs({TWO_COLUMNS}), to_tensor([true, false, true]))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 203,
    },
    "head": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, head, nrows)\n"
            "def main() -> i64 = {\n"
            f"  kept = head(from_pairs({TWO_COLUMNS}), cast(2, i64))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 202,
    },
    "slice": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, nrows, slice)\n"
            "def main() -> i64 = {\n"
            f"  kept = slice(from_pairs({TWO_COLUMNS}), cast(1, i64), cast(3, i64))\n"
            '  values = to_list(get_float_col(kept, "a"))\n'
            '  add(mul(nrows(kept), cast(100, i64)), cast(index(values, cast(0, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 202,
    },
    "sort_by": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, sort_by)\n"
            "def main() -> i64 = {\n"
            '  unsorted = from_pairs([("a", FloatCol(to_tensor([cast(3.0, f32), cast(1.0, f32), cast(2.0, f32)]))), ("b", FloatCol(to_tensor([cast(30.0, f32), cast(10.0, f32), cast(20.0, f32)])))])\n'
            '  ordered = sort_by(unsorted, "a", true)\n'
            '  values = to_list(get_float_col(ordered, "b"))\n'
            '  add(mul(cast(index(values, cast(0, i64)), i64), cast(100, i64)), add(mul(cast(index(values, cast(1, i64)), i64), cast(10, i64)), cast(index(values, cast(2, i64)), i64)))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 1230,
    },
    "with_column": {
        "source": (
            f"module {ENTRY_MODULE}\n"
            "import Coral.Frame (FloatCol, from_pairs, get_float_col, with_column, ncols)\n"
            "def main() -> i64 = {\n"
            f'  result = with_column(from_pairs({TWO_COLUMNS}), "c", FloatCol(to_tensor([cast(7.0, f32), cast(8.0, f32), cast(9.0, f32)])))\n'
            '  values = to_list(get_float_col(result, "c"))\n'
            '  add(mul(ncols(result), cast(100, i64)), cast(index(values, cast(1, i64)), i64))\n'
            '}\n'
        ),
        "expect_build": True,
        "expect_value": 308,
    },
}

# Bounded de-narrowing witnesses: two configurations per newly exercised verb.
TARGETS.update({
    'describe_float': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'def main() -> i64 = {\n'
            '  result = describe(from_pairs([("a", FloatCol(to_tensor([1f32, 2f32, 3f32]))), ("b", FloatCol(to_tensor([4f32, 5f32, 6f32])))]))\n'
            '  a = to_list(get_float_col(result, "a"))\n'
            '  b = to_list(get_float_col(result, "b"))\n'
            '  if and(eq(nrows(result), 8i64), and(eq(columns(result), ["stat", "a", "b"]), and(eq(a, [3f32, 2f32, 1f32, 1f32, 1.5f32, 2f32, 2.5f32, 3f32]), eq(b, [3f32, 5f32, 1f32, 4f32, 4.5f32, 5f32, 5.5f32, 6f32])))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'describe_int': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'def main() -> i64 = {\n'
            '  result = describe(from_pairs([("value", int_col_of_list([1i64, 3i64, 5i64, 7i64]))]))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(nrows(result), 8i64), and(eq(columns(result), ["stat", "value"]), and(eq(index(values, 0i64), 4f32), and(eq(index(values, 1i64), 4f32), and(lt(abs(sub(index(values, 2i64), 2.5819888f32)), 0.00001f32), and(eq(index(values, 3i64), 1f32), and(eq(index(values, 4i64), 2.5f32), and(eq(index(values, 5i64), 4f32), and(eq(index(values, 6i64), 5.5f32), eq(index(values, 7i64), 7f32)))))))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'agg_sum': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.GroupBy (group_by, agg, AggSum, AggMean)\n'
            'def main() -> i64 = {\n'
            '  frame = from_pairs([("key", StringCol(["a", "b", "a"])), ("value", FloatCol(to_tensor([2f32, 3f32, 5f32]))), ("price", FloatCol(to_tensor([10f32, 20f32, 50f32])))])\n'
            '  result = agg(group_by(frame, "key"), [("value", AggSum), ("price", AggMean)])\n'
            '  if and(eq(nrows(result), 2i64), and(eq(columns(result), ["key", "value_sum", "price_mean"]), and(eq(get_string_col(result, "key"), ["a", "b"]), and(eq(to_list(get_float_col(result, "value_sum")), [7f32, 3f32]), eq(to_list(get_float_col(result, "price_mean")), [30f32, 20f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'agg_mean': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.GroupBy (group_by, agg, AggSum, AggMean)\n'
            'def main() -> i64 = {\n'
            '  frame = from_pairs([("key", int_col_of_list([1i64, 1i64, 2i64, 2i64])), ("value", FloatCol(to_tensor([2f32, 4f32, 6f32, 8f32]))), ("price", FloatCol(to_tensor([10f32, 20f32, 30f32, 40f32])))])\n'
            '  result = agg(group_by(frame, "key"), [("value", AggMean), ("price", AggSum)])\n'
            '  if and(eq(nrows(result), 2i64), and(eq(columns(result), ["key", "value_mean", "price_sum"]), and(eq(to_list(get_int_col(result, "key")), [1i64, 2i64]), and(eq(to_list(get_float_col(result, "value_mean")), [3f32, 7f32]), eq(to_list(get_float_col(result, "price_sum")), [30f32, 70f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'inner_join_partial': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (inner_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["a", "b"])), ("qty", FloatCol(to_tensor([1f32, 2f32])))])\n'
            '  right = from_pairs([("key", StringCol(["b", "c"])), ("value", FloatCol(to_tensor([3f32, 4f32])))])\n'
            '  result = inner_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 1i64), and(eq(get_string_col(result, "key"), ["b"]), and(eq(qty, [2f32]), eq(values, [3f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'inner_join_complete': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (inner_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["x", "y", "z"])), ("qty", FloatCol(to_tensor([4f32, 5f32, 6f32])))])\n'
            '  right = from_pairs([("key", StringCol(["x", "y", "z"])), ("value", FloatCol(to_tensor([40f32, 50f32, 60f32])))])\n'
            '  result = inner_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 3i64), and(eq(get_string_col(result, "key"), ["x", "y", "z"]), and(eq(qty, [4f32, 5f32, 6f32]), eq(values, [40f32, 50f32, 60f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'left_join_partial': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (left_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["a", "b"])), ("qty", FloatCol(to_tensor([1f32, 2f32])))])\n'
            '  right = from_pairs([("key", StringCol(["b", "c"])), ("value", FloatCol(to_tensor([3f32, 4f32])))])\n'
            '  result = left_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 2i64), and(eq(get_string_col(result, "key"), ["a", "b"]), and(eq(qty, [1f32, 2f32]), and(neq(index(values, 0i64), index(values, 0i64)), eq(index(values, 1i64), 3f32)))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'left_join_complete': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (left_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["x", "y", "z"])), ("qty", FloatCol(to_tensor([4f32, 5f32, 6f32])))])\n'
            '  right = from_pairs([("key", StringCol(["x", "y", "z"])), ("value", FloatCol(to_tensor([40f32, 50f32, 60f32])))])\n'
            '  result = left_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 3i64), and(eq(get_string_col(result, "key"), ["x", "y", "z"]), and(eq(qty, [4f32, 5f32, 6f32]), eq(values, [40f32, 50f32, 60f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'outer_join_partial': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (outer_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["a", "b"])), ("qty", FloatCol(to_tensor([1f32, 2f32])))])\n'
            '  right = from_pairs([("key", StringCol(["b", "c"])), ("value", FloatCol(to_tensor([3f32, 4f32])))])\n'
            '  result = outer_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 3i64), and(eq(get_string_col(result, "key"), ["a", "b", "c"]), and(eq(index(qty, 0i64), 1f32), and(eq(index(qty, 1i64), 2f32), and(neq(index(qty, 2i64), index(qty, 2i64)), and(neq(index(values, 0i64), index(values, 0i64)), and(eq(index(values, 1i64), 3f32), eq(index(values, 2i64), 4f32))))))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'outer_join_complete': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Join (outer_join)\n'
            'def main() -> i64 = {\n'
            '  left = from_pairs([("key", StringCol(["x", "y", "z"])), ("qty", FloatCol(to_tensor([4f32, 5f32, 6f32])))])\n'
            '  right = from_pairs([("key", StringCol(["x", "y", "z"])), ("value", FloatCol(to_tensor([40f32, 50f32, 60f32])))])\n'
            '  result = outer_join(left, right, "key")\n'
            '  qty = to_list(get_float_col(result, "qty"))\n'
            '  values = to_list(get_float_col(result, "value"))\n'
            '  if and(eq(columns(result), ["key", "qty", "value"]), and(eq(nrows(result), 3i64), and(eq(get_string_col(result, "key"), ["x", "y", "z"]), and(eq(qty, [4f32, 5f32, 6f32]), eq(values, [40f32, 50f32, 60f32]))))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
    },
    'read_csv_frame_2rows': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Io (read_csv_frame)\n'
            'main = {\n'
            '  result = read_csv_frame("__CORAL_NATIVE_FIXTURE__")\n'
            '  if and(eq(nrows(result), 2i64), and(eq(columns(result), ["key", "value"]), and(eq(get_string_col(result, "key"), ["a", "b"]), eq(to_list(get_float_col(result, "value")), [1.25f32, 2.5f32])))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
        'fixture': ('input.csv', 'key,value\na,1.25\nb,2.5\n'),
    },
    'read_csv_frame_3rows': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Io (read_csv_frame)\n'
            'main = {\n'
            '  result = read_csv_frame("__CORAL_NATIVE_FIXTURE__")\n'
            '  if and(eq(nrows(result), 3i64), and(eq(columns(result), ["key", "value"]), and(eq(get_string_col(result, "key"), ["x", "y", "z"]), eq(to_list(get_float_col(result, "value")), [3.5f32, 5.5f32, 8.5f32])))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
        'fixture': ('input.csv', 'key,value\nx,3.5\ny,5.5\nz,8.5\n'),
    },
    'read_json_frame_2rows': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Io (read_json_frame)\n'
            'main = {\n'
            '  result = read_json_frame("__CORAL_NATIVE_FIXTURE__")\n'
            '  if and(eq(nrows(result), 2i64), and(eq(columns(result), ["key", "value"]), and(eq(get_string_col(result, "key"), ["a", "b"]), eq(to_list(get_float_col(result, "value")), [1.25f32, 2.5f32])))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
        'fixture': ('input.json', '[{"key": "a", "value": 1.25}, {"key": "b", "value": 2.5}]\n'),
    },
    'read_json_frame_3rows': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, StringCol, from_pairs, nrows, ncols, columns, get_float_col, get_int_col, get_string_col, describe, int_col_of_list)\n'
            'import Coral.Io (read_json_frame)\n'
            'main = {\n'
            '  result = read_json_frame("__CORAL_NATIVE_FIXTURE__")\n'
            '  if and(eq(nrows(result), 3i64), and(eq(columns(result), ["key", "value"]), and(eq(get_string_col(result, "key"), ["x", "y", "z"]), eq(to_list(get_float_col(result, "value")), [3.5f32, 5.5f32, 8.5f32])))) then 1i64 else 0i64\n'
            '}\n'
        ),
        'expect_build': True,
        'expect_value': 1,
        'fixture': ('input.json', '[{"key": "x", "value": 3.5}, {"key": "y", "value": 5.5}, {"key": "z", "value": 8.5}]\n'),
    },
    'drop_column': {
        "source": (
            'module Coral.ProbeFrameBuild\n'
            'import Coral.Frame (FloatCol, from_pairs, drop_column, ncols)\n'
            'def main() -> i64 = ncols(drop_column(from_pairs([("a", FloatCol(to_tensor([1f32, 2f32]))), ("b", FloatCol(to_tensor([3f32, 4f32])))]), "b"))\n'
        ),
        'expect_build': False,
        'expect_diagnostic': 'unimplemented chelis#879: general C-host function values are not implemented',
        'blocker': 'chelis#879',
    },
})


def _eval_value(entry: Path) -> int | None:
    result = subprocess.run(
        [CHELIS, "eval", "--file", str(entry)], capture_output=True, text=True, timeout=300
    )
    if result.returncode != 0:
        print((result.stdout + result.stderr).strip())
        return None
    match = re.search(r"^main = (-?\d+)$", result.stdout, re.MULTILINE)
    return int(match.group(1)) if match else None


def _run_target(name: str, spec: dict) -> int:
    entry = REPO / "src" / f"{ENTRY_STEM}.ch"
    if entry.exists():
        print(f"{name}: {entry} already exists; refusing to overwrite")
        return 1
    workdir = Path(tempfile.mkdtemp(prefix=f"coral-package-frame-{name}-"))
    try:
        source = spec["source"]
        if "fixture" in spec:
            fixture_name, content = spec["fixture"]
            fixture = workdir / fixture_name
            fixture.write_text(content)
            source = source.replace('"__CORAL_NATIVE_FIXTURE__"', json.dumps(str(fixture)))
        entry.write_text(source)
        out_dir = workdir / "out"
        build = subprocess.run(
            [CHELIS, "build", str(entry), "--output", str(out_dir)],
            capture_output=True,
            text=True,
            timeout=900,
        )
        output = (build.stdout + build.stderr).strip()

        if not spec["expect_build"]:
            if build.returncode == 0:
                print(output)
                print(f"{name}: FIX-DETECTED -- the build lane now accepts this entry")
                return 1
            if spec["expect_diagnostic"] not in output:
                print(output)
                print(f"{name}: failure diagnostic drifted")
                return 1
            print(f"{name}: still blocked at the expected boundary ({spec['blocker']})")
            return 0

        if build.returncode != 0:
            print(output)
            print(f"{name}: chelis build failed")
            return 1

        evaluated = _eval_value(entry)
        if evaluated is None:
            print(f"{name}: chelis eval did not produce an integer value")
            return 1

        binary = built_executable_path(output)

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"{name}: compiled program exited rc={run.returncode}")
            return 1

        native = observed_root(run.stdout, "main")
        if native is None or int(native) != evaluated:
            print(run.stdout.strip())
            print(f"{name}: native observed {native!r}, eval returned {evaluated}")
            return 1
        if int(native) != spec["expect_value"]:
            print(f"{name}: expected {spec['expect_value']}, got {native}")
            return 1
        print(f"{name}: build, link, and run OK -- native and eval both {evaluated}")
        return 0
    finally:
        entry.unlink(missing_ok=True)
        shutil.rmtree(workdir, ignore_errors=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=[*sorted(TARGETS), "all"], default="all")
    args = parser.parse_args()
    names = sorted(TARGETS) if args.target == "all" else [args.target]
    return max(_run_target(name, TARGETS[name]) for name in names)


if __name__ == "__main__":
    raise SystemExit(main())
