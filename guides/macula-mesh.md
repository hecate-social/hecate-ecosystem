# Macula Mesh and the Role of Hecate

## What is Macula?

Macula is a decentralized mesh network built on HTTP/3 over QUIC. It provides the communication layer that allows Hecate agents to discover each other, share capabilities, and collaborate — without central servers.

Think of it as the nervous system connecting all Hecate nodes. Each daemon is a peer on the mesh. There is no master, no broker, no cloud gateway. Peers find each other through a Kademlia DHT, communicate over encrypted QUIC connections, and authenticate using Ed25519 keypairs.

## How Hecate Uses the Mesh

Every Hecate daemon embeds a Macula client (`hecate_mesh` module). When the daemon starts, it:

1. **Bootstraps** — connects to known bootstrap nodes (`boot.macula.io:4433`)
2. **Joins a realm** — enters a namespace (default: `io.macula`) that isolates traffic
3. **Announces identity** — publishes its MRI (Macula Resource Identifier) to the DHT
4. **Subscribes to topics** — listens for events from other agents in the realm

From that point, the daemon can publish facts, subscribe to topics, and call remote procedures on other agents.

```
Your Machine                           The Mesh
┌──────────────────────┐              ┌─────────────────────────┐
│  hecate-web (Tauri)  │              │                         │
│         │            │              │   ┌───────┐             │
│         │ Unix sock  │              │   │ Agent │             │
│         ▼            │              │   │  B    │             │
│  hecate-daemon       │   QUIC/H3   │   └───┬───┘             │
│  ┌──────────────┐    │◄────────────►│       │                 │
│  │ hecate_mesh  │    │              │   ┌───┴───┐             │
│  │ hecate_store │    │              │   │  DHT  │             │
│  │ hecate_ucan  │    │              │   │ Boot  │             │
│  └──────────────┘    │              │   └───┬───┘             │
│                      │              │       │                 │
│  ReckonDB (events)   │              │   ┌───┴───┐             │
│  SQLite (read models)│              │   │ Agent │             │
└──────────────────────┘              │   │  C    │             │
                                      │   └───────┘             │
                                      └─────────────────────────┘
```

## Identity: MRI and Ed25519

Every Hecate agent has a cryptographic identity:

- **Ed25519 keypair** — generated automatically on first boot
- **MRI** (Macula Resource Identifier) — a structured address on the mesh

MRI format: `mri:{type}:{realm}/{owner}/{name}`

| Type | Example | Description |
|------|---------|-------------|
| `agent` | `mri:agent:io.macula/rl/hecate-a1b2` | An agent instance |
| `capability` | `mri:capability:io.macula/rl/weather` | A discoverable service |

The private key signs messages. Other agents verify signatures using the public key. No certificate authority needed — identity is self-sovereign.

## Realms

A **realm** is a namespace on the mesh. Agents in different realms cannot see each other.

| Realm | Purpose |
|-------|---------|
| `io.macula` | Default public realm |
| `io.mycompany.team` | Private team namespace |
| `io.mycompany.prod` | Production environment |

Realms provide multi-tenancy without infrastructure overhead. Same mesh, different namespaces.

## Pub/Sub: Publishing Facts

Domain events stay inside the daemon (in ReckonDB). What goes on the mesh are **facts** — explicit public contracts derived from domain events.

The distinction matters:

| Domain Events (Internal) | Integration Facts (Mesh) |
|--------------------------|--------------------------|
| Implementation detail | Public contract |
| Fine-grained | Coarse-grained |
| May change freely | Stable API |
| Stored in ReckonDB | Published to mesh topics |

A **process manager** decides when a domain event should produce a fact on the mesh.

```
Domain Event (ReckonDB)              Integration Fact (Mesh)
────────────────────────             ─────────────────────────
learning_validated_v1         ──►    Process Manager decides
(internal to mentor domain)          to publish to topic
                                     "hecate.learnings.shared"
```

### Publishing

```erlang
%% In an emitter module (e.g., learning_validated_v1_to_mesh.erl)
hecate_mesh:publish(<<"hecate.learnings.shared">>, Fact).
```

### Subscribing

```erlang
%% In a listener module
hecate_mesh:subscribe(<<"hecate.learnings.shared">>, self()).
```

Listeners receive facts and convert them to **commands** that enter the local CQRS pipeline. Facts never bypass the command/aggregate layer.

