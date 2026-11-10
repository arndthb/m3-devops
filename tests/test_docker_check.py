#!/usr/bin/env python3
"""Mocked Docker/Compose report tests. No Docker daemon or package operations."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / "scripts/docker-check.sh"


def put_script(folder, name, text):
    path = folder / name
    path.write_text("#!/bin/bash\n" + text)
    path.chmod(0o755)


def run_case(online):
    with tempfile.TemporaryDirectory() as directory:
        folder = Path(directory)
        binpath = folder / "bin"
        binpath.mkdir()
        (binpath / "dirname").symlink_to("/usr/bin/dirname")
        log = folder / "commands"
        if online:
            put_script(binpath, "docker",
                'printf "docker:%s\\n" "$*" >> "$M3_DOCKER_LOG"\n'
                'case "$1" in\n'
                '  context) printf "default\\n" ;;\n'
                '  info) exit 0 ;;\n'
                '  compose) [[ "$2" == version ]] && exit 0 ;;\n'
                'esac\n'
                'exit 1\n')
            put_script(binpath, "podman",
                'printf "podman:%s\\n" "$*" >> "$M3_DOCKER_LOG"\n'
                '[[ "$1" == info ]]')
        env = dict(os.environ)
        env["HOME"] = directory
        env["PATH"] = str(binpath)
        env["M3_DOCKER_LOG"] = str(log)
        result = subprocess.run(["/bin/bash", str(CHECK)], env=env,
                                capture_output=True, text=True, timeout=10)
        assert result.returncode == 0, result.stderr
        assert "No packages installed, services changed or containers started" in result.stdout
        if online:
            assert "Docker Engine and Compose are available" in result.stdout
            assert "Docker CLI plugin available" in result.stdout
            commands = log.read_text().splitlines()
            assert commands == [
                "docker:context show",
                "docker:info --format {{.ServerVersion}}",
                "docker:compose version",
                "podman:info --format {{.Host.Arch}}",
            ], commands
            print("PASS: only read-only Docker/Compose/Podman probes")
        else:
            assert "Not found in this terminal" in result.stdout
            assert "ujust devmode" in result.stdout
            assert not log.exists()
            print("PASS: missing Docker displays Bluefin DX guide; makes no changes")


if __name__ == "__main__":
    run_case(True)
    run_case(False)
