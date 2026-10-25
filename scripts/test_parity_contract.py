#!/usr/bin/env python3
"""Contract tests for Coral's generated runtime parity programs."""
from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from parity import run_parity
from scripts import repro_multimodule_bare_build as native


class ParityContractTests(unittest.TestCase):
    def test_archive_lookup_accepts_bare_and_explicit_exact_dependency_versions(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            archive = root / "registry/packages/nautilus/0.7.58/nautilus-0.7.58.tar.zst"
            archive.parent.mkdir(parents=True)
            archive.touch()
            with mock.patch.object(native, "REPO", root), mock.patch.object(native, "_registry_root", return_value=root / "registry"):
                for version in ("0.7.58", "=0.7.58"):
                    (root / "reef.toml").write_text(f'[dependencies]\nnautilus = {{ version = "{version}" }}\n')
                    with self.subTest(version=version):
                        self.assertEqual(native._nautilus_tarball(), archive)

    def test_archive_lookup_rejects_nonexact_dependency_selectors(self) -> None:
        with tempfile.TemporaryDirectory() as raw:
            root = Path(raw)
            with mock.patch.object(native, "REPO", root):
                for value in ('">=0.7.58"', '"==0.7.58"', '"=0.7"', '42'):
                    (root / "reef.toml").write_text(f'[dependencies]\nnautilus = {{ version = {value} }}\n')
                    with self.subTest(value=value), self.assertRaises(RuntimeError):
                        native._nautilus_tarball()

    def test_window_program_pins_fixture_input_and_output_extent(self) -> None:
        fixture = json.loads(
            (run_parity.WINDOW_GOLDENS / "rolling_mean_w3.json").read_text()
        )

        program = run_parity.window_program(fixture)

        self.assertIn(
            "def rt_window_call(values: tensor[5, f32]) -> tensor[5, f32]",
            program,
        )
        self.assertIn("rolling_mean(values, cast(3, i64))", program)
        self.assertIn("to_list(rt_window_call(to_tensor([", program)
        self.assertIn("skip(actual, cast(1, i64))", program)
        self.assertNotIn("drop(actual,", program)
        self.assertNotIn("drop(expected,", program)

    def test_generated_programs_have_no_retired_integer_types(self) -> None:
        sources = [case["code"] for case in run_parity.NEGATIVE_CASES]
        for path in sorted(run_parity.WINDOW_GOLDENS.glob("*.json")):
            if path.name != "README.json":
                sources.append(run_parity.window_program(json.loads(path.read_text())))
        for source in sources:
            with self.subTest(source=source[:80]):
                self.assertIsNone(re.search(r"\bint(?:8|16|32|64)\b", source))


if __name__ == "__main__":
    unittest.main()