```
Mesh Fact ──► Listener ──► Command ──► Aggregate ──► Domain Event ──► ReckonDB
```

## RPC: Calling Remote Agents

RPC allows synchronous calls between agents. An agent advertises a procedure, and other agents can call it.

```erlang
%% Call a remote procedure
{ok, Result} = hecate_mesh:call(
    <<"mri:agent:io.macula/other/agent">>,
    <<"weather.forecast">>,
    #{location => <<"Brussels">>}
).
```

The daemon exposes RPC via the REST API:

```bash
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/rpc/call \
  -H "Content-Type: application/json" \
  -d '{"procedure": "weather.forecast", "args": {"location": "Brussels"}}'
```

## UCAN: Capability-Based Authorization

Agents don't have passwords or API keys. Instead, they use **UCAN tokens** (User Controlled Authorization Networks) — capability tokens that are:

- **Self-contained** — no server lookup needed to verify
- **Delegatable** — Agent A can grant Agent B permission to act on its behalf
- **Expiring** — tokens have a TTL
- **Revocable** — the issuer can revoke at any time

```bash
# Grant Agent B permission to call my weather procedure for 1 hour
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/ucan/grant \
  -d '{
    "to": "mri:agent:io.macula/other/agent",
    "capability": "rpc/call",
    "resource": "procedure:weather.forecast",
    "expires_in": 3600
  }'
```

## Pairing: Connecting to a Realm Account

When a daemon first boots, it has a self-generated identity but no realm account. **Pairing** links the daemon to a Macula realm account (via OAuth with GitHub):

1. Daemon generates a pairing session with a confirmation code
2. User visits `https://macula.io/pair/{session_id}?code={code}`
3. User authenticates with GitHub on the realm page
4. Realm confirms the pairing — daemon receives realm credentials
5. Daemon's identity is now linked to the realm account

```bash
# Initiate pairing
curl -X POST --unix-socket ~/.hecate/hecate-daemon/sockets/api.sock \
  http://localhost/api/pairing/initiate

# Returns: { pairing_url, confirm_code, session_id, expires_in }
```

The pairing URL includes the confirmation code for seamless auto-confirmation — no manual code entry needed.

## Network Topology

A typical Hecate deployment:

```
┌─────────────────────────────────────────────────────────────┐
│                     Your Network                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│   ┌──────────────┐    ┌──────────────┐                       │
│   │  Workstation  │    │  Server      │                       │
│   │  (laptop)     │    │  (beam01)    │                       │
│   │               │    │              │                       │
│   │ daemon        │    │ daemon       │                       │
│   │ hecate-web    │    │ plugins      │                       │
│   │ ollama        │    │              │                       │
│   └───────┬───────┘    └──────┬───────┘                       │
│           │                   │                               │
│           │   BEAM Cluster    │                               │
│           └───────────────────┘                               │
│                   │                                           │
│                   │  Macula Mesh (QUIC)                       │
│                   ▼                                           │
│           ┌───────────────┐                                   │
│           │ boot.macula.io│  ◄──── DHT Bootstrap              │
│           └───────┬───────┘                                   │
│                   │                                           │
│              ┌────┴────┐                                      │
│              │ Other   │  ◄──── Agents in same realm          │
│              │ Agents  │                                      │
│              └─────────┘                                      │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

**Within your network:** Daemons form a BEAM cluster (Erlang distribution, pg process groups). Communication is direct and fast.

**Across networks:** Daemons communicate via the Macula mesh (HTTP/3 over QUIC). NAT traversal with hole punching and relay fallback.

## Configuration

The daemon configures mesh connectivity via environment variables and application config:

| Setting | Source | Default |
|---------|--------|---------|
| Realm | `hecate.app.src` | `io.macula` |
| Bootstrap nodes | `hecate.app.src` | `boot.macula.io:4433` |
| Mesh enabled | Runtime | `true` |
| Hostname | `HECATE_HOSTNAME` env var | OS detection |
| User | `HECATE_USER` env var | OS detection |

## Further Reading

- [Macula Ecosystem](https://github.com/macula-io/macula-ecosystem) — full mesh architecture docs, content transfer protocol, MaculaOS
- [App Development](app-development.md) — build plugins that use the mesh
- [Daemon API](daemon-api.md) — REST endpoints for mesh operations
