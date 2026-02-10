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
│  │  │ /api/vent*  │  │  │Ollama │  │  │                     │  │    │
│  │  │ /api/llm/*  │  │  │OpenAI │  │  │  - Ventures         │  │    │
│  │  │ /api/mesh/* │  │  │Claude │  │  │  - Divisions        │  │    │
│  │  └─────────────┘  │  │Google │  │  │  - Designs          │  │    │
│  │                   │  └───────┘  │  │  - Plans            │  │    │
│  │                   └──────┬──────┘  └─────────────────────┘  │    │
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
- Navigate chat history with up/down arrows

**Key Packages:**
- `internal/ui/` - Bubble Tea models and views
- `internal/commands/` - Slash command handlers
- `internal/client/` - Daemon API client
- `internal/personality/` - Personality file loader
- `internal/llmtools/` - Tool/function calling system

### Hecate Daemon

The daemon is an Erlang/OTP umbrella application organized around the [Application Lifecycle](application-lifecycle.md).

**Venture Lifecycle Apps (CMD):**

| App | Process | Purpose |
|-----|---------|---------|
| `setup_venture` | Inception | Birth of a venture — name, brief, vision |
| `discover_divisions` | Discovery | Identify bounded contexts |
| `design_division` | Architecture | Event storming, aggregate design |
| `plan_division` | Planning | Desk inventory, priorities, sequencing |
| `generate_division` | Generation | Template-based code scaffolding |
| `test_division` | Testing | Verify quality, acceptance criteria |
| `deploy_division` | Deployment | CI/CD, staged rollouts |
| `monitor_division` | Monitoring | Observe health, track SLAs |
| `rescue_division` | Rescue | Diagnose, intervene, unblock |
| `guide_venture` | Orchestration | Track progress across divisions |

**Venture Lifecycle Apps (QRY+PRJ):**

| App | Read Model |
|-----|-----------|
| `query_ventures` | Venture summaries |
| `query_discoveries` | Discovered divisions |
| `query_designs` | Aggregate and event designs |
| `query_plans` | Desk inventory, sequences |
| `query_generations` | Generated skeletons, desks |
| `query_tests` | Test suites, results |
| `query_deployments` | Releases, rollout stages |
| `query_monitoring` | Health checks, incidents |
| `query_rescues` | Diagnoses, fixes |

**Infrastructure Apps:**

| App | Purpose |
|-----|---------|
| `hecate_api` | Cowboy HTTP handlers, routing |
| `hecate_mesh` | Macula mesh integration |
| `serve_llm` | LLM provider abstraction |
| `shared` | API utilities |
| `hecate_telemetry` | Cost tracking |

**Platform Services:**

| App | Purpose |
|-----|---------|
| `manage_capabilities` | Capability announcements |
| `manage_reputation` | Agent reputation tracking |
| `manage_identities` | Identity management |
| `manage_ucan` | UCAN authorization tokens |
| + corresponding `query_*` apps | Read models for each |

**CQRS Architecture:**

The daemon follows Command Query Responsibility Segregation. Each venture process has a CMD app (commands) and a QRY+PRJ app (queries and projections):

```
CMD (Write Side)                    QRY+PRJ (Read Side)
────────────────                    ───────────────────
design_division                     query_designs
  ├── start_design/                   ├── query_designs_store.erl (SQLite)
  │   ├── start_design_v1.erl        ├── aggregate_designed_v1_to_designs/
  │   ├── design_started_v1.erl      │   └── on_aggregate_designed_v1.erl
  │   └── maybe_start_design.erl     ├── get_design_by_id/
  ├── design_aggregate/              │   └── get_design_by_id.erl
  │   ├── design_aggregate_v1.erl    └── get_designs_page/
  │   ├── aggregate_designed_v1.erl      └── get_designs_page.erl
  │   └── maybe_design_aggregate.erl
  ├── complete_design/
  ├── archive_design/
  └── design_aggregate.erl
```

- **Commands** produce events stored in ReckonDB
- **Projections** consume events and update SQLite read models
- **Queries** read directly from SQLite for fast retrieval

Each desk directory is a **vertical slice** — command, event, handler, and emitters all live together. No `services/`, `handlers/`, or `utils/` directories.

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

Commercial providers are auto-detected on startup from environment variables. Use `POST /api/llm/providers/reload` for hot-reload without restart.

### Event Sourcing

The daemon uses event sourcing for all stateful operations via the [Reckon ecosystem](https://github.com/reckon-db-org/reckon-ecosystem).

**Event Flow:**

```
Command → Handler → Events → ReckonDB → Projections → SQLite Read Model
```

**Example: Setting Up a Venture**

1. TUI sends `POST /api/ventures` with venture data
2. API handler creates `setup_venture_v1` command
3. `maybe_setup_venture` validates and returns `venture_setup_v1` event
4. Event is stored in ReckonDB via evoq + reckon_evoq adapter
5. Projection updates SQLite read model in `query_ventures`
6. Subsequent queries read from SQLite

**Example: Designing an Aggregate**

1. User in `design_division` phase sends `POST /api/divisions/:id/design/aggregate`
2. API handler creates `design_aggregate_v1` command
3. `maybe_design_aggregate` validates against current design state
4. `aggregate_designed_v1` event stored in ReckonDB
5. Emitter publishes fact to pg group (internal) and mesh (external)
6. Projection updates `query_designs` SQLite store
7. `plan_division` can now see the designed aggregates

### Mesh Integration

The daemon connects to the Macula mesh for peer-to-peer communication via [Macula](https://github.com/macula-io/macula-ecosystem).

**Capabilities:**
- **Discovery** — Find other Hecate instances via DHT
- **PubSub** — Subscribe to events from other agents
- **RPC** — Call procedures on remote agents
- **Capabilities** — Advertise and discover agent capabilities

**Fact Transport:**

Processes communicate through facts, never by calling each other directly:

| Transport | Scope | Use |
|-----------|-------|-----|
| **pg groups** | Internal (same BEAM VM) | Inter-process facts within one daemon |
| **Macula mesh** | External (WAN) | Cross-daemon, agent-to-agent facts |

Each event can have two emitters:
- `{event}_to_pg.erl` — publishes to local OTP process groups
- `{event}_to_mesh.erl` — publishes to Macula mesh topics

## Data Storage

| Store | Technology | Purpose |
|-------|------------|---------|
| Event Store | ReckonDB (embedded, Khepri/Ra) | Immutable event log with Raft consensus |
| Read Models | SQLite | Fast query access, one database per QRY app |
| Provider Config | Environment vars | API keys for LLM providers |
| Personality | Markdown files | Agent persona and role definitions |

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

The daemon runs as a DaemonSet so every node gets one instance. Deployment is managed via GitOps (Flux) through the [hecate-gitops](https://github.com/hecate-social/hecate-gitops) repository.

## Next Steps

- [Application Lifecycle](application-lifecycle.md) — The ALC philosophy and process-centric architecture
- [Daemon API](daemon-api.md) — REST API reference
- [Mesh Integration](mesh-integration.md) — Peer-to-peer features
- [Deployment](deployment.md) — GitOps deployment guide
