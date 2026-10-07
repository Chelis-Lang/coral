#!/usr/bin/env python3
"""Validate all compile-checked code examples in the mdBook.

Walks docs/book/src/**/*.md, extracts code blocks tagged with ```chelis
(not ```chelis-fragment), writes each as a temporary file inside
src/ so reef imports resolve, and runs `chelis check`.

Exit non-zero if any block fails.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DOCS_SRC = REPO / "docs" / "book" / "src"
SRC = REPO / "src"
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()
MIN_CHELIS_BLOCKS = int(os.environ.get("MIN_BOOK_CHELIS_BLOCKS", "1"))


def extract_chelis_blocks(text: str) -> list[str]:
    all_blocks = re.findall(r"```chelis\n(.*?)```", text, re.DOTALL)
    fragments = set(re.findall(r"```chelis-fragment\n(.*?)```", text, re.DOTALL))
    return [b for b in all_blocks if b not in fragments]


def block_path(code: str, source_file: str, index: int) -> Path:
    mod_match = re.search(r"^module\s+Coral(?:\.[A-Za-z0-9_]+)+", code, re.M)
    if not mod_match:
        raise ValueError(f"{source_file} block {index} is missing a `module Coral.*` declaration")
    return SRC / f"{mod_match.group(0).split('.')[-1].lower()}.ch"


def validate_blocks(blocks: list[tuple[str, int, str]]) -> bool:
    temp_files: list[Path] = []
    try:
        for source_file, index, code in blocks:
            tmp = block_path(code, source_file, index)
            if tmp.exists():
                raise ValueError(f"{source_file} block {index} would overwrite existing {tmp.relative_to(REPO)}")
            tmp.write_text(code)
            temp_files.append(tmp)

        result = subprocess.run(
            [CHELIS, "reef", "build"],
            capture_output=True, text=True, cwd=str(REPO),
        )
        output = (result.stdout + result.stderr).strip()
        if result.returncode != 0:
            print(output)
            return False
        return True
    finally:
        for tmp in temp_files:
            tmp.unlink(missing_ok=True)


def main() -> int:
    if not DOCS_SRC.exists():
        print("docs/book/src/ not found, skipping book validation")
        return 0

    failures = 0
    total = 0
    blocks: list[tuple[str, int, str]] = []

    for md_file in sorted(DOCS_SRC.rglob("*.md")):
        text = md_file.read_text()
        file_blocks = extract_chelis_blocks(text)
        rel = md_file.relative_to(DOCS_SRC)
        for i, block in enumerate(file_blocks):
            total += 1
            blocks.append((str(rel), i, block))

    if total == 0:
        print("No compile-checked code blocks found in mdBook.")
        return 1
    failures = 0 if validate_blocks(blocks) else total
    print(f"{total - failures}/{total} mdBook examples passed.")
    if total < MIN_CHELIS_BLOCKS:
        print(f"FAIL: only {total} full `chelis` example blocks found; need at least {MIN_CHELIS_BLOCKS}.")
        return 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
