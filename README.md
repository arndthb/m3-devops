# m³ – Linux Workstation Automation

**A lightweight, modular toolkit for Linux DevOps workstations.**

m³ aims to inspect and eventually automate DevOps workstation setup. The initial focus is [Bluefin](https://projectbluefin.io/), with other Linux distributions planned.

## v0.1 – Read-only diagnostics

The diagnostics check the Linux distribution and detect Git, Podman, Distrobox, kubectl, Go, Terraform, VSCodium, Hermes, Docker CLI, Compose, kind, make, and curl. It reports missing tools without installing software or changing configuration.

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
- **DevOps Tool Manager:** inspect installed tools, select missing tools with **Space**, then press **Enter** to review exactly which Homebrew commands are approved. Nothing is installed unless you type the case-sensitive word **INSTALL**. On a Bluefin host with Homebrew, m³ initially supports installing **Git**, **Go**, **kubectl** (`kubernetes-cli`), **Terraform** (`hashicorp/tap/terraform`) and **kind** (`kind`); **Podman** and **Distrobox** remain manual-review only. The menu also **detects VSCodium, Hermes, Docker, Compose, kind, make and curl**, but does **not** automatically install those additional tools except **kind**, which now uses Homebrew after confirmation. The separate **Automatic installation preview** is strictly read-only. Installation is refused as root, from Distrobox/a detected container, or without Homebrew. No sudo, OS-image changes, or unattended installation are performed.
- **Container Manager:** browse Podman containers, images, volumes, networks, and disk usage without making changes. The menu uses the same highlighted selection and adaptive spacing as the main menu. Automatically generated hexadecimal volume IDs are shortened and labeled; use `podman volume inspect <volume-name>` for full metadata.
- **DevOps Project Manager:** discover local Git and Compose projects, browse with ↑/↓, and open details with Enter.
- **Update m³ / Check Updates:** fetch the latest `origin/main` revision, display the installed and available Git commit IDs (the project does not yet publish separate semantic version numbers), and offer to install an available update with explicit confirmation. Installation is fast-forward only and is refused if local changes exist or branches have diverged. When already current, or after a successful/skipped update, a visible 3–2–1 countdown returns to the main menu. The running menu reloads itself after a successful update to use the new code.
- **Settings and information:** view available configuration and project information.

### Bluefin workstation tool detection

The **DevOps Tool Manager** lists 13 development components, with paging on smaller terminals. Use **↑/↓** to browse, **Space** to select missing components, and **Enter** to review. It reports tools available in the *current environment*, not in every Distrobox.

- **VSCodium**: detected via the `codium` command or the Flatpak ID `com.vscodium.codium`.
- **Hermes**: detected via `hermes`, `hermes-agent`, or an executable `~/.local/bin/hermes`. Detection alone does not validate login or provider configuration.
- **Docker**: the `docker` command is checked independently. Its presence does not prove the Docker daemon is running.
- **Compose**: checks `docker compose version`, then standalone `docker-compose` or `podman-compose`. Compose does not imply a working Docker engine.
- **kind**: checks the `kind` command; creating a cluster still requires a working container provider.
- **make**, **curl**, **git**, **Go** and **kubectl**: checks command availability on the current PATH.

**Bluefin ships with Podman-centric workflows**; m³ does not assume Docker Desktop is required on Linux or replace Podman with Docker. For the original macOS/Windows setup, Docker Desktop with Compose should have at least **6 GiB RAM** allocated. On Bluefin, configure the kind provider separately and verify it with an actual cluster test.

Installation remains restricted to the reviewed Homebrew allowlist (Git, Go, kubectl, Terraform) and requires the exact confirmation `INSTALL`. VSCodium, Hermes, Docker, Compose, kind, make and curl are *detection-only* until suitable Bluefin-safe installation methods are reviewed. No privileged operating-system changes occur.

### Workstation readiness (Bluefin)

From **DevOps Tool Manager**, choose **Workstation readiness** to run local, read-only preflight checks for VSCodium, Hermes, Podman, Docker, Compose, kind, kubectl and cgroup v2. The check distinguishes an installed Docker CLI from a reachable Docker daemon; it likewise verifies Podman's engine availability without creating any containers. Hermes detection does not confirm authentication or a configured model.

**kind installation:** Select the missing **kind** entry with Space, press Enter to review `brew install --formula kind` and type exactly `INSTALL` to approve it. This is supported by Homebrew on Linux. Installing kind **does not automatically configure or launch a Kubernetes cluster**.

For an available Podman engine, the readiness screen *suggests* the explicit command below (it never executes it):

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name m3-test --wait 90s
```

Before attempting this manually, ensure that rootless Podman is set up with cgroup v2 and appropriate user service delegation. See the [kind rootless instructions](https://kind.sigs.k8s.io/docs/user/rootless/) and [Bluefin Developer Mode](https://docs.projectbluefin.io/bluefin-dx/). Docker Desktop is not required for this Bluefin/Podman workflow; Linux Docker Engine and Compose are separate optional alternatives. m³ does not install or activate Docker, edit systemd services, download Hermes, or change the operating-system image.

### DevOps Project Manager

The project manager searches common directories (`~/Projects`, `~/projects`, `~/Developer`, `~/Code`, `~/Documents/DevOps`, and `~`) up to two directory levels deep. It recognizes Git repositories and projects with `compose.yaml`, `compose.yml`, `docker-compose.yml`, or `docker-compose.yaml`. Backup-like directory names are excluded.

The project browser shows the name, Git branch/status, and Compose file in a **paged list**, limited to the terminal's visible height. An asterisk (`*`) indicates local Git changes (including untracked files); `?` indicates unavailable status. A selected project's **scrollable details** include its full path, branch, origin, up to three recent commits, a short working-tree status, the Compose file and top-level entries.

Use **↑/↓** to select a project, **Enter** to open details, **Enter** again to return to the list, and **Esc** to return to the main menu. Press **/** to search project names and paths, **F** to cycle through *All / Git / Compose / Changed*, **C** to clear the search, or **R** to rescan the filesystem. Empty results remain interactive so you can adjust the filter. The project manager is **read-only**: it does not modify repositories, install tools, or start containers. Git status is a snapshot from the last scan, not continuous monitoring.

Menu rendering helpers for Project Manager and Container Manager are shared in `scripts/lib/ui.sh`; this keeps their headers, colors, and selection rows consistent. The other menus will be migrated separately.

### Confirmed tool installation (experimental)

Use **m3 → DevOps Tool Manager → Space** to select one or more missing tools and **Enter** to review the proposed actions. Only tools shown as **READY** will be installed after you explicitly type `INSTALL` and press Enter. Other selections are shown as **BLOCKED** or **MANUAL** and will not be installed. `brew install --formula ...` is the only allowed package operation in this phase; Homebrew can download packages and modify its user-managed prefix. Always inspect the displayed command first, and do not run m³ as root or inside Distrobox. A failed installation is reported without any fallback to `sudo`, `rpm-ostree`, or `bootc`. An installation failure immediately stops the remaining selected tools, rather than silently continuing. The exact `INSTALL` confirmation is also checked inside the installer function itself.

The tool install feature is an **early v0.2 preview**, not a general workstation provisioning engine. It intentionally does not update installed packages or manage Podman or Distrobox automatically. Terraform installation first runs `brew tap hashicorp/tap`, followed by `brew install --formula hashicorp/tap/terraform` after the same explicit `INSTALL` confirmation. If adding the tap fails, the formula is not installed. Automated tests use a fake `brew` binary and never install real software.

## Roadmap

- **v0.1:** Read-only system and tool checks
- **v0.2 (in progress):** Curated, confirmed Homebrew installation for Git, Go, kubectl and Terraform; expand to safe configuration and additional tools after review
- **Future:** Bootable live environment with online and offline installation
- **Future:** Optional developer onboarding and documentation integrations

## Principles

Safe by default; explicit user consent before system changes; modular and reproducible configuration; no credentials in source code or logs.

## License

MIT. See [LICENSE](LICENSE).

This is an independent community project and is not affiliated with any Linux distribution vendor or hosting company.
