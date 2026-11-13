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


def test_tool_manager_paging():
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ)
        env["HOME"] = d
        term = Terminal(SCRIPT, rows=24, cols=80, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            term.expect(b"VSCodium", timeout=5)
            term.expect(b"Hermes", timeout=5)
            at = len(term.output)
            # Navigate to the final page of the 22-entry menu (16 tools + 6 actions).
            # The Back action is at index 21; 11 moves only reach the middle page.
            term.send(b"\x1b[B" * 21)
            term.expect(b"Automatic installation preview", after=at, timeout=5)
            term.expect(b"Back to main menu", after=at, timeout=5)
            print("PASS: expanded tool menu remains navigable on 24-row terminal")
        finally:
            term.close()


def test_readiness_menu_return():
    # Isolate PATH: the CI runner might have a slow Podman/Docker daemon.
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        (bindir / "bash").symlink_to("/bin/bash")
        # Interactive menus require stty; rendering also uses sed.
        (bindir / "stty").symlink_to(shutil.which("stty"))
        (bindir / "sed").symlink_to(shutil.which("sed"))
        env = dict(os.environ)
        env["HOME"] = d
        env["PATH"] = str(bindir)
        term = Terminal(SCRIPT, rows=24, cols=80, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            at = len(term.output)
            term.send(b"\x1b[B" * 19)
            term.expect(b"Workstation readiness", timeout=5, after=at)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"KUBERNETES TOOLCHAIN", timeout=8, after=at)
            term.expect(b"Inspection only:", after=at, timeout=8)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5, after=at)
            print("PASS: readiness submenu opens and returns without modifications")
        finally:
            term.close()


def test_docker_guide_return():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        (bindir / "bash").symlink_to("/bin/bash")
        # Interactive menus require stty; rendering also uses sed.
        (bindir / "stty").symlink_to(shutil.which("stty"))
        (bindir / "sed").symlink_to(shutil.which("sed"))
        env = dict(os.environ)
        env["HOME"] = d
        env["PATH"] = str(bindir)
        term = Terminal(SCRIPT, rows=24, cols=80, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            at = len(term.output)
            term.send(b"\x1b[B" * 20)
            term.expect(b"Docker & Compose", timeout=6, after=at)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"BLUEFIN", timeout=6, after=at)
            term.expect(b"No packages installed", timeout=6, after=at)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=6, after=at)
            print("PASS: Docker & Compose guide opens and returns to Tool Manager")
        finally:
            term.close()


def test_settings_roundtrip():
    # Simulate an installed Nerd Font so this tests preference persistence,
    # not the separate font-install confirmation flow.
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        fc_list = bindir / "fc-list"
        fc_list.write_text("#!/bin/sh\nprintf 'JetBrainsMono Nerd Font\\n'\n")
        fc_list.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir) + os.pathsep + env["PATH"]
        env["HOME"] = d
        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 7 + b"\r")
            term.expect(b"Icon style: classic", timeout=5)
            at = len(term.output)
            term.send(b"n")
            term.expect(b"Icon style: nerd", timeout=5, after=at)
            assert (Path(d) / ".config/m3/icon-mode").read_text().strip() == "nerd"
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Workstation Setup", timeout=5, after=at)
            print("PASS: Settings Nerd Font persistence and return")
        finally:
            term.close()


def test_tool_manager_readonly():
    with tempfile.TemporaryDirectory() as d:
        env = dict(os.environ)
        env["HOME"] = d
        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5)
            at = len(term.output)
            # Six original tools plus seven new entries: preview index 13.
            term.send(b"\x1b[B" * 13 + b"\r")
            term.expect(b"DRY RUN", timeout=5, after=at)
            term.expect(b"No changes made", timeout=5, after=at)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5, after=at)
            print("PASS: Tool Manager overview, DRY RUN and return")
        finally:
            term.close()


def test_selected_docker_opens_manual_bluefin_guide():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        (bindir / "bash").symlink_to("/bin/bash")
        # Interactive menus require stty; rendering also uses sed.
        (bindir / "stty").symlink_to(shutil.which("stty"))
        (bindir / "sed").symlink_to(shutil.which("sed"))
        env = dict(os.environ)
        env["PATH"] = str(bindir)
        env["HOME"] = d
        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            # Docker is item 9 in the 13-tool inventory.
            term.send(b"\x1b[B" * 8 + b" " + b"\r")
            term.expect(b"SELECTED TOOLS", timeout=5)
            term.expect(b"MANUAL", timeout=5)
            term.expect(b"Opening the Bluefin-specific Docker & Compose guide", timeout=5)
            term.expect(b"BLUEFIN", timeout=5)
            term.expect(b"No packages installed", timeout=5)
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5, after=at)
            print("PASS: selecting Docker opens the safe Bluefin guide, not a fake installer")
        finally:
            term.close()


