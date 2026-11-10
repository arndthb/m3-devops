# m³ – Linux Workstation Automation

**A lightweight, modular toolkit for Linux DevOps workstations.**

m³ aims to inspect and eventually automate DevOps workstation setup. The initial focus is [Bluefin](https://projectbluefin.io/), with other Linux distributions planned.

## v0.1 – Read-only diagnostics

The initial script detects the Linux distribution and checks whether these commands are available: Git, Podman, Distrobox, kubectl, Go, and Terraform. It reports missing tools without installing software or changing configuration.

Run on an existing Linux workstation:

```bash
bash scripts/check-system.sh
```

The script uses standard shell utilities and does not require elevated privileges. A missing command does not necessarily mean the tool is unavailable inside a development container.

## Easy launcher (Linux)

From your existing repository checkout, run once:

```bash
git pull origin main
bash scripts/install-launcher.sh
```

If `~/.local/bin` is in your PATH, start the interactive menu from anywhere with `m3`, or update the repository with `m3 update`. The update uses `git pull --ff-only origin main` and refuses to proceed if the checkout contains local changes. Neither command installs DevOps tools. The launcher does not overwrite an existing `~/.local/bin/m3`.

If `m3` is not found, open a new terminal or add `$HOME/.local/bin` to your PATH.

## Interactive workstation menu

Run `m3` to open the terminal interface. The current menu includes:

- **System diagnostics:** inspect the distribution and availability of development tools.
- **Workstation health check:** inspect CPU, memory, disk, network, Podman, Kubernetes, and Git/GitHub CLI, with a summary status.
- **DevOps Tool Manager:** inspect installed tools, select missing tools with **Space**, then press **Enter** to review exactly which Homebrew commands are approved. Nothing is installed unless you type the case-sensitive word **INSTALL**. On a Bluefin host with Homebrew, m³ initially supports installing **Git**, **Go**, and **kubectl** (`kubernetes-cli`); **Podman**, **Distrobox**, and **Terraform** remain manual-review only. The separate **Automatic installation preview** is strictly read-only. Installation is refused as root, from Distrobox/a detected container, or without Homebrew. No sudo, OS-image changes, or unattended installation are performed.
- **Container Manager:** browse Podman containers, images, volumes, networks, and disk usage without making changes. The menu uses the same highlighted selection and adaptive spacing as the main menu. Automatically generated hexadecimal volume IDs are shortened and labeled; use `podman volume inspect <volume-name>` for full metadata.
- **DevOps Project Manager:** discover local Git and Compose projects, browse with ↑/↓, and open details with Enter.
- **Update m³ / Check Updates:** fetch the latest `origin/main` revision, display the installed and available Git commit IDs (the project does not yet publish separate semantic version numbers), and offer to install an available update with explicit confirmation. Installation is fast-forward only and is refused if local changes exist or branches have diverged. When already current, or after a successful/skipped update, a visible 3–2–1 countdown returns to the main menu. The running menu reloads itself after a successful update to use the new code.
- **Settings and information:** view available configuration and project information.

### DevOps Project Manager

The project manager searches common directories (`~/Projects`, `~/projects`, `~/Developer`, `~/Code`, `~/Documents/DevOps`, and `~`) up to two directory levels deep. It recognizes Git repositories and projects with `compose.yaml`, `compose.yml`, `docker-compose.yml`, or `docker-compose.yaml`. Backup-like directory names are excluded.

The project browser shows the name, Git branch/status, and Compose file in a **paged list**, limited to the terminal's visible height. An asterisk (`*`) indicates local Git changes (including untracked files); `?` indicates unavailable status. A selected project's **scrollable details** include its full path, branch, origin, up to three recent commits, a short working-tree status, the Compose file and top-level entries.

Use **↑/↓** to select a project, **Enter** to open details, **Enter** again to return to the list, and **Esc** to return to the main menu. Press **/** to search project names and paths, **F** to cycle through *All / Git / Compose / Changed*, **C** to clear the search, or **R** to rescan the filesystem. Empty results remain interactive so you can adjust the filter. The project manager is **read-only**: it does not modify repositories, install tools, or start containers. Git status is a snapshot from the last scan, not continuous monitoring.

Menu rendering helpers for Project Manager and Container Manager are shared in `scripts/lib/ui.sh`; this keeps their headers, colors, and selection rows consistent. The other menus will be migrated separately.

### Confirmed tool installation (experimental)

Use **m3 → DevOps Tool Manager → Space** to select one or more missing tools and **Enter** to review the proposed actions. Only tools shown as **READY** will be installed after you explicitly type `INSTALL` and press Enter. Other selections are shown as **BLOCKED** or **MANUAL** and will not be installed. `brew install --formula ...` is the only allowed package operation in this phase; Homebrew can download packages and modify its user-managed prefix. Always inspect the displayed command first, and do not run m³ as root or inside Distrobox. A failed installation is reported without any fallback to `sudo`, `rpm-ostree`, or `bootc`.

The tool install feature is an **early v0.2 preview**, not a general workstation provisioning engine. It intentionally does not update installed packages or manage Terraform, Podman, or Distrobox automatically. Automated tests use a fake `brew` binary and never install real software.

## Roadmap

- **v0.1:** Read-only system and tool checks
- **v0.2 (in progress):** Curated, confirmed Homebrew installation for Git, Go and kubectl; expand to safe configuration and additional tools after review
- **Future:** Bootable live environment with online and offline installation
- **Future:** Optional developer onboarding and documentation integrations

## Principles

Safe by default; explicit user consent before system changes; modular and reproducible configuration; no credentials in source code or logs.

## License

MIT. See [LICENSE](LICENSE).

This is an independent community project and is not affiliated with any Linux distribution vendor or hosting company.
