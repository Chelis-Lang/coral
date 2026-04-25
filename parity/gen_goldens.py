#!/usr/bin/env python3
"""Generate pandas-backed goldens for Coral parity slices."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

try:
    import pandas as pd
except ModuleNotFoundError as exc:  # pragma: no cover
    raise SystemExit(
        "pandas is required for Coral golden generation. "
        "Install it with `python -m pip install --user pandas numpy`."
    ) from exc


REPO = Path(__file__).resolve().parent.parent
FRAME_GOLDENS = REPO / "parity" / "goldens" / "frame"
GROUPBY_GOLDENS = REPO / "parity" / "goldens" / "groupby"
IO_GOLDENS = REPO / "parity" / "goldens" / "io"
JOIN_GOLDENS = REPO / "parity" / "goldens" / "join"
WINDOW_GOLDENS = REPO / "parity" / "goldens" / "window"
RESHAPE_GOLDENS = REPO / "parity" / "goldens" / "reshape"

BASE_SCHEMA = {
    "id": "int",
    "qty": "int",
    "price": "float",
    "city": "string",
    "flag": "bool",
}


def encode_float(value: float) -> str | float:
    value = float(value)
    return "NaN" if math.isnan(value) else value


def encode_scalar(value, kind: str):
    if kind == "float":
        return encode_float(value)
    if kind == "int":
        return int(value)
    if kind == "bool":
        return bool(value)
    return str(value)


def base_frame() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "id": [1, 2, 3, 4],
            "qty": [5, 6, 7, 8],
            "price": [10.0, math.nan, 30.5, 40.0],
            "city": ["london", "paris", "paris", "oslo"],
            "flag": [True, False, True, False],
        }
    )


def frame_payload(df: pd.DataFrame, schema: dict[str, str]) -> dict:
    columns = []
    for name in list(df.columns):
        kind = schema[name]
        series = df[name]
        columns.append(
            {
                "name": name,
                "type": kind,
                "values": [encode_scalar(value, kind) for value in series.tolist()],
            }
        )
    return {"nrows": int(len(df.index)), "ncols": int(len(df.columns)), "columns": columns}


def describe_payload(df: pd.DataFrame) -> dict:
    described = df[["id", "qty", "price"]].describe()
    schema = {"stat": "string", "id": "float", "qty": "float", "price": "float"}
    result = described.reset_index(names="stat")
    return frame_payload(result, schema)


def frame_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral frame goldens are produced from pandas for fixed deterministic inputs.",
        "frame_schema": {
            "nrows": "int",
            "ncols": "int",
            "columns": [
                {
                    "name": "string",
                    "type": "one of: int | float | string | bool",
                    "values": "ordered row values; float NaN is encoded as the string 'NaN'",
                }
            ],
        },
        "phase_slice": [
            "construction via from_pairs",
            "typed access/reference frame shape",
            "filter",
            "head/tail/slice",
            "rename/with_column/drop_column",
            "NaN helpers via frame outputs",
            "concat",
            "describe",
            "value_counts",
            "sort_by (string, int, float, bool columns — ascending and descending)",
        ],
        "known_deltas": [
            "stripped bare-build runtime for HAMT-dependent operations (from_pairs, value_counts) is blocked by generic specialization in the prefixed-concat context; core algorithm runtime lane (fill_int_list, str_lt+sort, bool_list_to_tensor) runs and passes",
            "checked-in goldens prove pandas reference behavior",
        ],
    }


def frame_fixtures() -> dict[str, dict]:
    base = base_frame()
    total = base.assign(total=base["price"].fillna(0.0) * base["qty"])
    total_schema = {**BASE_SCHEMA, "total": "float"}
    renamed = base.rename(columns={"price": "cost"})
    renamed_schema = {"id": "int", "qty": "int", "cost": "float", "city": "string", "flag": "bool"}
    dropped = base.drop(columns=["city"])
    dropped_schema = {"id": "int", "qty": "int", "price": "float", "flag": "bool"}
    filled = base.assign(price=base["price"].fillna(99.5))
    dropped_nan = base.dropna(subset=["price"])
    filter_true = base[base["flag"]].reset_index(drop=True)
    concat_parts = pd.concat([base.iloc[:2], base.iloc[2:]], ignore_index=True)

    return {
        "README.json": frame_contract(),
        "base.json": {"fixture": "base", "operation": "from_pairs", "expected_frame": frame_payload(base, BASE_SCHEMA)},
        "filter_flag_true.json": {"fixture": "filter_flag_true", "operation": "filter", "expected_frame": frame_payload(filter_true, BASE_SCHEMA)},
        "head_2.json": {"fixture": "head_2", "operation": "head", "expected_frame": frame_payload(base.head(2), BASE_SCHEMA)},
        "tail_2.json": {"fixture": "tail_2", "operation": "tail", "expected_frame": frame_payload(base.tail(2).reset_index(drop=True), BASE_SCHEMA)},
        "slice_1_3.json": {"fixture": "slice_1_3", "operation": "slice", "expected_frame": frame_payload(base.iloc[1:3].reset_index(drop=True), BASE_SCHEMA)},
        "rename_price_to_cost.json": {"fixture": "rename_price_to_cost", "operation": "rename", "expected_frame": frame_payload(renamed, renamed_schema)},
        "with_column_total.json": {"fixture": "with_column_total", "operation": "with_column", "expected_frame": frame_payload(total, total_schema)},
        "drop_city.json": {"fixture": "drop_city", "operation": "drop_column", "expected_frame": frame_payload(dropped, dropped_schema)},
        "fill_nan_price.json": {"fixture": "fill_nan_price", "operation": "fill_nan", "expected_frame": frame_payload(filled, BASE_SCHEMA)},
        "drop_nan_price.json": {"fixture": "drop_nan_price", "operation": "drop_nan", "expected_frame": frame_payload(dropped_nan.reset_index(drop=True), BASE_SCHEMA)},
        "concat_base_parts.json": {"fixture": "concat_base_parts", "operation": "concat", "expected_frame": frame_payload(concat_parts, BASE_SCHEMA)},
        "describe_numeric.json": {"fixture": "describe_numeric", "operation": "describe", "expected_frame": describe_payload(base)},
        "value_counts_city.json": generate_value_counts_city(),
        "fill_nan_qty.json": generate_fill_nan_qty(),
        "sort_by_city_asc.json": generate_sort_by_city_asc(),
        "sort_by_city_desc.json": generate_sort_by_city_desc(),
    }


def generate_sort_by_city_asc() -> dict:
    df = pd.DataFrame({
        "city": ["paris", "london", "oslo", "berlin"],
        "price": [20.0, 10.0, 30.0, 15.0],
        "qty": [2, 5, 1, 3],
    })
    result = df.sort_values("city", ascending=True).reset_index(drop=True)
    schema = {"city": "string", "price": "float", "qty": "int"}
    return {
        "fixture": "sort_by_city_asc",
        "operation": "sort_by",
        "expected_frame": frame_payload(result, schema),
    }


def generate_sort_by_city_desc() -> dict:
    df = pd.DataFrame({
        "city": ["paris", "london", "oslo", "berlin"],
        "price": [20.0, 10.0, 30.0, 15.0],
        "qty": [2, 5, 1, 3],
    })
    result = df.sort_values("city", ascending=False).reset_index(drop=True)
    schema = {"city": "string", "price": "float", "qty": "int"}
    return {
        "fixture": "sort_by_city_desc",
        "operation": "sort_by",
        "expected_frame": frame_payload(result, schema),
    }


def generate_fill_nan_qty() -> dict:
    df = pd.DataFrame({
        "city": ["london", "paris", "oslo"],
        "qty": pd.array([pd.NA, 5, 8], dtype=pd.Int64Dtype()),
    })
    filled = df.copy()
    filled["qty"] = filled["qty"].fillna(-1).astype(int)
    schema = {"city": "string", "qty": "int"}
    return {
        "fixture": "fill_nan_qty",
        "operation": "fill_nan_int",
        "expected_frame": frame_payload(filled, schema),
    }


def generate_value_counts_city() -> dict:
    df = pd.DataFrame({"city": ["london", "paris", "london", "paris"]})
    counts = df["city"].value_counts(sort=False)
    vc_df = counts.reset_index()
    vc_df.columns = ["city", "count"]
    schema = {"city": "string", "count": "int"}
    return {
        "fixture": "value_counts_city",
        "operation": "value_counts",
        "expected_frame": frame_payload(vc_df, schema),
    }


def window_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral window goldens are produced from pandas and are exercised by a runtime build/link/execute harness.",
        "value_encoding": "float outputs use 'NaN' for missing window entries",
        "phase_slice": [
            "rolling_sum",
            "rolling_mean",
            "rolling_std (sample ddof=1)",
            "rolling_min",
            "rolling_max",
            "ewm(alpha, adjust=False)",
        ],
    }


def groupby_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral groupby goldens are produced from pandas with sort=False to match first-seen key ordering.",
        "phase_slice": [
            "group_by single string key",
            "agg_sum",
            "agg_mean",
            "agg_count",
            "agg_min",
            "agg_max",
            "agg with multiple specs",
        ],
        "known_deltas": [
            "checked-in expectations exist before a full executed runtime harness",
            "current parity target is first-seen key order, not sorted key order",
        ],
    }


def groupby_base() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "city": ["london", "paris", "paris", "oslo", "london"],
            "qty": [5, 6, 7, 8, 9],
            "price": [10.0, 20.0, 30.0, 40.0, 50.0],
            "flag": [True, False, True, False, True],
        }
    )


def groupby_fixtures() -> dict[str, dict]:
    base = groupby_base()
    sum_qty = base.groupby("city", sort=False)["qty"].sum().reset_index(name="qty_sum")
    mean_price = base.groupby("city", sort=False)["price"].mean().reset_index(name="price_mean")
    counts = base.groupby("city", sort=False).size().reset_index(name="count")
    min_qty = base.groupby("city", sort=False)["qty"].min().reset_index(name="qty_min")
    max_price = base.groupby("city", sort=False)["price"].max().reset_index(name="price_max")
    multi = (
        base.groupby("city", sort=False)
        .agg(qty_sum=("qty", "sum"), price_mean=("price", "mean"), count=("city", "size"))
        .reset_index()
    )
    city_int_schema = {"city": "string", "qty_sum": "int"}
    city_float_schema = {"city": "string", "price_mean": "float"}
    city_count_schema = {"city": "string", "count": "int"}
    city_min_schema = {"city": "string", "qty_min": "int"}
    city_max_schema = {"city": "string", "price_max": "float"}
    multi_schema = {"city": "string", "qty_sum": "int", "price_mean": "float", "count": "int"}
    return {
        "README.json": groupby_contract(),
        "agg_sum_qty_by_city.json": {"fixture": "agg_sum_qty_by_city", "operation": "agg_sum", "expected_frame": frame_payload(sum_qty, city_int_schema)},
        "agg_mean_price_by_city.json": {"fixture": "agg_mean_price_by_city", "operation": "agg_mean", "expected_frame": frame_payload(mean_price, city_float_schema)},
        "agg_count_by_city.json": {"fixture": "agg_count_by_city", "operation": "agg_count", "expected_frame": frame_payload(counts, city_count_schema)},
        "agg_min_qty_by_city.json": {"fixture": "agg_min_qty_by_city", "operation": "agg_min", "expected_frame": frame_payload(min_qty, city_min_schema)},
        "agg_max_price_by_city.json": {"fixture": "agg_max_price_by_city", "operation": "agg_max", "expected_frame": frame_payload(max_price, city_max_schema)},
        "agg_multi_city.json": {"fixture": "agg_multi_city", "operation": "agg", "expected_frame": frame_payload(multi, multi_schema)},
    }


def join_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral join goldens are produced from pandas merge outputs and preserve row order from the current host-path join implementation.",
        "phase_slice": [
            "inner_join on string key",
            "left_join on string key",
            "duplicate-match expansion",
            "left-join missing right rows as NaN / empty string",
        ],
        "known_deltas": [
            "checked-in expectations exist before a full executed runtime harness",
            "bool output columns remain deferred",
        ],
    }


def join_fixtures() -> dict[str, dict]:
    left = pd.DataFrame(
        {
            "customer": ["a", "b", "a", "c"],
            "qty": [1, 2, 3, 4],
        }
    )
    right = pd.DataFrame(
        {
            "customer": ["a", "a", "c", "d"],
            "region": ["north", "west", "south", "east"],
            "score": [10.0, 15.0, 40.0, 99.0],
        }
    )
    inner = left.merge(right, on="customer", how="inner", sort=False)
    left_joined = left.merge(right, on="customer", how="left", sort=False)
    left_joined["region"] = left_joined["region"].fillna("")
    # Coral outer_join traverses left rows sequentially (not key-grouped like pandas).
    # Reconstruct expected output in left-sequential order, then right-only rows.
    left_keys_set = set(left["customer"])
    outer_rows = []
    for _, lr in left.iterrows():
        matched = right[right["customer"] == lr["customer"]].reset_index(drop=True)
        if len(matched) == 0:
            outer_rows.append({"customer": lr["customer"], "qty": int(lr["qty"]), "region": "", "score": float("nan")})
        else:
            for _, rr in matched.iterrows():
                outer_rows.append({"customer": lr["customer"], "qty": int(lr["qty"]), "region": rr["region"], "score": float(rr["score"])})
    for _, rr in right.iterrows():
        if rr["customer"] not in left_keys_set:
            outer_rows.append({"customer": rr["customer"], "qty": 0, "region": rr["region"], "score": float(rr["score"])})
    outer_joined = pd.DataFrame(outer_rows)
    inner_schema = {"customer": "string", "qty": "int", "region": "string", "score": "float"}
    left_schema = {"customer": "string", "qty": "int", "region": "string", "score": "float"}
    outer_schema = {"customer": "string", "qty": "int", "region": "string", "score": "float"}
    return {
        "README.json": join_contract(),
        "inner_join_customer.json": {"fixture": "inner_join_customer", "operation": "inner_join", "expected_frame": frame_payload(inner, inner_schema)},
        "left_join_customer.json": {"fixture": "left_join_customer", "operation": "left_join", "expected_frame": frame_payload(left_joined, left_schema)},
        "outer_join_customer.json": {"fixture": "outer_join_customer", "operation": "outer_join", "expected_frame": frame_payload(outer_joined, outer_schema)},
    }


def io_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral IO goldens lock expected CSV/JSON read semantics and supported write formatting for the current compile-checked slice.",
        "phase_slice": [
            "read_csv_frame typed inference",
            "read_json_frame typed inference",
            "write_csv_frame on int/float/string/bool columns",
            "write_json_frame on int/float/string/bool columns",
        ],
        "known_deltas": [
            "IO is fixture-backed plus compile-checked; no executed runtime parity lane yet",
            "serialization expectations reflect Coral's current formatting, not pandas text formatting",
        ],
    }


def io_frame_df() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "id": [1, 2],
            "price": [10.0, 20.5],
            "flag": [True, False],
            "city": ["london", "paris"],
        }
    )


def io_fixtures() -> dict[str, dict]:
    frame = io_frame_df()
    schema = {"id": "int", "price": "float", "flag": "bool", "city": "string"}
    csv_text = "id,price,flag,city\n1,10.0,true,london\n2,20.5,false,paris\n"
    json_text = '[{"id":1,"price":10.0,"flag":true,"city":"london"},{"id":2,"price":20.5,"flag":false,"city":"paris"}]'
    return {
        "README.json": io_contract(),
        "read_csv_mixed.json": {
            "fixture": "read_csv_mixed",
            "operation": "read_csv_frame",
            "input_text": csv_text,
            "expected_frame": frame_payload(frame, schema),
        },
        "read_json_mixed.json": {
            "fixture": "read_json_mixed",
            "operation": "read_json_frame",
            "input_text": json_text,
            "expected_frame": frame_payload(frame, schema),
        },
        "write_csv_mixed.json": {
            "fixture": "write_csv_mixed",
            "operation": "write_csv_frame",
            "source_frame": frame_payload(frame, schema),
            "expected_text": csv_text,
        },
        "write_json_mixed.json": {
            "fixture": "write_json_mixed",
            "operation": "write_json_frame",
            "source_frame": frame_payload(frame, schema),
            "expected_text": json_text,
        },
    }


def window_fixture(name: str, operation: str, series: pd.Series, *, window: int | None = None, alpha: float | None = None) -> dict:
    values = [float(v) for v in series.tolist()]
    payload = {
        "fixture": name,
        "operation": operation,
        "input": [1.0, 2.0, 3.0, 4.0, 5.0],
        "expected": [encode_float(v) for v in values],
        "abs_tol": 1.0e-5,
        "rel_tol": 1.0e-5,
    }
    if window is not None:
        payload["window"] = window
    if alpha is not None:
        payload["alpha"] = alpha
    return payload


def window_fixtures() -> dict[str, dict]:
    values = pd.Series([1.0, 2.0, 3.0, 4.0, 5.0], dtype="float64")
    return {
        "README.json": window_contract(),
        "rolling_sum_w3.json": window_fixture("rolling_sum_w3", "rolling_sum", values.rolling(3).sum(), window=3),
        "rolling_mean_w3.json": window_fixture("rolling_mean_w3", "rolling_mean", values.rolling(3).mean(), window=3),
        "rolling_std_w3.json": window_fixture("rolling_std_w3", "rolling_std", values.rolling(3).std(), window=3),
        "rolling_min_w3.json": window_fixture("rolling_min_w3", "rolling_min", values.rolling(3).min(), window=3),
        "rolling_max_w3.json": window_fixture("rolling_max_w3", "rolling_max", values.rolling(3).max(), window=3),
        "ewm_alpha_0_5.json": window_fixture("ewm_alpha_0_5", "ewm", values.ewm(alpha=0.5, adjust=False).mean(), alpha=0.5),
    }


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n")


def check_json(path: Path, payload: dict) -> list[str]:
    if not path.exists():
        return [f"missing {path.relative_to(REPO)}"]
    current = json.loads(path.read_text())
    if current != payload:
        return [f"stale {path.relative_to(REPO)}"]
    return []


def reshape_contract() -> dict:
    return {
        "schema_version": 1,
        "note": "Coral reshape goldens are produced from pandas and cover pivot, melt, stack, and unstack.",
        "phase_slice": [
            "pivot with string index_col and columns_col, float values_col",
            "melt with id_cols and float value_cols",
            "stack: wide frame to long form with 'variable' and 'value' columns",
            "unstack: long form back to wide frame",
        ],
        "known_deltas": [
            "only FloatCol values_col is supported in v0.1",
            "pivot index_col and columns_col must be StringCol",
            "melt id_cols must be StringCol in v0.1",
            "stack with mixed-type frames (string + float columns) is deferred: melt requires float value_cols",
        ],
    }


def reshape_base() -> pd.DataFrame:
    return pd.DataFrame(
        {
            "city": ["london", "paris", "oslo", "london", "paris", "oslo"],
            "product": ["a", "a", "a", "b", "b", "b"],
            "qty": [5.0, 6.0, 7.0, 8.0, 9.0, 10.0],
            "price": [10.0, 20.0, 30.0, 40.0, 50.0, 60.0],
        }
    )


def gen_stack_wide_frame() -> dict:
    # Coral stack(df) = melt(df, [], columns(df)) — no id_cols, all columns as value_cols.
    # Only FloatCol columns are supported, so use a purely numeric frame.
    df = pd.DataFrame({
        "qty": [5.0, 6.0, 7.0],
        "price": [10.0, 20.0, 30.0],
    })
    # pandas equivalent: melt with no id_vars, all columns as value_vars.
    result = df.melt(id_vars=[], value_vars=["qty", "price"], var_name="variable", value_name="value")
    result = result[["variable", "value"]].reset_index(drop=True)
    schema = {"variable": "string", "value": "float"}
    return {
        "fixture": "stack_wide_frame",
        "operation": "stack",
        "value_cols": ["qty", "price"],
        "expected_frame": frame_payload(result, schema),
    }


def gen_unstack_stacked_frame() -> dict:
    # Coral unstack(df, index_col) = pivot(df, index_col, "variable", "value").
    # Build a stacked frame that has an index_col, a "variable" col, and a "value" col,
    # then pivot on index_col to recover wide form.
    df = pd.DataFrame({
        "city": ["london", "paris", "london", "paris"],
        "variable": ["qty", "qty", "price", "price"],
        "value": [5.0, 6.0, 10.0, 20.0],
    })
    # pivot: index="city", columns="variable", values="value"
    result = df.pivot(index="city", columns="variable", values="value").reset_index()
    result.columns.name = None
    # column order from unique_strings (first-seen): city, qty, price
    result = result[["city", "qty", "price"]].reset_index(drop=True)
    schema = {"city": "string", "qty": "float", "price": "float"}
    return {
        "fixture": "unstack_stacked_frame",
        "operation": "unstack",
        "index_col": "city",
        "expected_frame": frame_payload(result, schema),
    }


def reshape_fixtures() -> dict[str, dict]:
    base = reshape_base()

    pivot_df = base.pivot(index="city", columns="product", values="price").reset_index()
    pivot_df.columns.name = None
    pivot_schema = {"city": "string", "a": "float", "b": "float"}

    melt_df = base[["city", "qty", "price"]].melt(
        id_vars=["city"], value_vars=["qty", "price"], var_name="variable", value_name="value"
    )
    melt_schema = {"variable": "string", "value": "float", "city": "string"}
    melt_reordered = melt_df[["variable", "value", "city"]].reset_index(drop=True)

    return {
        "README.json": reshape_contract(),
        "pivot_city_product_price.json": {
            "fixture": "pivot_city_product_price",
            "operation": "pivot",
            "index_col": "city",
            "columns_col": "product",
            "values_col": "price",
            "expected_frame": frame_payload(pivot_df, pivot_schema),
        },
        "melt_city_qty_price.json": {
            "fixture": "melt_city_qty_price",
            "operation": "melt",
            "id_cols": ["city"],
            "value_cols": ["qty", "price"],
            "expected_frame": frame_payload(melt_reordered, melt_schema),
        },
        "stack_wide_frame.json": gen_stack_wide_frame(),
        "unstack_stacked_frame.json": gen_unstack_stacked_frame(),
    }


def write_or_check(base_dir: Path, expected: dict[str, dict], *, check: bool) -> list[str]:
    issues: list[str] = []
    for rel_name, payload in expected.items():
        path = base_dir / rel_name
        if check:
            issues.extend(check_json(path, payload))
        else:
            write_json(path, payload)
            print(f"wrote {path.relative_to(REPO)}")
    return issues


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify checked-in goldens match pandas output")
    args = parser.parse_args()

    issues = []
    issues.extend(write_or_check(FRAME_GOLDENS, frame_fixtures(), check=args.check))
    issues.extend(write_or_check(GROUPBY_GOLDENS, groupby_fixtures(), check=args.check))
    issues.extend(write_or_check(IO_GOLDENS, io_fixtures(), check=args.check))
    issues.extend(write_or_check(JOIN_GOLDENS, join_fixtures(), check=args.check))
    issues.extend(write_or_check(WINDOW_GOLDENS, window_fixtures(), check=args.check))
    issues.extend(write_or_check(RESHAPE_GOLDENS, reshape_fixtures(), check=args.check))

    if args.check:
        if issues:
            for issue in issues:
                print(issue)
            return 1
        print("frame, groupby, io, join, window, and reshape goldens match pandas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
