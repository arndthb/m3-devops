#!/usr/bin/env python3
"""PTY regression checks for the m³ interactive Bash menu (no network)."""
import errno
import fcntl
import struct
import termios
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
    def __init__(self, script, rows=24, cols=80, env=None):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ,
                        struct.pack('HHHH', rows, cols, 0, 0))
            args = ["bash", str(script)]
            if env is None:
                os.execv("/bin/bash", args)
            else:
                os.execve("/bin/bash", args, env)
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
            os.kill(self.pid, 9)  # Bash traps TERM to restore the cursor without exiting
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)
        os.close(self.fd)


def test_main_menu_layout():
    # Verify row positions and incremental redraws in both densities.
    for rows, cols, next_row in [(24, 80, 9), (40, 100, 10)]:
        term = Terminal(SCRIPT, rows=rows, cols=cols)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.expect(b"BUILD")
            initial = len(term.output)
            term.send(b"\x1b[B")
            term.expect(("\x1b[%d;1H" % next_row).encode(),
                        timeout=5, after=initial)
            print("PASS: %d-row layout arrow navigation" % rows)
        finally:
            term.close()


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


def test_container_manager():
    container_script = ROOT / "scripts" / "container-manager.sh"
    with tempfile.TemporaryDirectory() as d:
        fake_podman = Path(d) / "podman"
        fake_podman.write_text("""#!/usr/bin/env bash
case "$1" in
  info) printf 'amd64\\n' ;;
  volume)
    if [[ "$2" == ls ]]; then
      printf 'db_data\\n'
      printf '%064d\\n' 0
    fi ;;
  *) printf 'mock output\\n' ;;
esac
""")
        fake_podman.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = d + os.pathsep + env.get("PATH", "")
        term = Terminal(container_script, rows=40, cols=100, env=env)
        try:
            term.expect(b"Container Manager")
            term.expect(b"CONTAINERS")
            start = len(term.output)
            term.send(b"\x1b[B")
            term.expect(b"\x1b[10;1H", timeout=5, after=start)
            term.send(b"\x1b[B" + b"\r")
            term.expect(b"VOLUME NAME", timeout=5)
            term.expect(b"Auto-generated", timeout=5)
            term.expect(b"automatically named", timeout=5)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"Container Manager", timeout=5, after=at)
            print("PASS: Container Manager incremental navigation / volume labels / return")
        finally:
            term.close()



def test_project_manager():
    project_script = ROOT / "scripts" / "project-manager.sh"
    with tempfile.TemporaryDirectory() as d:
        home = Path(d) / "home"
        root = home / "Projects"
        root.mkdir(parents=True)
        alpha = root / "alpha"
        alpha.mkdir()
        git(root, "init", "-b", "main", str(alpha))
        git(alpha, "config", "user.email", "ci@example.invalid")
        git(alpha, "config", "user.name", "CI Test")
        (alpha / "README.md").write_text("hello\n")
        git(alpha, "add", "README.md")
        git(alpha, "commit", "-m", "initial commit")
        (alpha / "README.md").write_text("changed\n")
        (root / "beta").mkdir()
        (root / "beta" / "compose.yaml").write_text("services: {}\n")
        for i in range(18):
            directory = root / ("demo-%02d" % i)
            directory.mkdir()
            (directory / "compose.yaml").write_text("services: {}\n")

        env = dict(os.environ)
        env["HOME"] = str(home)
        env["LC_ALL"] = "C.UTF-8"
        term = Terminal(project_script, rows=24, cols=100, env=env)
        try:
            term.expect(b"DevOps Project Manager")
            term.expect(b"20 of 20 shown")
            at = len(term.output)
            term.send(b"/alpha\r")
            term.expect(b"Search: alpha", timeout=6, after=at)
            term.expect(b"1 of 20 shown")
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"Project: Projects/alpha", timeout=5, after=at)
            term.expect(b"Recent commits:", after=at)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Project Manager", timeout=5, after=at)
            at = len(term.output)
            term.send(b"f")
            term.expect(b"Filter: Git", timeout=5, after=at)
            at = len(term.output)
            term.send(b"f")
            term.expect(b"No projects match this search/filter", timeout=5, after=at)
            at = len(term.output)
            term.send(b"c")
            term.expect(b"19 of 20 shown", timeout=5, after=at)
            # Crossing the end of the 11-row viewport repaints the banner.
            at = len(term.output)
            term.send(b"\x1b[B" * 12)
            term.expect(b"DevOps Project Manager", timeout=5, after=at)
            # A refresh reads newly created Compose projects without re-execing Bash.
            added = root / "later-added"
            added.mkdir()
            (added / "compose.yaml").write_text("services: {}\n")
            at = len(term.output)
            term.send(b"r")
            term.expect(b"20 of 21 shown", timeout=5, after=at)
            at = len(term.output)
            term.send(b"f")
            term.expect(b"Filter: Changed", timeout=5, after=at)
            term.expect(b"1 of 21 shown", after=at)
            print("PASS: Project Manager search/filter/paging/details/rescan")
        finally:
            term.close()

    # No-match and no-project states must stay interactive, not crash or exit.
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ)
        env["HOME"] = d
        term = Terminal(project_script, rows=24, cols=80, env=env)
        try:
            term.expect(b"No projects match this search/filter", timeout=5)
            at = len(term.output)
            term.send(b"f")
            term.expect(b"Filter: Git", timeout=5, after=at)
            print("PASS: Project Manager empty state")
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
    test_main_menu_layout()
    test_container_manager()
    test_project_manager()
    test_info_return()
    test_no_update_return()
