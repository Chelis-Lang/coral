#!/usr/bin/env python3
"""Placeholder golden-generation entrypoint for future pandas parity work."""
from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def main() -> int:
    marker = {
        "status": "placeholder",
        "note": "Populate pandas reference fixtures as the Coral runtime surface stabilizes.",
    }
    out = REPO / "tests" / "goldens" / "frame" / "README.json"
    out.write_text(json.dumps(marker, indent=2) + "\n")
    print(f"wrote {out.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
