# Hecate Web Guide

Hecate Web is a **native desktop application** for interacting with the Hecate Daemon. Built with Tauri v2 (Rust) and SvelteKit (TypeScript/Svelte 5), it provides a rich graphical interface for venture lifecycle management, event storming, and AI-assisted development.

**Not a browser. Not Electron.** Tauri uses your system webview (webkit2gtk on Linux), keeping the binary small and memory efficient.

## Architecture

```
 Tauri Shell (native window)
   └── SvelteKit App (static HTML/JS/CSS)
        └── hecate:// custom protocol handler
             └── Rust socket proxy (src-tauri/src/socket_proxy.rs)
                  └── Unix socket → hecate-daemon (Cowboy HTTP on /run/hecate/daemon.sock)
```

### Key Design Decisions

1. **Zero daemon web serving** -- The daemon serves zero assets. All frontend code is bundled by Tauri.
2. **Custom protocol proxying** -- API calls go through `hecate://localhost/path`, which Tauri's Rust backend proxies to the daemon's Unix socket.
3. **SSE streaming via Tauri events** -- LLM chat streaming uses Tauri's event system for real-time chunk delivery, not the custom protocol.
4. **Same daemon, two frontends** -- Hecate Web and Hecate TUI both connect to the same daemon over the same Unix socket. They can run simultaneously.

## Studios

Hecate Web organizes functionality into **studios** -- focused workspaces for different tasks.

### LLM Studio

Chat with AI models through streaming responses. Supports Ollama (local), OpenAI, Anthropic, and Google providers.

- Real-time token-by-token streaming
- Model selector with provider health indicators
- Token usage tracking
- System prompt injection via the personality system
- Tool/function calling support (when model supports it)

### Node Dashboard

Monitor daemon health and system status.

- Daemon health and uptime
- Node identity (node_id, display_name, realm)
- LLM provider status with health checks
- Model inventory

### DevOps Studio

Venture lifecycle management and event storming workflows.

- **Venture management** -- Create, view, and track ventures
- **Division tracking** -- Bounded contexts identified through event storming
- **Phase progress** -- DnA, AnP, TnI, DnO phase tracking per division
- **Big Picture Event Storming** -- Full 7-phase event storming workflow:
  - Storm (brainstorm stickies)
  - Stack (group duplicates)
  - Groom (pick canonical names)
  - Cluster (group related events)
  - Name (assign business names)
  - Map (draw fact arrows between clusters)
  - Promote (graduate clusters to divisions)
- **AI Assist Panel** -- Phase-aware AI assistance with model affinity
- **Event Stream Viewer** -- Raw event history from ReckonDB

### Social Studio (planned)

Community chat and collaboration features.

### Arcade Studio (planned)

Games and entertainment.

## How It Connects to the Daemon

### Request Flow

All API calls follow this path:

```
SvelteKit fetch('hecate://localhost/api/ventures')
  → Tauri custom protocol handler (lib.rs)
    → socket_proxy.rs builds HTTP/1.1 request
      → writes to /run/hecate/daemon.sock
        → daemon processes request
      → reads response from socket
    → returns response to webview
  → SvelteKit receives JSON
```

### Streaming Flow (LLM Chat)

Chat uses a different path for real-time streaming:

```
SvelteKit invoke('chat_stream', { model, messages })
  → Tauri command handler (streaming.rs)
    → spawns async task
      → connects to /run/hecate/daemon.sock
      → POST /api/llm/chat with Accept: text/event-stream
      → reads SSE chunks from socket
      → emits Tauri events: chat-chunk-{id}, chat-done-{id}, chat-error-{id}
    → SvelteKit listens on event listeners
      → accumulates text in real-time
      → renders streaming content with cursor animation
```

### API Surface

| Endpoint | Purpose | Method |
|----------|---------|--------|
| `/health` | Daemon health and uptime | GET |
| `/api/llm/models` | Available LLM models | GET |
| `/api/llm/health` | LLM provider status | GET |
| `/api/llm/chat` | Chat completion with streaming | POST |
| `/api/identity` | Node identity info | GET |
| `/api/ventures` | All ventures | GET |
| `/api/ventures/:id/divisions` | Divisions for a venture | GET |
| `/api/ventures/:id/storm/state` | Event storming state | GET |
| `/api/ventures/:id/storm/*` | Storm commands (POST) | POST |
| `/api/ventures/:id/events` | Raw event stream | GET |

## Project Structure

```
hecate-web/
  src/
    routes/                    SvelteKit pages
      +layout.svelte           Root layout (studio tabs)
      +page.svelte             Home / studio selector
      llm/+page.svelte         LLM Studio
      node/+page.svelte        Node Dashboard
      devops/+page.svelte      DevOps Studio
      social/+page.svelte      Social Studio (placeholder)
      arcade/+page.svelte      Arcade Studio (placeholder)

    lib/
      api.ts                   REST client (hecate:// fetch wrapper)
      types.ts                 TypeScript interfaces for daemon API
      context.ts               StudioContext (shared contract for studios)
      stores/
        daemon.ts              Health, connection state, polling
        llm.ts                 Chat history, models, streaming
        node.ts                Identity, providers
        devops.ts              Ventures, divisions, phases, event storming
        personality.ts         Personality system (roles, prompts)
      components/
        StudioTabs.svelte      Tab switcher
        ChatMessage.svelte     Chat bubble component
        StreamingText.svelte   Real-time text display
        StatusBar.svelte       Status indicator
        devops/                DevOps-specific components
          BigPictureBoard.svelte
          EventStreamViewer.svelte
          AIAssistPanel.svelte
          ...

  src-tauri/                   Rust backend
    src/
      main.rs                  Entry point
      lib.rs                   Tauri setup, protocol handlers
      socket_proxy.rs          Unix socket HTTP proxy
      streaming.rs             SSE streaming handler
      personality.rs           Personality system (reads config files)
```

## Building and Running

### Requirements

- Rust 1.70+ (for Tauri)
- Node.js 20+ (for SvelteKit)
- Linux with webkit2gtk (system webview)
- Hecate daemon running at `/run/hecate/daemon.sock`

### Development

```bash
cd hecate-web
npm install
cargo tauri dev     # Starts SvelteKit dev server + opens native window
```

Hot reload is supported -- changes to Svelte files update instantly.

### Production Build

```bash
cargo tauri build   # Produces hecate.AppImage or hecate binary
```

The output is a standalone native application.

## Personality System

Hecate Web integrates the same personality system as the TUI. The Rust backend reads:

- **PERSONALITY.md** -- Goddess traits (from `~/.config/hecate-tui/config.toml`)
- **Active role** -- DnA, AnP, TnI, or DnO phase personality

The system prompt is injected into every LLM chat message, combining personality traits with the current phase context and venture/division information.

## Phase-Aware Model Selection

The DevOps studio AI Assist panel automatically recommends models based on the current ALC phase:

| Phase | Affinity | Preferred Models |
|-------|----------|------------------|
| DnA | general | Any capable model |
| AnP | general | Any capable model |
| TnI | code | Code-optimized models (e.g., codellama, deepseek-coder) |
| DnO | general | Any capable model |

Users can override model selection per-phase and pin preferences to localStorage.

## Relationship to Other Components

| Component | Relationship |
|-----------|-------------|
| **hecate-daemon** | Backend -- all data and logic lives here |
| **hecate-tui** | Sibling frontend -- same daemon, different UI |
| **hecate-agents** | Personality files loaded by Tauri's Rust backend |
| **hecate-gitops** | Deploys the daemon (Web runs locally, not deployed) |
