# Getting Started

This guide walks you through installing Hecate and having your first conversation with an AI agent.

## Prerequisites

- **Ollama** (recommended) - For running local models
- **Docker** (optional) - For containerized daemon deployment
- **Go 1.21+** (optional) - For building TUI from source
- **Erlang/OTP 27+** (optional) - For building daemon from source

## Step 1: Install Ollama

Ollama provides the easiest path to running local LLMs.

```bash
# Linux
curl -fsSL https://ollama.com/install.sh | sh

# macOS
brew install ollama

# Start Ollama service
ollama serve
```

Pull a model to get started:

```bash
ollama pull llama3.2
```

## Step 2: Install the Daemon

### Option A: Docker (Recommended)

```bash
docker run -d \
  --name hecate-daemon \
  -v /run/hecate:/run/hecate \
  -v ~/.hecate:/var/lib/hecate \
  --network host \
  ghcr.io/hecate-social/hecate-daemon:latest
```

The daemon exposes a Unix socket at `/run/hecate/daemon.sock`.

### Option B: Build from Source

```bash
git clone https://github.com/hecate-social/hecate-daemon.git
cd hecate-daemon
rebar3 release
_build/default/rel/hecate/bin/hecate foreground
```

### Verify the Daemon

```bash
curl --unix-socket /run/hecate/daemon.sock http://localhost/api/health
# Expected: {"ok":true,"status":"healthy",...}

curl --unix-socket /run/hecate/daemon.sock http://localhost/api/llm/models
# Expected: {"ok":true,"models":[...]}
```

## Step 3: Install the TUI

### Option A: Download Release

```bash
# Linux amd64
curl -LO https://github.com/hecate-social/hecate-tui/releases/latest/download/hecate-tui-linux-amd64.tar.gz
tar xzf hecate-tui-linux-amd64.tar.gz
sudo mv hecate-tui /usr/local/bin/

# macOS arm64
curl -LO https://github.com/hecate-social/hecate-tui/releases/latest/download/hecate-tui-darwin-arm64.tar.gz
tar xzf hecate-tui-darwin-arm64.tar.gz
sudo mv hecate-tui /usr/local/bin/
```

### Option B: Build from Source

```bash
git clone https://github.com/hecate-social/hecate-tui.git
cd hecate-tui
go build -o hecate-tui ./cmd/hecate-tui
sudo mv hecate-tui /usr/local/bin/
```

## Step 4: Configure the TUI

Create the configuration file:

```bash
mkdir -p ~/.config/hecate-tui
cat > ~/.config/hecate-tui/config.toml << 'EOF'
[daemon]
socket_path = "/run/hecate/daemon.sock"

[ui]
theme = "dark"
EOF
```

## Step 5: Start Chatting

Launch the TUI:

```bash
hecate-tui
```

You'll see a terminal interface with:
- Status bar at the top (daemon status, model name)
- Chat area in the middle
- Input field at the bottom
- Hints bar showing available commands

### Basic Interaction

1. Press `i` to enter **Insert mode**
2. Type your message
3. Press `Enter` to send
4. Press `Esc` to return to **Normal mode**

### Switch Models

Press `Tab` to cycle through available models, or use the command:

```
/models
```

### Get Help

```
/help
```

## Step 6: (Optional) Set Up Personality

Clone the agents repository for custom personalities:

```bash
git clone https://github.com/hecate-social/hecate-agents.git ~/hecate-agents
```

Update your config:

```toml
[personality]
personality_file = "~/hecate-agents/PERSONALITY.md"
roles_dir = "~/hecate-agents/philosophy"
active_role = "dna"
```

Now your agent will respond with the configured personality.

## Next Steps

- [TUI Usage](tui-usage.md) - Learn all commands and shortcuts
- [Daemon API](daemon-api.md) - Explore the REST API
- [Personality System](personality-system.md) - Customize your agent
