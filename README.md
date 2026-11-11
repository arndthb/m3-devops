# m³ – DevOps Workstation for Fedora

**BUILD · RUN · SHIP**

m³ is a terminal-based DevOps workstation setup and management tool, focused on **Fedora Workstation**. It provides system diagnostics, a tool installer, workstation readiness checks, project discovery, container inspection and self-updates.

## System requirements

- **Operating system:** Fedora Workstation (standard, mutable installation with **DNF**). Fedora 45 is the current development/test target. Other Fedora releases may work, but are not automatically guaranteed.
- **Architecture:** x86_64 is the primary target. Some installers also support aarch64; availability varies by tool.
- **Terminal:** A terminal with ANSI escape sequences and UTF-8 support. **JetBrainsMono Nerd Font Mono** is recommended for the icon mode.
- **Shell:** Bash.
- **Base utilities:** Git, curl, standard GNU/Linux utilities and a working internet connection for downloads and updates.
- **Permissions:** Run m³ as your **normal user**, not as root. Selected Fedora package installations may request sudo authentication.
- **Storage:** Enough free disk space for the selected tools, container images and development projects; requirements depend on your workload.
- **Containers:** Docker Engine or Podman as appropriate. Installing a CLI does not guarantee its daemon or engine is running.

**Not supported as a provisioning target:** immutable Fedora images (rpm-ostree/bootc), running m³ inside Distrobox/another container, and installations without a supported host package manager. This repository is **not** a Bluefin-specific setup guide.

## Installation

Open a terminal on Fedora Workstation:

```bash
sudo dnf install -y git curl
git clone https://github.com/arndthb/m3-devops.git
cd m3-devops
bash scripts/install-launcher.sh
```

Start the app:

```bash
m3
```

If `m3` is not found, open a new terminal and make sure `~/.local/bin` is in your `PATH`. Alternatively, run `bash scripts/m3.sh` from the repository directory.

If you already cloned the repository:

```bash
cd ~/m3-devops
git pull --ff-only origin main
bash scripts/install-launcher.sh
```

## Main menu

| Menu | Purpose |
| --- | --- |
| System diagnostics | Inspect Fedora, hardware and development tool availability |
| Workstation health check | Inspect CPU, memory, disk, network and selected development services |
| DevOps Tool Manager | Detect, select and install supported development tools |
| DevOps Project Manager | Browse local Git and Compose projects |
| Container Manager | Inspect Podman containers, images, networks, volumes and disk usage |
| Hermes Agent | Start Hermes directly from the home screen when installed |
| Codex CLI | Start Codex interactively from the home screen when installed |
| VSCodium | Open VSCodium from the home screen when installed |
| ChatGPT Desktop | Open the desktop application when installed and a launcher is available |
| Update m³ | Update the local checkout from `origin/main` |
| Settings | Choose classic markers or Nerd Font icons; offer font installation when missing |
| Info | Project information |

## DevOps Tool Manager

Use **↑/↓** to navigate and **Space** to select missing tools. Choose **Install selected** to start installing supported selections. You **do not need to type `INSTALL`** in the Tool Manager. Package-manager commands use noninteractive approval flags where supported, but sudo authentication and third-party installers may still prompt.

- **READY:** m³ has an installation recipe for the detected host.
- **MANUAL:** The tool is recognized, but an automated installation recipe is not available for this host.
- **BLOCKED:** The current environment does not meet installation requirements.
- **Installed:** The tool was detected; this does not necessarily mean it is configured, authenticated or ready to run.

The catalog includes Git, Podman, Distrobox, kubectl, Go, Terraform, VSCodium, Hermes Agent, Codex CLI, ChatGPT Desktop, Docker, Compose, kind, make, curl and JetBrainsMono Nerd Font.

### Fedora installation methods

| Tool | Installation / notes |
| --- | --- |
| Git, Go, kubectl, Distrobox | Fedora DNF packages where supported |
| Docker Engine and Compose | Docker's Fedora repository and packages; engine health checked separately |
| Terraform | Official HashiCorp release ZIP, SHA-256 checked, installed to `~/.local/bin` |
| VSCodium | Flathub Flatpak (`com.vscodium.codium`) |
| kind | `go install` into `~/.local/bin`; Go and a container provider required |
| Hermes Agent | Official Nous Research installer; requires subsequent provider setup |
| Codex CLI | Official OpenAI installer; sign in separately with ChatGPT |
| ChatGPT Desktop | Detected and listed; installation remains manual until an RPM compatible with the Fedora release is confirmed |
| JetBrainsMono Nerd Font | Installed in the user's font directory; select the font in terminal preferences |
| Podman, make, curl | Detected; installation availability depends on the current approved recipe |

A failed installation stops the remaining selected operations. Installation does not automatically configure cloud credentials, logins or Kubernetes clusters.

### Docker and Kubernetes

Docker CLI, Docker daemon, Docker Compose and Podman are checked separately. A successful `docker --version` does **not** prove the Docker daemon is reachable.

For a rootless Podman setup, kind can be launched manually after the provider is configured:

```bash
KIND_EXPERIMENTAL_PROVIDER=podman kind create cluster --name m3-test --wait 90s
```

See the [kind rootless documentation](https://kind.sigs.k8s.io/docs/user/rootless/). Do not assume Docker and Podman are interchangeable without provider-specific configuration.

### Nerd Font icons

In **Settings**, choose **Nerd Font icons**. m³ checks whether JetBrainsMono Nerd Font is installed and offers installation if needed. **Installing a font does not automatically select it in the terminal profile**: set **JetBrainsMono Nerd Font Mono** in your terminal's font preferences. Classic markers remain available.

## Project Manager

m³ discovers local Git and Compose projects in common development directories. Browse with ↑/↓ and Enter; use **/** to search, **F** to filter, **C** to clear, and **R** to rescan. Project browsing is read-only.

## Updating m³

Choose **Update m³** from the main menu, or run:

```bash
m3 update
```

Updates use `git pull --ff-only origin main` and will not overwrite local modifications or force a divergent branch. The running menu reloads after a successful update.

## Diagnostics without installation

```bash
bash scripts/check-system.sh
```

This command reports tool availability without installing software.

## Security and limitations

m³ is an **experimental** workstation tool, not an unattended fleet provisioning solution. Some installers download and execute upstream scripts; use only sources you trust and review changes before running them. A successful installation is not proof of a healthy service. Do not put API keys, tokens or passwords in the repository.

## Roadmap

- Fedora-first installer validation and automated shell checks
- More reliable terminal rendering across window sizes
- Expanded tool installation and readiness checks
- Optional developer onboarding and documentation integrations

## License

MIT. See [LICENSE](LICENSE).

Independent community project; not affiliated with Fedora, Red Hat, OpenAI, HashiCorp or other vendors.
