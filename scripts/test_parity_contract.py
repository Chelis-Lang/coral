#!/usr/bin/env python3
"""Contract tests for Coral's generated runtime parity programs."""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from parity import run_parity


class ParityContractTests(unittest.TestCase):
    def test_window_program_pins_fixture_input_and_output_extent(self) -> None:
        fixture = json.loads(
            (run_parity.WINDOW_GOLDENS / "rolling_mean_w3.json").read_text()
        )

        program = run_parity.window_program(fixture)

        self.assertIn(
            "def rt_window_call(values: tensor[5, f32]) -> tensor[5, f32]",
            program,
        )
        self.assertIn("rolling_mean(values, cast(3, int64))", program)
        self.assertIn("to_list(rt_window_call(to_tensor([", program)


if __name__ == "__main__":
    unittest.main()
