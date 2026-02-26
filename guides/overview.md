# Overview

Hecate is a **local-first development platform** for building distributed applications on the Macula mesh network. It combines an AI-assisted desktop environment with an Erlang/OTP daemon that handles event sourcing, LLM routing, and mesh connectivity.

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

See [Macula Mesh](macula-mesh.md) for the full architecture.

## Development Lifecycle (ALC)

Hecate structures development into four phases, each with specialized AI behavior:

### Discovery & Analysis (DnA)

Before writing code, understand the problem:
- Explore existing codebases
- Map dependencies and patterns
- Identify constraints and requirements
- Document findings for the team

### Architecture & Planning (AnP)

Design before you build:
- Choose patterns (event sourcing, CQRS, vertical slices)
- Define event schemas and aggregates
- Plan the implementation in phases
- Identify risks and unknowns

### Testing & Implementation (TnI)

Write code that works:
- Test-first development
- Follow existing patterns in the codebase
- Minimal changes — do what was asked
- Verify before declaring done

### Deployment & Operations (DnO)

Ship and maintain:
- systemd + podman deployment via GitOps reconciler
- Monitor health and performance
- Respond to incidents
- Iterate based on production feedback

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
| [**hecate-daemon**](https://github.com/hecate-social/hecate-daemon) | Erlang/OTP | Runtime — identity, event sourcing, LLM routing, mesh client |
| [**hecate-web**](https://github.com/hecate-social/hecate-web) | Tauri / SvelteKit | Desktop app — studios for LLM, DevOps, node management |
| [**hecate-agents**](https://github.com/hecate-social/hecate-agents) | Markdown | Personality, roles, philosophy, skills |
| [**hecate-install**](https://github.com/hecate-social/hecate-install) | Bash / Nix | Installer + NixOS flake for bootable media |
| [**hecate-gitops**](https://github.com/hecate-social/hecate-gitops) | Quadlet | Per-node systemd + podman deployment |

## Use Cases

### Solo Developer Building Edge Applications

Run Hecate on your workstation. Build mesh applications with AI assistance. Deploy to edge nodes via GitOps. No cloud infrastructure required.

### Team Building Distributed Systems

Each developer runs Hecate locally. Agents share learnings and patterns through the mesh. Consistent architecture enforced through shared personality and roles.

### Home Lab with Multiple Nodes

Deploy Hecate across a cluster of machines (e.g., beam00-03). Daemons form a BEAM cluster for intra-network communication and connect to the Macula mesh for cross-network collaboration.

## Next Steps

- [**Getting Started**](getting-started.md) — Install Hecate and verify everything works
- [**Mental Model**](mental-model.md) — Understand the Venture/Division/Department/Desk hierarchy
- [**Macula Mesh**](macula-mesh.md) — How the mesh works and Hecate's role in it
- [**App Development**](app-development.md) — Build your own Hecate plugin
