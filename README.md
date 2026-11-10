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

## Roadmap

- **v0.1:** Read-only system and tool checks
- **v0.2:** Optional, confirmed installation and configuration, with Bluefin-friendly methods
- **Future:** Bootable live environment with online and offline installation
- **Future:** Optional developer onboarding and documentation integrations

## Principles

Safe by default; explicit user consent before system changes; modular and reproducible configuration; no credentials in source code or logs.

## License

MIT. See [LICENSE](LICENSE).

This is an independent community project and is not affiliated with any Linux distribution vendor or hosting company.
