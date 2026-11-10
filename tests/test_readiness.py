#!/usr/bin/env python3
"""Read-only Bluefin provider tests with isolated fake executables."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "setup-check.sh"


def fake(bindir, name, body):
    p = bindir / name
    p.write_text("#!/bin/bash\n" + body)
    p.chmod(0o755)
    return p


def run(env):
    return subprocess.run(["/bin/bash", str(SCRIPT)], env=env,
                          capture_output=True, text=True, timeout=12)


def test_podman_ready():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        log = Path(d) / "actions.log"
        fake(bindir, "podman",
             'printf "podman:%s\\n" "$*" >> "$M3_READINESS_LOG"\n'
             '[[ "$1" == info ]] && exit 0\n'
             'exit 19\n')
        fake(bindir, "docker",
             'printf "docker:%s\\n" "$*" >> "$M3_READINESS_LOG"\n'
             'exit 7\n')
        fake(bindir, "codium", "exit 0\n")
        fake(bindir, "kind", "exit 0\n")
        fake(bindir, "kubectl", "exit 0\n")
        fake(bindir, "hermes-agent", "exit 0\n")
        env = dict(os.environ, HOME=d, PATH=str(bindir), M3_READINESS_LOG=str(log))
        result = run(env)
        assert result.returncode == 0, result.stderr
        assert "VSCodium" in result.stdout
        assert "Hermes" in result.stdout
        assert "Podman" in result.stdout and "Engine reachable" in result.stdout
        assert "Docker" in result.stdout and "daemon unavailable" in result.stdout
        assert "Provider: Podman" in result.stdout
        assert "KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster" in result.stdout
        assert "Inspection only:" in result.stdout
        commands = log.read_text().splitlines()
        allowed = {
            "podman:info --format {{.Host.Arch}}",
            "docker:info --format {{.ServerVersion}}",
            "docker:compose version",
        }
        assert "podman:info --format {{.Host.Arch}}" in commands, commands
        assert "docker:info --format {{.ServerVersion}}" in commands, commands
        assert set(commands).issubset(allowed), (
            "Readiness ran an unexpected container command: " + repr(commands)
        )
        print("PASS: Podman provider selected without creating a cluster")


def test_missing_provider():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        env = dict(os.environ, HOME=d, PATH=str(bindir))
        result = run(env)
        assert result.returncode == 0, result.stderr
        assert "No working container engine verified" in result.stdout
        assert "Install from m" in result.stdout
        assert "No CLI or Flatpak detected" in result.stdout
        assert "Inspection only:" in result.stdout
        print("PASS: missing runtime and IDE display guidance, with no installs")


if __name__ == "__main__":
    test_podman_ready()
    test_missing_provider()
