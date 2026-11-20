# m³ DevOps · LoupixDeck CT integration

**Experimental, optional** control deck for Loupedeck CT on Fedora, using [LoupixDeck](https://github.com/RadiatorTwo/LoupixDeck).

## Features

- Four workspaces, **12 touch keys each**: Home, Docker, Kubernetes, Monitoring.
- Docker / Compose inspection, Kubernetes cluster inspection, Helm lists, system status, Grafana / Loki Explore, GitHub, m³, terminal and VSCodium.
- No changes to containers or clusters; no install commands, sudo or remote code downloads.
- CT wheel, rotary dials and physical buttons are deliberately left at LoupixDeck defaults until tested on hardware.

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

## Rebuild and test

```bash
python3 integrations/loupixdeck/build_profile.py
python3 -m unittest discover -s integrations/loupixdeck/tests -v
bash -n integrations/loupixdeck/scripts/m3-deck.sh integrations/loupixdeck/install.sh
```

## Safety and limitations

All shell actions are in a fixed allowlist; the button cannot pass arbitrary shell text. Kubernetes read queries may contact your current remote cluster via your kubeconfig, so inspect the active context before running them. `docker info` and `helm list` are inspect-only operations; no destructive actions are included.

The package targets LoupixDeck portable format v1 and config schema v13. **Not hardware-tested or import-tested on a physical CT**; validate on Fedora before treating it as production-ready. The profile is not an application plugin and does not install software.

Format reference: [LoupixDeck portable packages](https://github.com/RadiatorTwo/LoupixDeck/blob/master/LoupixDeck/Models/Portable/ProfilePackageFiles.cs).
