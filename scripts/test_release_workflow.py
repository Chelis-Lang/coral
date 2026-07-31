#!/usr/bin/env python3
"""Static contracts for Coral's release and toolchain-install workflows."""

from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleaseWorkflowTests(unittest.TestCase):
    def test_toolchain_download_is_checksum_verified_and_compatibility_scoped(
        self,
    ) -> None:
        action = (ROOT / ".github/actions/install-chelis/action.yml").read_text()
        self.assertIn("default: linux-x86_64-glibc2.31", action)
        self.assertIn('key: chelis-toolchain-sha256-v1-', action)
        self.assertIn('--pattern "$asset.sha256"', action)
        self.assertIn('sha256sum -c "$asset.sha256"', action)
        self.assertIn('shasum -a 256 -c "$asset.sha256"', action)
        self.assertLess(
            action.index('--pattern "$asset.sha256"'),
            action.index('tar -xzf "/tmp/chelis-toolchain/$asset"'),
        )

    def test_release_rebuild_is_byte_identical_and_publishes_complete_set(
        self,
    ) -> None:
        release = (ROOT / ".github/workflows/release.yml").read_text()
        first_build = release.index("run: chelis reef build")
        seal = release.index("sha256sum \\\n")
        second_build = release.index("chelis reef build", seal)
        verify = release.index("sha256sum -c", second_build)
        publish = release.index("uses: softprops/action-gh-release@v2")
        self.assertLess(first_build, seal)
        self.assertLess(seal, second_build)
        self.assertLess(second_build, verify)
        self.assertLess(verify, publish)
        self.assertIn(
            "dist/${{ env.PACKAGE_NAME }}-${{ env.PACKAGE_VERSION }}.sha256",
            release[publish:],
        )
        self.assertIn("overwrite_files: true", release[publish:])


if __name__ == "__main__":
    unittest.main()
