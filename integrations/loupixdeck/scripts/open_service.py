#!/usr/bin/env python3
"""Open allowlisted self-hosting services from a local URL config, without shell."""
import json
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlsplit

ALLOWED = frozenset({
    "karakeep", "prometheus", "alertmanager", "argocd", "portainer",
    "dockge", "proxmox", "truenas", "homepage"
})
CONFIG = Path.home() / ".config" / "m3-devops" / "services.json"


def fail(message):
    print(message, file=sys.stderr)
    try:
        subprocess.run(["notify-send", "m³ Selfhosting", message],
                       check=False, timeout=2)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return 1


def valid_url(url):
    if not isinstance(url, str) or not url or any(c.isspace() for c in url):
        return False
    try:
        parsed = urlsplit(url)
        return (parsed.scheme in ("http", "https")
                and bool(parsed.hostname)
                and parsed.username is None
                and parsed.password is None
                and not any(c in parsed.netloc for c in ('"', "'", "\\")))
    except ValueError:
        return False


def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if len(args) != 1 or args[0] not in ALLOWED:
        return fail("Unknown service. See integrations/loupixdeck/README.md")
    name = args[0]
    try:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return fail("Missing or invalid ~/.config/m3-devops/services.json")
    url = config.get(name) if isinstance(config, dict) else None
    if not valid_url(url):
        return fail("Configure the URL for '" + name + "' in services.json")
    try:
        subprocess.Popen(["xdg-open", url], stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        return fail("xdg-open is not available")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
