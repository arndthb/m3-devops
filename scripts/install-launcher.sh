#!/usr/bin/env bash
# Install a per-user m3 launcher; does not install DevOps tools.
set -euo pipefail
repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$repo/scripts/m3.sh" && -d "$repo/.git" ]] || { printf 'Run this from a Git checkout of m3-devops.\n' >&2; exit 1; }
mkdir -p "$HOME/.local/bin"
launcher="$HOME/.local/bin/m3"
if [[ -e "$launcher" || -L "$launcher" ]]; then
  printf 'Launcher already exists: %s (not overwritten).\n' "$launcher" >&2
  exit 1
fi
printf -v repo_quoted '%q' "$repo"
cat > "$launcher" <<EOF
#!/usr/bin/env bash
set -euo pipefail
repo=$repo_quoted
case "\${1:-}" in
  update)
    cd -- "\$repo"
    if [[ -n "\$(git status --porcelain)" ]]; then
      printf 'Local changes found; update cancelled.\\n' >&2
      exit 1
    fi
    git pull --ff-only origin main
    ;;
  ''|start) exec bash "\$repo/scripts/m3.sh" ;;
  *) printf 'Usage: m3 [start|update]\\n' >&2; exit 2 ;;
esac
EOF
chmod 755 "$launcher"
printf 'Installed launcher: %s\n' "$launcher"
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  printf 'Add ~/.local/bin to PATH to use m3 from anywhere.\n'
fi
printf 'Try: m3\n'
