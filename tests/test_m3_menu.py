#!/usr/bin/env python3
"""PTY regression checks for the m³ interactive Bash menu (no network)."""
import errno
import os
from pathlib import Path
import pty
import select
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "m3.sh"


class Terminal:
    def __init__(self, script):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execv("/bin/bash", ["bash", str(script)])
        self.output = bytearray()

    def send(self, data):
        os.write(self.fd, data)

    def expect(self, marker, timeout=10, after=0):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if marker in self.output[after:]:
                return
            ready, _, _ = select.select([self.fd], [], [], 0.1)
            if ready:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError as exc:
                    if exc.errno == errno.EIO:
                        break
                    raise
                if not chunk:
                    break
                self.output.extend(chunk)
        raise AssertionError(
            "Did not see %r after offset %d. Last output: %r"
            % (marker, after, bytes(self.output[-900:]))
        )

    def close(self):
        try:
            os.kill(self.pid, 15)
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)
        os.close(self.fd)


def test_info_return():
    term = Terminal(SCRIPT)
    try:
        term.expect(b"DevOps Workstation Setup")
        term.send(b"\x1b[B" * 7 + b"\r")
        term.expect(b"ABOUT m", timeout=5)
        at = len(term.output)
        term.send(b"\r")
        term.expect(b"DevOps Workstation Setup", timeout=5, after=at)
        print("PASS: Info -> Enter -> main menu is redrawn")
    finally:
        term.close()


def git(cwd, *args):
    subprocess.run(["git", *args], cwd=cwd, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def test_no_update_return():
    with tempfile.TemporaryDirectory() as d:
        base = Path(d)
        repo = base / "repo"
        scripts = repo / "scripts"
        scripts.mkdir(parents=True)
        shutil.copy2(SCRIPT, scripts / "m3.sh")
        git(base, "init", "-b", "main", str(repo))
        git(repo, "config", "user.email", "ci@example.invalid")
        git(repo, "config", "user.name", "CI Test")
        git(repo, "add", ".")
        git(repo, "commit", "-m", "test fixture")
        origin = base / "origin.git"
        git(base, "init", "--bare", "-b", "main", str(origin))
        git(repo, "remote", "add", "origin", str(origin))
        git(repo, "push", "-u", "origin", "main")

        term = Terminal(scripts / "m3.sh")
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 5 + b"\r")
            term.expect(b"No new commits.", timeout=10)
            term.expect(b"Returning to main menu in 3", timeout=5)
            at = len(term.output)
            term.expect(b"DevOps Workstation Setup", timeout=7, after=at)
            print("PASS: already up-to-date -> 3/2/1 countdown -> main menu")
        finally:
            term.close()


if __name__ == "__main__":
    test_info_return()
    test_no_update_return()
