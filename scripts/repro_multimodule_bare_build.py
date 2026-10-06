#!/usr/bin/env python3
"""Probe a trivial-entry native build of Coral's stripped modules.

This is an upstream-triage probe, not a CI gate.

It concatenates Coral's Frame, GroupBy, or Join module (plus its Coral and
Nautilus dependencies) into one temporary file, prefixes function names to
avoid symbol collisions, adds a constant `main`, runs `chelis build`, compiles
with the command the compiler prints, runs the binary, and reads the `main`
observation line. It is a module-lowering smoke test, not proof that invoked
Frame APIs lower; that boundary is probed by `repro_package_frame_build.py`
and `repro_native_drop_nan_blocked.py`.

Expected outcome at the current pin: `chelis build` rejects every target with
the chelis#2097 ownership-signature diagnostic. The earlier chelis#730
unresolved-host-type diagnostic no longer appears at this boundary; this
probe does not establish that the broader #730 class is fixed. See
docs/UPSTREAM_BUGS.md.

The module also owns helpers shared by the other native probes and by
`parity/run_parity.py`: def extraction, name prefixing, the emitted compile
command, and the `<name> = <value>` observation parser.

Exit codes:
- 0: the outcome matches docs/UPSTREAM_BUGS.md (blocked by chelis#2097)
- 1: the outcome changed (FIX-DETECTED, or a different failure) or the probe
  could not run
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO))

from scripts.chelis_toolchain import resolve_chelis_bin


CHELIS = resolve_chelis_bin()

# Stable substring of the chelis#2097 rejection. The local function id is
# volatile and deliberately excluded.
CHELIS_2097_DIAGNOSTIC = "does not match ownership signature"


def _registry_root() -> Path:
    """Where reef keeps installed packages, honouring the same overrides reef does.

    A pin bump that lands ahead of its sibling's release has to resolve the
    dependency out of a scoped registry rather than the shared one, so this
    probe has to agree with `chelis reef build` about which registry is in
    play instead of hardcoding the default.
    """
    reef_home = os.environ.get("CHELIS_REEF_HOME")
    if reef_home:
        return Path(reef_home)
    chelis_home = os.environ.get("CHELIS_HOME")
    if chelis_home:
        return Path(chelis_home) / "reef"
    return Path.home() / ".chelis" / "reef"


def _nautilus_tarball() -> Path:
    reef_toml = REPO / "reef.toml"
    with open(reef_toml, "rb") as f:
        deps = tomllib.load(f).get("dependencies", {})
    nautilus_version = deps.get("nautilus", {}).get("version", "")
    if not nautilus_version:
        raise RuntimeError("nautilus dependency not found in reef.toml")
    tarball = _registry_root() / "packages" / "nautilus" / nautilus_version / f"nautilus-{nautilus_version}.tar.zst"
    if not tarball.exists():
        raise RuntimeError(f"nautilus {nautilus_version} not found in local reef registry: {tarball}")
    return tarball


def _nautilus_src(member_path: str) -> str:
    """Extract one source file from the Nautilus package in the local reef registry."""
    import io

    tarball = _nautilus_tarball()
    try:
        tf = tarfile.open(tarball, "r:*")
    except tarfile.ReadError:
        # stdlib tarfile reads zstd only on Python >= 3.14; fall back to the
        # zstd binary (the script already shells out to gcc, so an external
        # tool is fair game).
        zstd = shutil.which("zstd")
        if zstd is None:
            raise RuntimeError(
                f"cannot read {tarball}: need Python >= 3.14 (tarfile zstd) or a `zstd` binary on PATH"
            )
        try:
            raw = subprocess.run([zstd, "-dc", str(tarball)], check=True, capture_output=True).stdout
        except subprocess.CalledProcessError as exc:
            reason = exc.stderr.decode(errors="replace").strip()
            raise RuntimeError(f"zstd failed to decompress {tarball}: {reason}") from exc
        tf = tarfile.open(fileobj=io.BytesIO(raw), mode="r:")
    with tf:
        member = tf.getmember(member_path)
        return tf.extractfile(member).read().decode()


# `nautilus:`-prefixed entries resolve from the reef registry at runtime, in
# dependency order: stats.ch imports chi_squared_cdf from Distributions,
# which imports erf/erfinv/log_gamma from Special.
_NAUTILUS_STATS_CHAIN = [
    ("nautilus:src/special.ch", "special__"),
    ("nautilus:src/distributions.ch", "dist__"),
    ("nautilus:src/stats.ch", "stats__"),
]

MODULE_PRESETS = {
    "frame": [
        ("src/internal/hamt.ch", "hamt__"),
        *_NAUTILUS_STATS_CHAIN,
        ("src/frame.ch", "frame__"),
    ],
    "groupby": [
        ("src/internal/hamt.ch", "hamt__"),
        *_NAUTILUS_STATS_CHAIN,
        ("src/frame.ch", "frame__"),
        ("src/groupby.ch", "groupby__"),
    ],
    "join": [
        ("src/internal/hamt.ch", "hamt__"),
        *_NAUTILUS_STATS_CHAIN,
        ("src/frame.ch", "frame__"),
        ("src/join.ch", "join__"),
    ],
}


def strip_module_surface(src: str) -> str:
    src = re.sub(r"^module .*\n", "", src, flags=re.M)
    src = re.sub(r"^import .*\n", "", src, flags=re.M)
    src = re.sub(r"^export \([^)]*\)\s*\n", "", src, flags=re.M | re.S)
    return src


_STRING_LITERAL_RE = re.compile(r'"(?:\\.|[^"\\])*"')


def apply_name_map(src: str, mapping: dict[str, str]) -> str:
    # Whole-word rename: besides `name(` / `name[` call sites, functions are
    # referenced bare in pipe chains (`x |> name |> ...`) and as first-class
    # arguments, which lookahead-based rewrites miss. String literals are
    # excluded — a def name that is also an English word (e.g. `columns`)
    # must not be rewritten inside fail() messages, or the synthesized
    # program's diagnostics diverge from the real modules. Known limitation:
    # locals that share a def's name still get renamed (harmless shadowing
    # today; scope-aware renaming is out of a triage harness's weight class).
    def rename(segment: str) -> str:
        for old, new in sorted(mapping.items(), key=lambda item: -len(item[0])):
            segment = re.sub(rf"\b{re.escape(old)}\b", new, segment)
        return segment

    parts: list[str] = []
    last = 0
    for m in _STRING_LITERAL_RE.finditer(src):
        parts.append(rename(src[last : m.start()]))
        parts.append(m.group(0))
        last = m.end()
    parts.append(rename(src[last:]))
    return "".join(parts)


def prefix_defs(src: str, prefix: str) -> tuple[str, dict[str, str]]:
    names = re.findall(r"^def\s+([A-Za-z_][A-Za-z0-9_]*)", src, flags=re.M)
    mapping = {name: f"{prefix}{name}" for name in names}
    return apply_name_map(src, mapping), mapping


def extract_named_defs(src: str, names: list[str]) -> str:
    """Return the source of the named top-level defs, in file order.

    A top-level def runs from its `def <name>` header to the next top-level
    `def ` (or end of file). This lets a probe natively compile a specific
    slice of a module -- e.g. Coral's own frame NaN helpers -- without
    flat-pasting the whole module chain the full file would otherwise drag in.
    The caller must name every genuine dependency; a body that references a def
    not in `names` (and not a builtin) would lower to an undeclared C call.
    """
    wanted = set(names)
    headers = list(re.finditer(r"^def\s+([A-Za-z_][A-Za-z0-9_]*)", src, flags=re.M))
    present = {m.group(1) for m in headers}
    missing = wanted - present
    if missing:
        raise RuntimeError(f"defs not found in module source: {sorted(missing)}")
    blocks: list[str] = []
    for idx, m in enumerate(headers):
        if m.group(1) not in wanted:
            continue
        start = m.start()
        end = headers[idx + 1].start() if idx + 1 < len(headers) else len(src)
        blocks.append(src[start:end].rstrip())
    return "\n".join(blocks)


def build_prefixed_modules(specs: list[tuple[str, str]]) -> str:
    accumulated: dict[str, str] = {}
    parts: list[str] = []
    for rel_path, prefix in specs:
        raw = (
            _nautilus_src(rel_path.removeprefix("nautilus:"))
            if rel_path.startswith("nautilus:")
            else (REPO / rel_path).read_text()
        )
        src = strip_module_surface(raw)
        src, local_map = prefix_defs(src, prefix)
        src = apply_name_map(src, accumulated)
        parts.append(src)
        accumulated.update(local_map)
    return "\n".join(parts)


BUILT_PREFIX = "Built executable "


def built_executable_path(build_output: str) -> Path:
    """Return the executable that `chelis build` compiled and linked."""
    for line in build_output.splitlines():
        stripped = line.strip()
        if stripped.startswith(BUILT_PREFIX):
            binary = Path(stripped[len(BUILT_PREFIX) :])
            if binary.is_file():
                return binary
            raise RuntimeError(f"`chelis build` reported a missing executable: {binary}")
    raise RuntimeError("`chelis build` reported no executable")


def observed_root(stdout: str, name: str) -> str | None:
    """Read one `<name> = <value>` observation out of a compiled run.

    The compiled program and `chelis eval` print observed roots in the same
    form, so a probe can compare the two lanes line for line.
    """
    prefix = f"{name} = "
    for line in stdout.splitlines():
        if line.startswith(prefix):
            return line[len(prefix) :].strip()
    return None


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=sorted(MODULE_PRESETS), default="groupby")
    args = parser.parse_args()

    body = build_prefixed_modules(MODULE_PRESETS[args.target])
    body += "\n\ndef main() -> f32 = cast(1.0, f32)\n"

    workdir = Path(tempfile.mkdtemp(prefix=f"coral-repro-{args.target}-"))
    try:
        main_ch = workdir / "main.ch"
        main_ch.write_text(body)
        fmt = subprocess.run([CHELIS, "fmt", "--inplace", str(main_ch)], capture_output=True, text=True)
        if fmt.returncode != 0:
            print((fmt.stdout + fmt.stderr).strip())
            print("unexpected: `chelis fmt --inplace` failed on the synthesized module")
            return 1
        out_dir = workdir / "out"
        build = subprocess.run([CHELIS, "build", str(main_ch), "-o", str(out_dir)], capture_output=True, text=True)
        print((build.stdout + build.stderr).strip())
        if build.returncode != 0:
            if CHELIS_2097_DIAGNOSTIC in (build.stdout or "") + (build.stderr or ""):
                print(f"expected blocked: {args.target} stops at the chelis#2097 ownership-signature boundary")
                return 0
            print("unexpected: `chelis build` failed before native C compile")
            return 1

        build_output = (build.stdout or "") + (build.stderr or "")
        PHASE0E_PANIC = "`if` is not representable in the Phase 0e RISC DAG"
        if PHASE0E_PANIC in build_output:
            print("regression: Phase 0e RISC DAG panic reappeared in chelis build output")
            return 1

        binary = built_executable_path(build_output)

        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
        if run.returncode != 0:
            print(run.stderr.strip())
            print(f"regression: binary exited with rc={run.returncode}")
            return 1

        entry_value = observed_root(run.stdout, "main")
        if entry_value is None or float(entry_value) != 1.0:
            print(run.stdout.strip())
            print(f"regression: entry observed as {entry_value!r}, expected 1.0")
            return 1

        print(f"trivial-entry stripped multi-module smoke OK: build clean, link OK, run OK (main = {entry_value})")
        print("FIX-DETECTED: chelis#2097 no longer blocks this target; re-probe the full native path")
        return 1
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
