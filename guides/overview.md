# Overview

Hecate is a local-first AI agent platform designed for developers who want to run intelligent assistants on their own hardware while maintaining full control over their data and workflows.

## Philosophy

### Local-First

Every component of Hecate is designed to run locally. Your conversations, your models, your rules. Cloud connectivity is optional and additive, never required.

### Terminal-Native

The terminal is the developer's natural habitat. Hecate embraces this with a vim-style TUI that integrates seamlessly into your existing workflow. No browser tabs, no Electron apps, just your terminal.

### Agent Personality

AI assistants don't have to be generic. Hecate's personality system lets you shape how your agent thinks, communicates, and approaches problems. From the confident goddess persona to strictly professional modes, you control the character.

### Mesh-Ready

When you need agents to collaborate, Hecate connects to the Macula mesh network. Discover peers, share capabilities, and coordinate through distributed events.

## Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| [Daemon](https://github.com/hecate-social/hecate-daemon) | Erlang/OTP | LLM routing, event sourcing, mesh connectivity |
| [TUI](https://github.com/hecate-social/hecate-tui) | Go (Bubble Tea) | Terminal interface, vim-style interaction |
| [Agents](https://github.com/hecate-social/hecate-agents) | Markdown | Personality files, philosophy guides |
| [GitOps](https://github.com/hecate-social/hecate-gitops) | YAML (Flux) | Kubernetes deployment manifests |

## Use Cases

### Personal AI Assistant

Run Hecate on your workstation with Ollama for a completely private AI assistant. Your conversations never leave your machine.

### Development Pair Programmer

Use the TUI alongside your editor for code reviews, debugging assistance, and architecture discussions. The personality system can be configured for technical precision.

### Team Knowledge Base

Deploy Hecate across a team with mesh connectivity. Agents can share learned patterns and coordinate on complex tasks.

### Edge AI

Deploy on Kubernetes clusters (including single-node k3s) for AI capabilities at the edge. The daemon's small footprint makes it suitable for resource-constrained environments.

## Next Steps

- [Getting Started](getting-started.md) - Install and run your first chat
- [Architecture](architecture.md) - Understand how the components fit together
- [TUI Usage](tui-usage.md) - Master the terminal interface
