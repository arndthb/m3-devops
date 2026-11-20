# m³ DevOps · LoupixDeck CT integration

**Experimental, optional** control deck for Loupedeck CT on Fedora, using [LoupixDeck](https://github.com/RadiatorTwo/LoupixDeck).

## Features

- Five workspaces, **12 touch keys each**: Home, Docker, Kubernetes, Monitoring and Selfhosting.
- Docker / Compose inspection, Kubernetes cluster inspection, Helm lists, system status, Grafana / Loki Explore, GitHub, m³, terminal and VSCodium; configurable self-hosted dashboard shortcuts.
- No changes to containers or clusters; no install commands, sudo or remote code downloads.
- **CT centre wheel configured**: 2 round-screen modes per workspace, each split into four independently tappable quadrants, with original m³ text artwork. The six side dials and profile LED buttons remain at application defaults.

## Fedora setup

Install LoupixDeck separately. Clone this repository; while this pull request is open, switch to branch `feat/loupixdeck-ct-control-deck`:

```bash
git clone https://github.com/arndthb/m3-devops.git
cd m3-devops
git switch feat/loupixdeck-ct-control-deck
bash integrations/loupixdeck/install.sh
```

Next open **LoupixDeck → Settings → Profiles → Import** and choose `integrations/loupixdeck/profiles/m3-devops-ct.loupixprofile`. Activate **m³ DevOps** after reviewing the import dialog.

The profile needs the `$HOME/.local/bin/m3-deck` symlink created by `install.sh` to launch its local commands. The existing `m3` menu is optional and installed separately. Grafana links expect `http://localhost:3000` and do not install Grafana.

## CT centre wheel — v0.2

The central wheel is now an active controller, not just decoration. It follows the current workspace and shows **two wheel modes**:

- **NAV**: four quadrants open Docker / Kubernetes / Monitoring / Selfhosting.
- **TOOLS**: four context-sensitive read-only actions for the current workspace, e.g. Docker PS, Images, Stats, Info or Kubernetes Pods, Nodes, Events, Current Context.

Rotate the ring **left/right to move to the previous/next workspace** (LoupixDeck's built-in navigation commands). Swipe up/down on the wheel screen to open the wheel-mode menu, then select the mode you want. The quadrant layout uses the **Cross (+)** split (top-left, top-right, bottom-left, bottom-right) with a central m³ mark.

The wheel labels and actions are defined in `layout.json` and built into the portable profile by `build_profile.py`. No extra plugin is required for these static labels and actions. The wheel does **not** yet draw live CPU usage, Kubernetes metrics, LogQL timelines, or an attack-graph scrubber. That requires a separate data/renderer plugin and remains future work.

This feature requires a LoupixDeck build supporting CT wheel split-screen mode; see the [upstream wheel documentation](https://github.com/RadiatorTwo/LoupixDeck/blob/master/docs/CT_WHEEL_APPEARANCE.md). **Hardware behavior still needs testing** with a connected CT.

## Selfhosting shortcuts

Inspired by the [Self-Hosting LoupixDeck community profile by Rand0mB0y](https://github.com/RadiatorTwo/LoupixDeck.Profiles/tree/master/profiles/Rand0mB0y/selfhosting-win-lin). This layout is rebuilt for 12 CT touch keys; no graphics or scripts are copied.

A dedicated workspace offers Grafana, Karakeep, Prometheus, Alertmanager, Argo CD, Portainer, Dockge, Proxmox, TrueNAS, Homepage, GitHub and Home.

The installer creates **`~/.config/m3-devops/services.json`** from `services.example.json` only if absent. Edit the JSON with the URLs for services you actually run. Keep unused values empty.

```json
{
  "karakeep": "http://your-host.example:3002",
  "argocd": "https://argocd.your-lab.example"
}
```

The example above is abbreviated; retain the other keys in the generated file. No addresses or credentials are included in the public repository. Service shortcuts verify HTTP(S) URLs and use `xdg-open`, never string interpolation into a shell. An unset or invalid URL produces an error notification. Grafana remains pointed at the assumed local development endpoint `http://localhost:3000`.

## Rebuild and test

```bash
python3 integrations/loupixdeck/build_profile.py
python3 -m unittest discover -s integrations/loupixdeck/tests -v
bash -n integrations/loupixdeck/scripts/m3-deck.sh integrations/loupixdeck/install.sh
```

## Safety and limitations

All shell actions are in a fixed allowlist; the button cannot pass arbitrary shell text. Selfhosting addresses are read from a private local JSON file and opened through `xdg-open` after URL validation. Kubernetes read queries may contact your current remote cluster via your kubeconfig, so inspect the active context before running them. `docker info` and `helm list` are inspect-only operations; no destructive actions are included.

The package targets LoupixDeck portable format v1 and config schema v13. **Not hardware-tested or import-tested on a physical CT**; validate on Fedora before treating it as production-ready. The profile is not an application plugin and does not install software.

Format reference: [LoupixDeck portable packages](https://github.com/RadiatorTwo/LoupixDeck/blob/master/LoupixDeck/Models/Portable/ProfilePackageFiles.cs).
