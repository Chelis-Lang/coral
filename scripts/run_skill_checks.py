#!/usr/bin/env python3
"""Validate compile-checked Coral examples in SKILL.md."""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()


def extract_blocks(text: str, lang: str) -> list[str]:
    pattern = rf"```{re.escape(lang)}\n(.*?)```"
    candidates = re.findall(pattern, text, re.DOTALL)
    frag_pattern = rf"```{re.escape(lang)}-fragment\n(.*?)```"
    fragments = set(re.findall(frag_pattern, text, re.DOTALL))
    return [c for c in candidates if c not in fragments]


def block_path(code: str, source: str, index: int) -> Path:
    mod = re.search(r"^module\s+Coral(?:\.[A-Za-z0-9_]+)+", code, re.M)
    if not mod:
        raise ValueError(f"{source} block {index} is missing a `module Coral.*` declaration")
    return SRC / f"{mod.group(0).split('.')[-1].lower()}.ch"


def validate_blocks(blocks: list[str]) -> bool:
    temp_files: list[Path] = []
    try:
        for index, code in enumerate(blocks):
            tmp = block_path(code, "SKILL.md", index)
            if tmp.exists():
                raise ValueError(f"SKILL.md block {index} would overwrite existing {tmp.relative_to(REPO)}")
            tmp.write_text(code)
            temp_files.append(tmp)

        proc = subprocess.run([CHELIS, "reef", "build"], cwd=str(REPO), capture_output=True, text=True)
        if proc.returncode != 0:
            print((proc.stdout + proc.stderr).strip())
            return False
        return True
    finally:
        for tmp in temp_files:
            tmp.unlink(missing_ok=True)


def main() -> int:
    path = REPO / "SKILL.md"
    if not path.exists():
        print("SKILL.md not found")
        return 0
    text = path.read_text()
    blocks = extract_blocks(text, "chelis")
    if not blocks:
        print("No compile-checked SKILL examples found.")
        return 1
    ok = validate_blocks(blocks)
    print(f"{len(blocks) if ok else 0}/{len(blocks)} SKILL examples passed")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
