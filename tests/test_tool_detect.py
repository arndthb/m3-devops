#!/usr/bin/env python3
"""Check Bluefin tool detection using isolated fake commands, no installs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / "scripts/lib/tool-detect.sh"


def invoke(code, env):
    return subprocess.run(
        ["/bin/bash", "-c", 'source "$1"; ' + code, "_", str(LIB)],
        env=env, capture_output=True, text=True, timeout=10,
    )


def check():
    with tempfile.TemporaryDirectory() as directory:
        home = Path(directory)
        bindir = home / "bin"
        bindir.mkdir()
        env = dict(os.environ, HOME=str(home), PATH=str(bindir))
        # A fake Flatpak installation is found even when codium is not on PATH.
        flatpak = bindir / "flatpak"
        flatpak.write_text(
            "#!/bin/bash\n"
            '[[ "$1" == info && "$2" == com.vscodium.codium ]]\n'
        )
        flatpak.chmod(0o755)
        assert invoke("m3_tool_present codium", env).returncode == 0
        assert invoke("m3_tool_source codium", env).stdout == "Flatpak"
        assert invoke("m3_tool_present hermes", env).returncode != 0

        # Hermes can appear under either CLI name.
        hermes = bindir / "hermes-agent"
        hermes.write_text("#!/bin/bash\nexit 0\n")
        hermes.chmod(0o755)
        assert invoke("m3_tool_present hermes", env).returncode == 0

        # Docker CLI alone is not sufficient to report Compose as present.
        docker = bindir / "docker"
        docker.write_text("#!/bin/bash\nexit 1\n")
        docker.chmod(0o755)
        assert invoke("m3_tool_present docker", env).returncode == 0
        assert invoke("m3_tool_present compose", env).returncode != 0
        docker.write_text(
            "#!/bin/bash\n"
            '[[ "$1" == compose && "$2" == version ]]\n'
        )
        assert invoke("m3_tool_present compose", env).returncode == 0
        assert invoke("m3_tool_source compose", env).stdout == "Docker plugin"

        docker.unlink()
        assert invoke("m3_tool_present docker", env).returncode != 0
        podman_compose = bindir / "podman-compose"
        podman_compose.write_text("#!/bin/bash\nexit 0\n")
        podman_compose.chmod(0o755)
        assert invoke("m3_tool_present compose", env).returncode == 0
        assert invoke("m3_tool_source compose", env).stdout == "podman-compose"

        for tool in ("kind", "make", "curl"):
            executable = bindir / tool
            executable.write_text("#!/bin/bash\nexit 0\n")
            executable.chmod(0o755)
            assert invoke("m3_tool_present " + tool, env).returncode == 0

        assert invoke("m3_tool_label codium", env).stdout == "VSCodium"
        assert invoke("m3_tool_present invalid-tool", env).returncode != 0
        assert invoke("m3_tool_hint kind", env).returncode == 0
        print("PASS: Flatpak VSCodium, Hermes, Docker/Compose split, kind/make/curl")


if __name__ == "__main__":
    check()