def test_confirmed_tool_install_via_menu():
    # A restricted PATH makes Go missing and ensures only our fake brew can run.
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        log = Path(d) / "brew-actions.log"
        fake_brew = bindir / "brew"
        fake_brew.write_text(
            "#!/bin/bash\n"
            'printf "%s\\n" "$*" >> "$M3_MOCK_LOG"\n'
            'printf "mock installation succeeded\\n"\n'
        )
        fake_brew.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir)
        env["HOME"] = d
        env["M3_MOCK_LOG"] = str(log)
        env.pop("DISTROBOX_ENTER_PATH", None)
        env.pop("CONTAINER_ID", None)

        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            term.send(b"\x1b[B" * 4 + b" " + b"\r")
            term.expect(b"SELECTED TOOLS", timeout=5)
            term.expect(b"brew install --formula go", timeout=5)
            assert not log.exists(), "Homebrew ran before user confirmed"
            term.send(b"\r")
            term.expect(b"Cancelled", timeout=5)
            assert not log.exists(), "Homebrew ran on blank confirmation"
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5)
            term.send(b"\r")
            term.expect(b"Type", timeout=5)
            term.send(b"INSTALL\r")
            term.expect(b"mock installation succeeded", timeout=5)
            assert log.read_text() == "install --formula go\n"
            print("PASS: menu dry-run cancel then explicit INSTALL invokes only mocked Homebrew")
        finally:
            term.close()


def test_terraform_requires_explicit_confirmation():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        log = Path(d) / "brew-actions.log"
        fake_brew = bindir / "brew"
        fake_brew.write_text(
            "#!/bin/bash\n"
            'printf "%s\\n" "$*" >> "$M3_MOCK_LOG"\n'
            "exit 0\n"
        )
        fake_brew.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir)
        env["HOME"] = d
        env["M3_MOCK_LOG"] = str(log)
        env.pop("DISTROBOX_ENTER_PATH", None)
        env.pop("CONTAINER_ID", None)

        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            term.send(b"\x1b[B" * 5 + b" " + b"\r")
            term.expect(b"brew tap hashicorp/tap && brew install --formula hashicorp/tap/terraform", timeout=5)
            assert not log.exists(), "Terraform began installing without approval"
            term.send(b"\r")
            term.expect(b"Cancelled", timeout=5)
            assert not log.exists(), "Terraform ran despite cancellation"
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5)
            term.send(b"\r")
            term.expect(b"Type", timeout=5)
            term.send(b"INSTALL\r")
            term.expect(b"Homebrew completed successfully", timeout=5)
            assert log.read_text().splitlines() == [
                "tap hashicorp/tap", "install --formula hashicorp/tap/terraform"
            ], "Unexpected Terraform install operations"
            print("PASS: Terraform preview/cancel and confirmed tap+install")
        finally:
            term.close()


def test_tool_batch_stops_after_first_failure():
    with tempfile.TemporaryDirectory() as d:
        bindir = Path(d) / "bin"
        bindir.mkdir()
        (bindir / "dirname").symlink_to("/usr/bin/dirname")
        log = Path(d) / "brew-actions.log"
        fake_brew = bindir / "brew"
        fake_brew.write_text(
            "#!/bin/bash\n"
            'printf "%s\\n" "$*" >> "$M3_MOCK_LOG"\n'
            "exit 23\n"
        )
        fake_brew.chmod(0o755)
        env = dict(os.environ)
        env["PATH"] = str(bindir)
        env["HOME"] = d
        env["M3_MOCK_LOG"] = str(log)
        env.pop("DISTROBOX_ENTER_PATH", None)
        env.pop("CONTAINER_ID", None)

        term = Terminal(SCRIPT, env=env)
        try:
            term.expect(b"DevOps Workstation Setup")
            term.send(b"\x1b[B" * 2 + b"\r")
            term.expect(b"TOOLCHAIN", timeout=8)
            term.send(b"\x1b[B" * 3 + b" " + b"\x1b[B" + b" " + b"\r")
            term.expect(b"SELECTED TOOLS", timeout=5)
            term.expect(b"2 approved for Homebrew installation", timeout=5)
            assert not log.exists()
            term.send(b"INSTALL\r")
            term.expect(b"Stopping: remaining tools will not be attempted", timeout=5)
            assert log.read_text() == "install --formula kubernetes-cli\n", (
                "Second tool was attempted despite first failure"
            )
            at = len(term.output)
            term.send(b"\r")
            term.expect(b"DevOps Tool Manager", timeout=5, after=at)
            print("PASS: failure stops batch and returns to Tool Manager")
        finally:
            term.close()


def test_info_return():
    term = Terminal(SCRIPT)
    try:
        term.expect(b"DevOps Workstation Setup")
        term.send(b"\x1b[B" * 8 + b"\r")
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
        (scripts / "lib").mkdir()
        for lib in ("tool-install.sh", "tool-detect.sh", "ui.sh"):
            shutil.copy2(ROOT / "scripts" / "lib" / lib, scripts / "lib" / lib)
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
    test_tool_manager_paging()
    test_readiness_menu_return()
    test_docker_guide_return()
    test_container_manager()
    test_settings_roundtrip()
    test_tool_manager_readonly()
    test_selected_docker_opens_manual_bluefin_guide()
    test_confirmed_tool_install_via_menu()
    test_terraform_requires_explicit_confirmation()
    test_tool_batch_stops_after_first_failure()
    test_project_manager()
    test_info_return()
    test_no_update_return()
