# Deployment Guide

Hecate runs as **rootless Podman containers** managed by **systemd user services**. No Kubernetes, no Docker, no root at runtime.

## Overview

```
~/.hecate/gitops/           ← Source of truth (Quadlet .container files)
    ↓ reconciler watches
~/.config/containers/systemd/  ← Podman Quadlet picks up symlinks
    ↓ systemctl --user daemon-reload
systemd user services          ← Containers run as user services
```

1. CI/CD builds OCI images and pushes to ghcr.io (`:latest` + semver tags)
2. Quadlet `.container` files in `~/.hecate/gitops/` define what runs on each node
3. The reconciler watches gitops and symlinks Quadlet files to systemd
4. `podman auto-update` pulls new `:latest` images automatically

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh | bash
```

This installs podman, the daemon, the reconciler, and optionally the desktop app and Ollama. See [hecate-install](https://github.com/hecate-social/hecate-install) for details.

## Directory Layout

| Path | Contents |
|------|----------|
| `~/.hecate/` | Data root |
| `~/.hecate/hecate-daemon/` | Daemon data (sqlite, reckon-db, sockets) |
| `~/.hecate/gitops/system/` | Core Quadlet files (daemon, reconciler) |
| `~/.hecate/gitops/apps/` | Plugin Quadlet files (installed on demand) |
| `~/.hecate/secrets/` | LLM API keys (sops + age encrypted) |
| `~/.local/bin/hecate` | CLI wrapper |
| `~/.local/bin/hecate-reconciler` | GitOps reconciler |
| `~/.config/containers/systemd/` | Podman Quadlet units (symlinks) |

## Quadlet Container Files

A Quadlet `.container` file is a declarative container definition:

```ini
# ~/.hecate/gitops/system/hecate-daemon.container
[Unit]
Description=Hecate Daemon

[Container]
Image=ghcr.io/hecate-social/hecate-daemon:latest
AutoUpdate=registry
Network=host

Volume=%h/.hecate/hecate-daemon:/home/hecate/.hecate/hecate-daemon:Z
Volume=%h/.hecate/secrets:/home/hecate/.hecate/secrets:ro,Z

Environment=HOME=%h
Environment=HECATE_HOSTNAME=%H
Environment=HECATE_USER=%u

[Service]
Restart=always

[Install]
WantedBy=default.target
```

Key features:
- `AutoUpdate=registry` — `podman auto-update` pulls new `:latest` images
- `%H` / `%u` — systemd specifiers inject host hostname and user into container
- `Network=host` — daemon binds directly to host network for BEAM clustering and Ollama access
- No root needed — containers run as user-level systemd services

## The Reconciler

The reconciler is a filesystem watcher that manages the lifecycle of Quadlet units:

1. Watches `~/.hecate/gitops/system/` and `~/.hecate/gitops/apps/`
2. When a `.container` file is added → symlinks to `~/.config/containers/systemd/` → `daemon-reload` → starts service
3. When removed → stops service → removes symlink → `daemon-reload`

```bash
# Check desired vs actual state
hecate-reconciler --status

# Manual reconciliation
hecate reconcile
```

## Installing Plugins

Drop a Quadlet file into `~/.hecate/gitops/apps/`:

```bash
cp hecate-marthad.container ~/.hecate/gitops/apps/
# Reconciler picks it up automatically
```

## Managing Services

```bash
# CLI wrapper
hecate status                    # Show all hecate services
hecate start                     # Start daemon
hecate stop                      # Stop daemon
hecate restart                   # Restart daemon
hecate logs                      # View daemon logs
hecate health                    # Check daemon health
hecate update                    # Pull latest container images

# Direct systemd
systemctl --user list-units 'hecate-*'
systemctl --user status hecate-daemon
journalctl --user -u hecate-daemon -f
```

## Updating

Updates happen automatically via `podman auto-update`:

1. CI pushes new `:latest` image to ghcr.io
2. `podman auto-update` detects the new digest
3. Container restarts with the new image

For manual updates:

```bash
hecate update
```

## Rolling Back

Pin a `.container` file to a specific version:

```ini
# Change from :latest to a specific version
Image=ghcr.io/hecate-social/hecate-daemon:0.11.2
```

After the fix ships, revert to `:latest`.

## Multi-Node Deployment

For clusters (beam00-03), use Ansible:

```bash
cd hecate-install/ansible
ansible-playbook -i inventory.ini hecate.yml
```

See [ansible/README.md](https://github.com/hecate-social/hecate-install/tree/main/ansible) for variables and examples.

## NixOS

For bootable USB/ISO images:

```bash
cd hecate-install
nix build .#iso
```

See [hecate-install](https://github.com/hecate-social/hecate-install) for NixOS flake details.

## Troubleshooting

### Daemon Not Starting

```bash
systemctl --user status hecate-daemon
journalctl --user -u hecate-daemon -n 50
podman ps -a
```

### Socket Not Created

```bash
ls -la ~/.hecate/hecate-daemon/sockets/
```

### Container Image Not Pulling

```bash
podman pull ghcr.io/hecate-social/hecate-daemon:latest
```

### Wrong Hostname/User in Settings

Check that `HECATE_HOSTNAME` and `HECATE_USER` are set in the `.container` file:

```bash
grep HECATE_ ~/.hecate/gitops/system/hecate-daemon.container
```

### User Lingering Not Enabled

Services won't persist after logout without lingering:

```bash
loginctl enable-linger $USER
```
