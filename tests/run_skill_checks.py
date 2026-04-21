#!/usr/bin/env python3
"""Validate compile-checked Coral examples in SKILL.md."""
from __future__ import annotations

import json
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


def validate_block(code: str, index: int) -> bool:
    mod = re.search(r"^module\s+Coral(?:\.[A-Za-z0-9_]+)+", code, re.M)
    fname = mod.group(0).split(".")[-1].lower() if mod else f"_skill_{index}"
    tmp = SRC / f"{fname}.ch"
    try:
        tmp.write_text(code)
        proc = subprocess.run([CHELIS, "check", str(tmp)], cwd=str(REPO), capture_output=True, text=True)
        payload = (proc.stdout + proc.stderr).strip()
        if not payload:
            return proc.returncode == 0
        try:
            data = json.loads(payload)
        except json.JSONDecodeError:
            return proc.returncode == 0
        if data.get("score", 0) >= 0.95 and not data.get("errors"):
            return True
        print(f"  FAIL: block {index} (score={data.get('score')}, errors={data.get('errors', [])})")
        return False
    finally:
        tmp.unlink(missing_ok=True)


def main() -> int:
    path = REPO / "SKILL.md"
    if not path.exists():
        print("SKILL.md not found")
        return 0
    text = path.read_text()
    failures = 0
    blocks = extract_blocks(text, "chelis")
    for idx, block in enumerate(blocks):
        if not validate_block(block, idx):
            failures += 1
    print(f"{len(blocks) - failures}/{len(blocks)} SKILL examples passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
