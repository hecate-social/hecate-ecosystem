# Architecture

This guide explains how the Hecate components work together to provide a local-first AI agent platform.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                           User Terminal                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    Hecate TUI (Go)                           │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────┐ │    │
│  │  │ Normal  │  │ Insert  │  │ Command │  │   Personality   │ │    │
│  │  │  Mode   │  │  Mode   │  │  Mode   │  │     Loader      │ │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────────────┘ │    │
│  └────────────────────────────┬────────────────────────────────┘    │
│                               │ Unix Socket                          │
│                               ▼                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                 Hecate Daemon (Erlang/OTP)                   │    │
│  │                                                               │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │    │
│  │  │  HTTP API   │  │   LLM       │  │    Event Store      │  │    │
│  │  │  (Cowboy)   │  │  Routing    │  │    (ReckonDB)       │  │    │
│  │  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │    │
│  │         │                │                     │             │    │
│  │         ▼                ▼                     ▼             │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │    │
│  │  │   Router    │  │  Providers  │  │   Read Models       │  │    │
│  │  │             │  │  ┌───────┐  │  │    (SQLite)         │  │    │
│  │  │  /api/llm/* │  │  │Ollama │  │  │                     │  │    │
│  │  │  /api/cart* │  │  │OpenAI │  │  │  - Cartwheels       │  │    │
│  │  │  /api/mesh* │  │  │Claude │  │  │  - Torches          │  │    │
│  │  └─────────────┘  │  │Google │  │  │  - Mentors          │  │    │
│  │                   │  └───────┘  │  └─────────────────────┘  │    │
│  │                   └──────┬──────┘                            │    │
│  │                          │                                    │    │
│  │  ┌───────────────────────┴───────────────────────────────┐  │    │
│  │  │                   Macula Mesh                          │  │    │
│  │  │           (HTTP/3 over QUIC, DHT, PubSub)             │  │    │
│  │  └───────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Details

### Hecate TUI

The terminal interface is built with Go and the Bubble Tea framework.

**Responsibilities:**
- Render chat interface with markdown support
- Handle vim-style modal input (Normal, Insert, Command modes)
- Load and inject personality/role into system prompts
- Stream responses from daemon with real-time display
- Manage model selection and provider status display

**Key Packages:**
- `internal/ui/` - Bubble Tea models and views
- `internal/commands/` - Slash command handlers
- `internal/client/` - Daemon API client
- `internal/personality/` - Personality file loader

### Hecate Daemon

The daemon is an Erlang/OTP umbrella application.

**Umbrella Apps:**

| App | Purpose |
|-----|---------|
| `hecate_api` | Cowboy HTTP handlers, routing |
| `hecate_mesh` | Macula mesh integration |
| `serve_llm` | LLM provider abstraction |
| `manage_providers` | Provider configuration, health |
| `manage_cartwheels` | Project lifecycle (commands) |
| `query_cartwheels` | Project read models (queries) |
| `query_torches` | Torch read models |
| `query_mentors` | Mentor read models |

**CQRS Architecture:**

The daemon follows Command Query Responsibility Segregation:

```
Commands (Write Side)              Queries (Read Side)
─────────────────────              ──────────────────
manage_cartwheels                  query_cartwheels
  ├── initiate_cartwheel/            ├── query_cartwheels_store.erl (SQLite)
  │   ├── initiate_cartwheel_v1.erl  └── list_cartwheels.erl
  │   ├── cartwheel_initiated_v1.erl
  │   └── maybe_initiate_cartwheel.erl
  └── alc_aggregate.erl
```

- **Commands** produce events stored in ReckonDB
- **Projections** consume events and update SQLite read models
- **Queries** read directly from SQLite for fast retrieval

### LLM Provider System

The daemon supports multiple LLM providers through a behaviour-based abstraction.

**Provider Behaviour:**

```erlang
-callback list_models(Config) -> {ok, [Model]} | {error, Reason}.
-callback chat(Config, Messages, Options) -> {ok, Response} | {error, Reason}.
-callback chat_stream(Config, Messages, Options, Callback) -> ok | {error, Reason}.
-callback health(Config) -> ok | {error, Reason}.
```

**Supported Providers:**

| Provider | Module | Auto-Detection |
|----------|--------|----------------|
| Ollama | `ollama_provider` | Always (localhost:11434) |
| OpenAI | `openai_provider` | `OPENAI_API_KEY` env var |
| Anthropic | `anthropic_provider` | `ANTHROPIC_API_KEY` env var |
| Google | `google_provider` | `GOOGLE_API_KEY` env var |

**Model Routing:**

When a chat request arrives, the daemon:
1. Looks up which provider owns the requested model
2. Routes the request to that provider
3. Streams the response back to the caller

### Event Sourcing

The daemon uses event sourcing for all stateful operations.

**Event Flow:**

```
Command → Handler → Events → Event Store → Projections → Read Model
```

**Example: Creating a Cartwheel**

1. TUI sends `POST /api/cartwheels` with project data
2. API handler creates `initiate_cartwheel_v1` command
3. `maybe_initiate_cartwheel` validates and returns `cartwheel_initiated_v1` event
4. Event is stored in ReckonDB
5. Projection updates SQLite read model
6. Subsequent queries read from SQLite

### Mesh Integration

The daemon connects to the Macula mesh for peer-to-peer communication.

**Capabilities:**
- **Discovery** - Find other Hecate instances via DHT
- **PubSub** - Subscribe to events from other agents
- **RPC** - Call procedures on remote agents
- **Capabilities** - Advertise and discover agent capabilities

**Current Status:** Basic integration complete, advanced features in development.

## Data Storage

| Store | Technology | Purpose |
|-------|------------|---------|
| Event Store | ReckonDB (embedded) | Immutable event log |
| Read Models | SQLite | Fast query access |
| Configuration | Environment vars | Provider keys, settings |
| Personality | Markdown files | Agent persona definitions |

## Deployment Patterns

### Local Development

```
┌──────────┐     ┌──────────┐     ┌──────────┐
│  Ollama  │◄────│  Daemon  │◄────│   TUI    │
└──────────┘     └──────────┘     └──────────┘
localhost:11434   daemon.sock      terminal
```

### Kubernetes (DaemonSet)

```
┌─────────────────────────────────────────────┐
│  Node                                        │
│  ┌──────────┐   ┌──────────┐                │
│  │  Ollama  │◄──│  Hecate  │                │
│  │   Pod    │   │ DaemonSet│                │
│  └──────────┘   └────┬─────┘                │
│                      │                       │
│            /run/hecate/daemon.sock          │
│                      │                       │
│                 ┌────┴─────┐                │
│                 │   TUI    │                │
│                 │ (user)   │                │
│                 └──────────┘                │
└─────────────────────────────────────────────┘
```

## Next Steps

- [Daemon API](daemon-api.md) - REST API reference
- [Mesh Integration](mesh-integration.md) - Peer-to-peer features
- [Deployment](deployment.md) - GitOps deployment guide
