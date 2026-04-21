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
FRAME_GOLDENS = REPO / "tests" / "goldens" / "frame"
GROUPBY_GOLDENS = REPO / "tests" / "goldens" / "groupby"
WINDOW_GOLDENS = REPO / "tests" / "goldens" / "window"

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
        ],
        "known_deltas": [
            "string sort_by is deferred",
            "runtime reef-import build is blocked upstream on v0.1.13",
            "checked-in goldens prove pandas reference behavior even when runtime parity harness is still partial",
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
    issues.extend(write_or_check(WINDOW_GOLDENS, window_fixtures(), check=args.check))

    if args.check:
        if issues:
            for issue in issues:
                print(issue)
            return 1
        print("frame, groupby, and window goldens match pandas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
