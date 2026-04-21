#!/usr/bin/env python3
"""Generate pandas-backed frame goldens for Coral's first parity slice."""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

try:
    import pandas as pd
except ModuleNotFoundError as exc:  # pragma: no cover - explicit operator guidance
    raise SystemExit(
        "pandas is required for Coral golden generation. "
        "Install it with `python -m pip install --user pandas numpy`."
    ) from exc


REPO = Path(__file__).resolve().parent.parent
GOLDENS = REPO / "tests" / "goldens" / "frame"

BASE_SCHEMA = {
    "id": "int",
    "qty": "int",
    "price": "float",
    "city": "string",
    "flag": "bool",
}


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


def encode_scalar(value, kind: str):
    if kind == "float":
        value = float(value)
        return "NaN" if math.isnan(value) else value
    if kind == "int":
        return int(value)
    if kind == "bool":
        return bool(value)
    return str(value)


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


def fixture_contract() -> dict:
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


def fixtures() -> dict[str, dict]:
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
        "README.json": fixture_contract(),
        "base.json": {
            "fixture": "base",
            "operation": "from_pairs",
            "expected_frame": frame_payload(base, BASE_SCHEMA),
        },
        "filter_flag_true.json": {
            "fixture": "filter_flag_true",
            "operation": "filter",
            "expected_frame": frame_payload(filter_true, BASE_SCHEMA),
        },
        "head_2.json": {
            "fixture": "head_2",
            "operation": "head",
            "expected_frame": frame_payload(base.head(2), BASE_SCHEMA),
        },
        "tail_2.json": {
            "fixture": "tail_2",
            "operation": "tail",
            "expected_frame": frame_payload(base.tail(2).reset_index(drop=True), BASE_SCHEMA),
        },
        "slice_1_3.json": {
            "fixture": "slice_1_3",
            "operation": "slice",
            "expected_frame": frame_payload(base.iloc[1:3].reset_index(drop=True), BASE_SCHEMA),
        },
        "rename_price_to_cost.json": {
            "fixture": "rename_price_to_cost",
            "operation": "rename",
            "expected_frame": frame_payload(renamed, renamed_schema),
        },
        "with_column_total.json": {
            "fixture": "with_column_total",
            "operation": "with_column",
            "expected_frame": frame_payload(total, total_schema),
        },
        "drop_city.json": {
            "fixture": "drop_city",
            "operation": "drop_column",
            "expected_frame": frame_payload(dropped, dropped_schema),
        },
        "fill_nan_price.json": {
            "fixture": "fill_nan_price",
            "operation": "fill_nan",
            "expected_frame": frame_payload(filled, BASE_SCHEMA),
        },
        "drop_nan_price.json": {
            "fixture": "drop_nan_price",
            "operation": "drop_nan",
            "expected_frame": frame_payload(dropped_nan.reset_index(drop=True), BASE_SCHEMA),
        },
        "concat_base_parts.json": {
            "fixture": "concat_base_parts",
            "operation": "concat",
            "expected_frame": frame_payload(concat_parts, BASE_SCHEMA),
        },
        "describe_numeric.json": {
            "fixture": "describe_numeric",
            "operation": "describe",
            "expected_frame": describe_payload(base),
        },
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="verify checked-in goldens match pandas output")
    args = parser.parse_args()

    expected = fixtures()
    issues: list[str] = []
    for rel_name, payload in expected.items():
        path = GOLDENS / rel_name
        if args.check:
            issues.extend(check_json(path, payload))
        else:
            write_json(path, payload)
            print(f"wrote {path.relative_to(REPO)}")

    if args.check:
        if issues:
            for issue in issues:
                print(issue)
            return 1
        print("frame goldens match pandas")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
