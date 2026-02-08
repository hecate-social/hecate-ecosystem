# Overview

Hecate is a **developer studio for building applications on the Macula mesh network**. It combines an AI-assisted terminal interface with local infrastructure for distributed, event-sourced application development.

## Not Just Another Chatbot

Many AI tools focus on conversation. Hecate focuses on **building**.

| Generic AI Chat | Hecate Developer Studio |
|-----------------|-------------------------|
| Answers questions | Explores codebases, writes code, runs tests |
| Stateless conversations | Event-sourced project history |
| Cloud-dependent | Local-first, mesh-connected |
| General purpose | Opinionated for distributed systems |
| Single user | Agents discover and collaborate on mesh |

## The Macula Mesh

Hecate is designed to build applications for [Macula](https://github.com/macula-io/macula-ecosystem) — a decentralized mesh network built on HTTP/3 over QUIC.

**Macula provides:**
- **DHT Discovery** — Find services without central registries
- **PubSub** — Publish and subscribe to events across the mesh
- **RPC** — Call procedures on remote nodes
- **Capability Security** — UCAN tokens for fine-grained authorization

**Hecate applications can:**
- Discover peers automatically
- Share capabilities with other agents
- Coordinate through distributed events
- Run at the edge without cloud dependencies

## Development Lifecycle (ALC)

Hecate structures development into four phases, each with specialized AI behavior:

### Discovery & Analysis (DNA)

Before writing code, understand the problem:
- Explore existing codebases
- Map dependencies and patterns
- Identify constraints and requirements
- Document findings for the team

The AI in DNA mode asks questions, explores thoroughly, and resists jumping to implementation.

### Architecture & Planning (ANP)

Design before you build:
- Choose patterns (event sourcing, CQRS, vertical slices)
- Define event schemas and aggregates
- Plan the implementation in phases
- Identify risks and unknowns

The AI in ANP mode thinks in systems, proposes architectures, and challenges assumptions.

### Testing & Implementation (TNI)

Write code that works:
- Test-first development
- Follow existing patterns in the codebase
- Minimal changes — do what was asked
- Verify before declaring done

The AI in TNI mode is focused, precise, and stays close to the code.

### Deployment & Operations (DNO)

Ship and maintain:
- GitOps deployments via Flux
- Monitor health and performance
- Respond to incidents
- Iterate based on production feedback

The AI in DNO mode thinks about infrastructure, reliability, and operational concerns.

## Architecture Principles

Hecate embodies strong opinions about distributed system design:

### Event Sourcing

Capture **what happened**, not just current state:
- Full audit trail of every decision
- Time-travel debugging
- Replay for analytics and recovery
- Events as the single source of truth

### Vertical Slicing

Features own their infrastructure:
- Commands, events, handlers co-located
- No horizontal layers (`services/`, `utils/`, `repositories/`)
- Each slice is independently deployable
- Changes to one feature stay in one place

### Screaming Architecture

Names reveal purpose:
- `register_user/` not `user_service.ex`
- `user_registered_v1` not `user_created`
- Directory structure mirrors business capabilities
- New developers can navigate without a guide

### Local-First

Your data stays yours:
- Run LLMs locally via Ollama
- Event store on your machine
- Mesh connectivity is additive, not required
- No cloud vendor lock-in

## Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| [**hecate-tui**](https://github.com/hecate-social/hecate-tui) | Go / Bubble Tea | Terminal interface, AI interaction |
| [**hecate-daemon**](https://github.com/hecate-social/hecate-daemon) | Erlang/OTP | LLM routing, event store, mesh client |
| [**hecate-agents**](https://github.com/hecate-social/hecate-agents) | Markdown | Personality, roles, philosophy |
| [**hecate-gitops**](https://github.com/hecate-social/hecate-gitops) | YAML / Flux | Kubernetes deployment |

## Use Cases

### Solo Developer Building Edge Applications

Run Hecate on your workstation. Build mesh applications with AI assistance. Deploy to edge nodes via GitOps. No cloud infrastructure required.

### Team Building Distributed Systems

Each developer runs Hecate locally. Agents share learnings and patterns through the mesh. Consistent architecture enforced through shared personality and roles.

### Enterprise Mesh Deployments

Deploy Hecate daemon as a DaemonSet across Kubernetes clusters. Developers connect via TUI from any machine. Centralized secrets, decentralized execution.

## Next Steps

- [**Getting Started**](getting-started.md) — Install Hecate and run your first session
- [**Architecture**](architecture.md) — Deep dive into component design
- [**Mesh Integration**](mesh-integration.md) — Connect to the Macula mesh
