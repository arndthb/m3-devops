#!/usr/bin/env python3
"""Isolated allowlist and install-confirmation tests. Never invoke real Homebrew."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "scripts/lib/tool-install.sh"


def bash(code, env):
    return subprocess.run(["/bin/bash", "-c", 'source "$1"; ' + code, "_", str(LIB)],
                          env=env, capture_output=True, text=True, timeout=8)


def run_checks():
    with tempfile.TemporaryDirectory() as d:
        directory = Path(d)
        bindir = directory / "bin"
        bindir.mkdir()
        log = directory / "brew.log"
        fake_brew = bindir / "brew"
        fake_brew.write_text(
            "#!/bin/bash\n"
            'printf "%s\\n" "$*" >> "$M3_MOCK_LOG"\n'
            'printf "fake brew complete\\n"\n'
        )
        fake_brew.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir)
        env["HOME"] = str(directory)
        env["M3_MOCK_LOG"] = str(log)
        env.pop("DISTROBOX_ENTER_PATH", None)
        env.pop("CONTAINER_ID", None)

        r = bash('m3_install_command kubectl', env)
        assert r.returncode == 0 and r.stdout == 'brew install --formula kubernetes-cli', r
        r = bash('m3_install_command terraform', env)
        assert r.returncode != 0 and not log.exists(), r
        print("PASS: formula allowlist and reject unsupported tools")

        r = bash('m3_install_tool terraform', env)
        assert r.returncode == 2 and not log.exists(), r
        print("PASS: unsupported install never calls Homebrew")

        blocked = dict(env, DISTROBOX_ENTER_PATH="/usr/bin/distrobox-enter")
        r = bash('m3_install_tool go', blocked)
        assert r.returncode == 2 and "blocked" in r.stdout and not log.exists(), r
        print("PASS: Distrobox context blocks install")

        r = bash('m3_install_tool go', env)
        assert r.returncode == 0 and log.read_text() == "install --formula go\n", r
        print("PASS: explicit installation API calls only allowlisted mocked Homebrew")

        # A real menu interaction must be tested too; see test_m3_menu.py.


if __name__ == "__main__":
    run_checks()
