# Getting Started

This guide walks you through installing Hecate and verifying that everything works.

## Prerequisites

- **Linux** (x86_64 or arm64) or **macOS** (arm64)
- **curl** and **git**
- **systemd** (for service management)
- **Ollama** (recommended for local LLM inference)

## Step 1: Install Hecate

```bash
curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh | bash
```

The installer will:
1. Detect your hardware (RAM, CPU, GPU, storage)
2. Ask you to select a node role (standalone, cluster, inference)
3. Optionally install Ollama and pull a model
4. Install podman, the daemon, and the reconciler
5. Optionally install the desktop app (hecate-web)

For headless servers:

```bash
curl -fsSL https://raw.githubusercontent.com/hecate-social/hecate-install/main/install.sh | bash -s -- --daemon-only
```

## Step 2: Verify the Daemon

```bash
# Check service status
hecate status

# Check daemon health
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/health

# Check node identity (auto-generated on first boot)
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/node/identity
```

Expected output:

```json
{
  "ok": true,
  "node_identity": {
    "mri": "mri:agent:io.macula/anonymous/hecate-a1b2",
    "public_key": "base64...",
    "realm": "io.macula",
    "initialized": true
  }
}
```

## Step 3: Install Ollama (if not done by installer)

```bash
curl -fsSL https://ollama.com/install.sh | sh
ollama pull llama3.2
```

Verify the daemon can see models:

```bash
curl --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock http://localhost/api/llm/models
```

## Step 4: (Optional) Install the Desktop App

Download from [GitHub Releases](https://github.com/hecate-social/hecate-web/releases), or if installed via `install.sh`:

```bash
hecate-web
```

The desktop app connects to the daemon via Unix socket and provides studios for LLM chat, node management, and DevOps workflows.

## Step 5: Pair with Macula Realm

Pairing links your daemon to a Macula realm account (via GitHub OAuth):

```bash
# Start pairing
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/pairing/initiate
```

This returns a URL — open it in your browser. The confirmation code is included in the URL for seamless auto-confirmation.

Or use the desktop app's Settings page to initiate pairing with one click.

## Step 6: (Optional) Set Up AI Personality

Clone the agents knowledge base:

```bash
git clone https://github.com/hecate-social/hecate-agents.git ~/.hecate/hecate-agents
```

This provides philosophy documents, skills, and guardrails that shape how AI assistants interact with your Hecate codebase.

## Daemon Logs

```bash
# View logs
hecate logs

# Or directly via journalctl
journalctl --user -u hecate-daemon -f
```

## Next Steps

- [Hecate Web](hecate-web.md) — learn the desktop app studios
- [Macula Mesh](macula-mesh.md) — connect to the mesh network
- [Daemon API](daemon-api.md) — explore the REST API
- [App Development](app-development.md) — build your own Hecate plugin
