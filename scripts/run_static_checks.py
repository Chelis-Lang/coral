#!/usr/bin/env python3
"""Static consistency checks for Coral."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src"


def parse_exports(path: Path) -> set[str]:
    text = path.read_text()
    match = re.search(r"export\s*\(([^)]*)\)", text, re.S)
    if not match:
        return set()
    return {tok.strip() for tok in match.group(1).split(",") if tok.strip()}


def parse_imports(path: Path) -> dict[str, set[str]]:
    text = path.read_text()
    out: dict[str, set[str]] = {}
    for match in re.finditer(r"import\s+([\w.]+)\s*\(([^)]*)\)", text, re.S):
        mod = match.group(1)
        names = {tok.strip() for tok in match.group(2).split(",") if tok.strip()}
        out.setdefault(mod, set()).update(names)
    return out


def main() -> int:
    failures: list[str] = []
    smoke = SRC / "apismoke.ch"
    modules = {
        "Coral.Core": SRC / "core.ch",
        "Coral.Frame": SRC / "frame.ch",
        "Coral.GroupBy": SRC / "groupby.ch",
        "Coral.Join": SRC / "join.ch",
        "Coral.Window": SRC / "window.ch",
        "Coral.Io": SRC / "io.ch",
        "Coral.Reshape": SRC / "reshape.ch",
        "Coral.AsOf": SRC / "asof.ch",
        "Coral.PlayerData": SRC / "playerdata.ch",
        "Coral.Internal.Hamt": SRC / "internal" / "hamt.ch",
    }
    if not smoke.exists():
        failures.append("missing src/apismoke.ch")
    else:
        imports = parse_imports(smoke)
        for mod, names in imports.items():
            target = modules.get(mod)
            if target is None:
                failures.append(f"apismoke imports unknown module {mod}")
                continue
            exports = parse_exports(target)
            missing = sorted(names - exports)
            if missing:
                failures.append(f"{mod} missing exports used by apismoke: {missing}")

    readme = REPO / "README.md"
    if not readme.exists():
        failures.append("missing README.md")
    else:
        txt = readme.read_text()
        for mod, path in modules.items():
            if mod == "Coral.Internal.Hamt":
                continue
            if mod not in txt:
                failures.append(f"README.md does not mention {mod}")
            if not parse_exports(path):
                failures.append(
                    f"{path.relative_to(REPO)} has an empty or missing export() clause"
                )
    if failures:
        print("STATIC CHECK FAILURES:")
        for item in failures:
            print(f"  - {item}")
        return 1
    print("static checks OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
